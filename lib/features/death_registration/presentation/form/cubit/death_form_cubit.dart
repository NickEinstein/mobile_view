import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/cancellation.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/death_registration_repository.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_draft.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_form.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_reference_data.dart';

part 'death_form_state.dart';

/// The four-step death registration form, saved on every change. With
/// [queriedRecordId] it corrects that record instead (in memory only).
class DeathFormCubit extends Cubit<DeathFormState> {
  DeathFormCubit(
    this._repository, {
    this.queriedRecordId,
    DateTime Function()? now,
    String Function()? newSubmissionKey,
  }) : _now = now ?? DateTime.now,
       _newSubmissionKey = newSubmissionKey ?? _randomKey,
       super(const DeathFormState());

  final DeathRegistrationRepository _repository;
  final String? queriedRecordId;
  final DateTime Function() _now;
  final String Function() _newSubmissionKey;

  /// The upload in flight. Leaving the screen cancels it; the draft keeps
  /// its submission key, so sending it again later is safe.
  Cancellation? _submission;

  @override
  Future<void> close() {
    _submission?.cancel();
    return super.close();
  }

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
    if (queriedRecordId case final id?) return _loadQueried(id);
    final (draft, reference) = await (
      _repository.loadDraft(),
      _repository.referenceData(),
    ).wait;
    if (isClosed) return;
    switch (reference) {
      case Ok(value: final referenceData):
        final loaded = draft ?? DeathDraft(startedOn: today);
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

  Future<void> _loadQueried(String id) async {
    final record = await _repository.details(id);
    final reference = switch (record) {
      Ok(value: final r) => await _repository.referenceData(
        withLgasOf: deathStates(deceased: r.deceased, informant: r.informant),
      ),
      Err(:final failure) => Err<DeathReferenceData>(failure),
    };
    if (isClosed) return;
    switch ((record, reference)) {
      case (Ok(value: final record), Ok(value: final referenceData)):
        final draft = record.toQueriedDraft();
        _statesWithLgas = draft.chosenStates;
        emit(
          state.copyWith(
            status: FormStatus.ready,
            referenceData: referenceData,
            draft: draft,
          ),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(state.copyWith(status: FormStatus.failure, failure: failure));
    }
  }

  /// States whose LGAs are loaded or on their way.
  Set<String> _statesWithLgas = const {};

  /// A state's LGAs are fetched once it is chosen.
  Future<void> _loadLgas(DeathDraft draft) async {
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
    // Names from a verified NIN can't be changed.
    if (draft == null || state.isLocked(field)) return;
    _update(draft.copyWith(deceased: draft.deceased.set(field, value)));
    if (field == DeceasedField.nin) _clearNinFailure(NinOwner.deceased);
  }

  void dateOfDeathChanged(DateTime date) => deceasedChanged(
    DeceasedField.dateOfDeath,
    DateTime(date.year, date.month, date.day).toIso8601String(),
  );

  void informantChanged(InformantField field, String? value) {
    final draft = state.draft;
    if (draft == null || state.isInformantLocked(field)) return;
    var informant = draft.informant.set(field, value);
    // "Yes" copies the deceased's residence.
    if (field == InformantField.sameAddress && value == DeathCodes.yes) {
      informant = informant.withAddressOf(draft.deceased);
    }
    _update(draft.copyWith(informant: informant));
    if (field == InformantField.nin) _clearNinFailure(NinOwner.informant);
  }

  /// Checks the typed NIN with the identity service; its names fill the
  /// form.
  Future<void> verifyNin(NinOwner owner) async {
    final draft = state.draft;
    final nin = switch (owner) {
      NinOwner.deceased => draft?.deceased[DeceasedField.nin],
      NinOwner.informant => draft?.informant[InformantField.nin],
    };
    if (draft == null || nin == null || state.verifying.contains(owner)) {
      return;
    }
    emit(
      state.copyWith(
        verifying: {...state.verifying, owner},
        ninFailures: {...state.ninFailures}..remove(owner),
      ),
    );
    final result = await _repository.verifyNin(nin);
    if (isClosed) return;
    final verifying = {...state.verifying}..remove(owner);
    final latest = state.draft!;
    switch (result) {
      // Ignore an answer for a NIN that has since changed.
      case Ok(value: final record) when record.nin == nin:
        emit(state.copyWith(verifying: verifying));
        _update(switch (owner) {
          NinOwner.deceased => latest.copyWith(
            deceased: latest.deceased.verified(
              nin: nin,
              surname: record.surname,
              firstName: record.firstName,
            ),
          ),
          NinOwner.informant => latest.copyWith(
            informant: latest.informant.verified(
              nin: nin,
              surname: record.surname,
              firstName: record.firstName,
            ),
          ),
        });
      case Ok():
        emit(state.copyWith(verifying: verifying));
      case Err(:final failure):
        emit(
          state.copyWith(
            verifying: verifying,
            ninFailures: {...state.ninFailures, owner: failure},
          ),
        );
    }
  }

  void _clearNinFailure(NinOwner owner) {
    if (!state.ninFailures.containsKey(owner)) return;
    emit(state.copyWith(ninFailures: {...state.ninFailures}..remove(owner)));
  }

  /// Checks and stores a picked image. Returns why it was refused, if it
  /// was.
  Future<DocumentError?> documentPicked(
    DeathDocument document, {
    required String path,
    required String name,
    required int sizeBytes,
  }) async {
    final error = SupportingDocuments.check(name, sizeBytes);
    final draft = state.draft;
    if (error != null || draft == null) return error;
    final kept = await _repository.keepDocument(
      path,
      replacing: draft.documents[document]?.path,
    );
    final latest = state.draft;
    if (isClosed || latest == null) return null;
    final file = AttachedFile(path: kept, name: name, sizeBytes: sizeBytes);
    _update(latest.copyWith(documents: latest.documents.set(document, file)));
    return null;
  }

  Future<void> documentRemoved(DeathDocument document) async {
    final draft = state.draft;
    final file = draft?.documents[document];
    if (draft == null || file == null) return;
    _update(draft.copyWith(documents: draft.documents.set(document, null)));
    await _repository.deleteFile(file.path);
  }

  /// Stores the drawn signature, replacing any earlier one.
  Future<void> signatureDrawn(Uint8List png) async {
    final draft = state.draft;
    if (draft == null) return;
    final path = await _repository.keepSignature(
      png,
      replacing: draft.signature,
    );
    final latest = state.draft;
    if (isClosed || latest == null) return;
    _update(latest.copyWith(signature: () => path));
  }

  Future<void> signatureCleared() async {
    final draft = state.draft;
    final path = draft?.signature;
    if (draft == null || path == null) return;
    _update(draft.copyWith(signature: () => null));
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
      _update(draft.copyWith(step: DeathStep.review), showErrors: false);
      emit(state.copyWith(returnToReview: false));
      return;
    }
    final nextIndex = draft.step.index + 1;
    if (nextIndex >= DeathStep.count) return;
    _update(
      draft.copyWith(step: DeathStep.values[nextIndex]),
      showErrors: false,
    );
  }

  void previous() {
    final draft = state.draft;
    if (draft == null || draft.step.index == 0) return;
    _update(
      draft.copyWith(step: DeathStep.values[draft.step.index - 1]),
      showErrors: false,
    );
  }

  /// "Edit" on the preview: opens [step]; "Next" there returns to the
  /// preview.
  void editStep(DeathStep step) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(step: step), showErrors: false);
    emit(state.copyWith(returnToReview: true));
  }

  void declarationChanged({required bool declared}) =>
      emit(state.copyWith(declared: declared));

  /// Sends the registration. On success the draft and its files are
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
        progress: () => null,
        submitFailure: () => null,
      ),
    );
    await flush();
    if (keyed.queried != null) return _sendCorrection(keyed);
    final result = await _repository.submit(
      keyed,
      cancellation: _submission = Cancellation(),
      onProgress: (done, total) {
        if (!isClosed && total > 0) {
          emit(state.copyWith(progress: () => done / total));
        }
      },
    );
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

  Future<void> _sendCorrection(DeathDraft draft) async {
    final result = await _repository.updateQueried(draft);
    if (isClosed) return;
    if (result is Ok) {
      // The replaced files were sent; don't keep copies on the device.
      for (final path in draft.files) {
        await _repository.deleteFile(path);
      }
      if (isClosed) return;
    }
    emit(switch (result) {
      Ok() => state.copyWith(
        submitStatus: SubmitStatus.submitted,
        trackingId: () => draft.queried?.certificateNumber,
      ),
      Err(:final failure) => state.copyWith(
        submitStatus: SubmitStatus.failed,
        submitFailure: () => failure,
      ),
    });
  }

  /// Completes once every change is safely stored.
  Future<void> flush() => _saving;

  void _update(DeathDraft draft, {bool? showErrors}) {
    emit(state.copyWith(draft: draft, showErrors: showErrors));
    unawaited(_loadLgas(draft));
    // A correction lives only in memory; the record is on the server.
    if (draft.queried != null) return;
    _saving = _saving.then((_) => _repository.saveDraft(draft));
  }
}
