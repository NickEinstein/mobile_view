import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_draft.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_form.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_reference_data.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/still_birth_repository.dart';

part 'still_birth_form_state.dart';

/// The four-step still birth form, saved on every change.
class StillBirthFormCubit extends Cubit<StillBirthFormState> {
  StillBirthFormCubit(
    this._repository, {
    DateTime Function()? now,
    String Function()? newSubmissionKey,
  }) : _now = now ?? DateTime.now,
       _newSubmissionKey = newSubmissionKey ?? _randomKey,
       super(const StillBirthFormState());

  final StillBirthRepository _repository;
  final DateTime Function() _now;
  final String Function() _newSubmissionKey;

  /// 128 random bits as hex.
  static String _randomKey() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  /// Saves run one after another, in order.
  Future<void> _saving = Future.value();

  DateTime get today => _now();

  Future<void> load() async {
    emit(state.copyWith(status: FormStatus.loading));
    final (draft, reference) = await (
      _repository.loadDraft(),
      _repository.referenceData(),
    ).wait;
    if (isClosed) return;
    switch (reference) {
      case Ok(value: final referenceData):
        final loaded = draft ?? StillBirthDraft(startedOn: today);
        emit(
          state.copyWith(
            status: FormStatus.ready,
            referenceData: referenceData,
            draft: loaded,
          ),
        );
        // The draft's states' LGAs follow; if they fail, only those
        // fields say so.
        await _loadLgas(loaded);
      case Err(:final failure):
        emit(state.copyWith(status: FormStatus.failure, failure: failure));
    }
  }

  /// States whose LGAs are loaded or on their way.
  Set<String> _statesWithLgas = const {};

  /// A state's LGAs are fetched once it is chosen.
  Future<void> _loadLgas(StillBirthDraft draft) async {
    final missing = draft.chosenStates.difference(_statesWithLgas);
    if (missing.isEmpty) return;
    _statesWithLgas = {..._statesWithLgas, ...missing};
    emit(
      state.copyWith(
        lgasUnavailable: state.lgasUnavailable.difference(missing),
      ),
    );
    final result = await _repository.referenceData(withLgasOf: missing);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final referenceData):
        emit(state.copyWith(referenceData: referenceData));
      case Err():
        _statesWithLgas = _statesWithLgas.difference(missing);
        emit(
          state.copyWith(
            lgasUnavailable: {...state.lgasUnavailable, ...missing},
          ),
        );
    }
  }

  /// "Try again" under an LGA field whose state's LGAs failed to load.
  Future<void> retryLgas() async {
    final draft = state.draft;
    if (draft != null) await _loadLgas(draft);
  }

  void deceasedChanged(DeceasedField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(deceased: draft.deceased.set(field, value)));
  }

  void dateOfDeliveryChanged(DateTime date) => deceasedChanged(
    DeceasedField.dateOfDelivery,
    DateTime(date.year, date.month, date.day).toIso8601String(),
  );

  void motherChanged(MotherField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(mother: draft.mother.set(field, value)));
  }

  void informantChanged(InformantField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    var informant = draft.informant.set(field, value);
    // Choosing "Mother" fills in her name and address.
    if (field == InformantField.relationship &&
        value == StillBirthCodes.motherRelationship) {
      informant = informant.copyFromMother(draft.mother);
    }
    _update(draft.copyWith(informant: informant));
  }

  /// Stores the drawn signature, replacing any earlier one.
  Future<void> signatureDrawn(Uint8List png) async {
    final draft = state.draft;
    if (draft == null) return;
    final path = await _repository.keepSignature(
      png,
      replacing: draft.informant[InformantField.signature],
    );
    final latest = state.draft;
    if (isClosed || latest == null) return;
    _update(
      latest.copyWith(
        informant: latest.informant.set(InformantField.signature, path),
      ),
    );
  }

  Future<void> signatureCleared() async {
    final draft = state.draft;
    final path = draft?.informant[InformantField.signature];
    if (draft == null || path == null) return;
    _update(
      draft.copyWith(
        informant: draft.informant.set(InformantField.signature, null),
      ),
    );
    await _repository.deleteFile(path);
  }

  /// "Next". Shows the errors instead if the step is incomplete.
  void next() {
    final draft = state.draft;
    if (draft == null) return;
    if (!state.isStepComplete(today)) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    if (state.returnToReview) {
      _update(draft.copyWith(step: StillBirthStep.review), showErrors: false);
      emit(state.copyWith(returnToReview: false));
      return;
    }
    final nextIndex = draft.step.index + 1;
    if (nextIndex >= StillBirthStep.count) return;
    _update(
      draft.copyWith(step: StillBirthStep.values[nextIndex]),
      showErrors: false,
    );
  }

  void previous() {
    final draft = state.draft;
    if (draft == null || draft.step.index == 0) return;
    _update(
      draft.copyWith(step: StillBirthStep.values[draft.step.index - 1]),
      showErrors: false,
    );
  }

  /// "Edit" on the preview: opens [step]; "Next" there returns to the
  /// preview.
  void editStep(StillBirthStep step) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(step: step), showErrors: false);
    emit(state.copyWith(returnToReview: true));
  }

  void declarationChanged({required bool declared}) =>
      emit(state.copyWith(declared: declared));

  /// Sends the registration. On success the draft and its signature are
  /// cleared from the device.
  Future<void> submit() async {
    final draft = state.draft;
    if (draft == null || state.submitStatus == SubmitStatus.submitting) return;
    if (!state.canSubmit(today)) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    // Stored before sending, so a retry (even after a restart) reuses it.
    final keyed = draft.submissionKey == null
        ? draft.copyWith(submissionKey: _newSubmissionKey())
        : draft;
    if (keyed != draft) _update(keyed);
    emit(
      state.copyWith(
        submitStatus: SubmitStatus.submitting,
        submitFailure: () => null,
      ),
    );
    await flush();
    final result = await _repository.submit(keyed);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final trackingId):
        await _repository.discardDraft();
        if (isClosed) return;
        emit(
          state.copyWith(
            submitStatus: SubmitStatus.submitted,
            trackingId: () => trackingId,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            submitStatus: SubmitStatus.failed,
            submitFailure: () => failure,
          ),
        );
    }
  }

  /// Completes once every change is safely stored.
  Future<void> flush() => _saving;

  void _update(StillBirthDraft draft, {bool? showErrors}) {
    emit(state.copyWith(draft: draft, showErrors: showErrors));
    unawaited(_loadLgas(draft));
    _saving = _saving.then((_) => _repository.saveDraft(draft));
  }
}
