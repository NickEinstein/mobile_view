import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_options.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';

part 'birth_reissuance_form_state.dart';

/// The birth certificate's form, saved on every change. With a
/// [queriedId] it corrects that request instead (in memory only).
class BirthReissuanceFormCubit extends Cubit<BirthReissuanceFormState> {
  BirthReissuanceFormCubit(this._repository, {this.queriedId})
    : super(const BirthReissuanceFormState());

  final ReissuanceRepository _repository;
  final String? queriedId;

  /// Saves run one after another, in order.
  Future<void> _saving = Future.value();

  Future<void> load() async {
    emit(state.copyWith(status: FormStatus.loading));
    if (queriedId case final id?) return _loadQueried(id);
    final (draft, options) = await (
      _repository.loadDraft(),
      _repository.options(),
    ).wait;
    if (isClosed) return;
    if (draft == null || draft.certificate == null) {
      emit(state.copyWith(status: FormStatus.missing));
      return;
    }
    switch (options) {
      case Ok(value: final options):
        final form = draft.birthForm ?? _prefilled(draft.ninRecord);
        emit(
          state.copyWith(
            status: FormStatus.ready,
            options: options,
            draft: draft.withBirthForm(form),
          ),
        );
        if (draft.birthForm == null) _save(state.draft!);
        await _loadPlacesFor(form);
      case Err(:final failure):
        emit(state.copyWith(status: FormStatus.failure, failure: failure));
    }
  }

  Future<void> _loadQueried(String id) async {
    final (record, options) = await (
      _repository.birthRecord(id),
      _repository.options(),
    ).wait;
    if (isClosed) return;
    switch ((record, options)) {
      case (Ok(value: final record), Ok(value: final options)):
        emit(
          state.copyWith(
            status: FormStatus.ready,
            options: options,
            record: record,
          ),
        );
        await _loadPlacesFor(record.form);
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(state.copyWith(status: FormStatus.failure, failure: failure));
    }
  }

  /// The NIN's names and sex are the child's.
  static BirthReissuanceForm _prefilled(ApplicantNinRecord nin) {
    var child = const ChildParticulars()
        .set(ChildField.surname, nin.surname)
        .set(ChildField.firstName, nin.firstName);
    if (nin.sex case final sex?) {
      child = child.set(
        ChildField.sex,
        sex == Sex.male ? ReissuanceCodes.male : ReissuanceCodes.female,
      );
    }
    return BirthReissuanceForm(child: child);
  }

  void childChanged(ChildField field, String? value) {
    final form = state.form;
    if (form == null) return;
    _update(form.copyWith(child: form.child.set(field, value)));
    if (value == null) return;
    if (field == ChildField.stateOfBirth ||
        field == ChildField.registrationState) {
      unawaited(_loadLgas(value));
    }
  }

  void dateOfBirthChanged(DateTime date) => childChanged(
    ChildField.dateOfBirth,
    DateTime(date.year, date.month, date.day).toIso8601String(),
  );

  void parentChanged(ParentRole role, ParentDetail field, String? value) {
    final form = state.form;
    if (form == null) return;
    final parent = form.parent(role).set(field, value);
    _update(
      role == ParentRole.mother
          ? form.copyWith(mother: parent)
          : form.copyWith(father: parent),
    );
    if (value == null) return;
    if (field == ParentDetail.country || field == ParentDetail.nationality) {
      unawaited(_loadStates(value));
    } else if (field == ParentDetail.state ||
        field == ParentDetail.stateOfOrigin) {
      unawaited(_loadLgas(value));
    }
  }

  /// The father's "Is it the same as mother's?".
  void sameResidenceAsMother({required bool same}) {
    final form = state.form;
    if (form == null) return;
    _update(
      form.copyWith(
        father: form.father.sameResidenceAs(form.mother, same: same),
      ),
    );
  }

  /// "Next" (or "Save & Continue"). Shows the errors instead if the step
  /// is incomplete.
  void next() {
    final form = state.form;
    if (form == null) return;
    if (!form.isComplete(form.step)) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    if (state.returnToReview) {
      _update(
        form.copyWith(step: BirthReissuanceStep.review),
        showErrors: false,
      );
      emit(state.copyWith(returnToReview: false));
      return;
    }
    final nextIndex = form.step.index + 1;
    if (nextIndex >= BirthReissuanceStep.count) return;
    _update(
      form.copyWith(step: BirthReissuanceStep.values[nextIndex]),
      showErrors: false,
    );
  }

  void previous() {
    final form = state.form;
    if (form == null || form.step.index == 0) return;
    _update(
      form.copyWith(step: BirthReissuanceStep.values[form.step.index - 1]),
      showErrors: false,
    );
  }

  /// "Edit" on the preview: opens [step]; "Next" there returns to the
  /// preview.
  void editStep(BirthReissuanceStep step) {
    final form = state.form;
    if (form == null) return;
    _update(form.copyWith(step: step), showErrors: false);
    emit(state.copyWith(returnToReview: true));
  }

  /// Why the document can't be attached, if it can't. Photos only.
  Future<DocumentError?> documentPicked({
    required String path,
    required String name,
    required int sizeBytes,
  }) async {
    final error = SupportingDocuments.check(name, sizeBytes);
    if (error != null) return error;
    final kept = await _repository.keepDocument(
      path,
      replacing: state.form?.document?.path,
    );
    final form = state.form;
    if (isClosed || form == null) return null;
    _update(
      form.copyWith(
        document: () =>
            AttachedFile(path: kept, name: name, sizeBytes: sizeBytes),
        keptDocument: () => null,
      ),
    );
    return null;
  }

  /// Removes the new document, or a queried request's earlier one.
  Future<void> documentRemoved() async {
    final form = state.form;
    if (form == null || !form.hasDocument) return;
    final path = form.document?.path;
    _update(form.copyWith(document: () => null, keptDocument: () => null));
    if (path != null) await _repository.deleteFile(path);
  }

  /// Stores the parent's drawn signature, replacing any earlier one.
  Future<void> signatureDrawn(Uint8List png) async {
    final kept = await _repository.keepSignature(
      png,
      replacing: state.form?.signature,
    );
    final form = state.form;
    if (isClosed || form == null) return;
    _update(form.copyWith(signature: () => kept, keptSignature: () => null));
  }

  Future<void> signatureCleared() async {
    final form = state.form;
    if (form == null || !form.hasSignature) return;
    final path = form.signature;
    _update(form.copyWith(signature: () => null, keptSignature: () => null));
    if (path != null) await _repository.deleteFile(path);
  }

  /// Sends the request to the confirmed [email].
  Future<void> submit({required String? email}) async {
    final form = state.form;
    if (form == null || state.submitStatus == SubmitStatus.submitting) {
      return;
    }
    if (email == null || !state.canSubmit) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    emit(
      state.copyWith(
        submitStatus: SubmitStatus.submitting,
        submitFailure: () => null,
      ),
    );
    await flush();
    final record = state.record;
    final draft = state.draft;
    final result = record != null
        ? await _repository.updateBirth(record, form, email: email)
        : await _repository.submitBirth(draft!, email: email);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            submitStatus: SubmitStatus.submitted,
            submitMessage: () => value,
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

  void _update(BirthReissuanceForm form, {bool? showErrors}) {
    final record = state.record;
    if (record != null) {
      // A correction stays in memory.
      emit(
        state.copyWith(record: record.withForm(form), showErrors: showErrors),
      );
      return;
    }
    final draft = state.draft!.withBirthForm(form);
    emit(state.copyWith(draft: draft, showErrors: showErrors));
    _save(draft);
  }

  void _save(ReissuanceDraft draft) =>
      _saving = _saving.then((_) => _repository.saveDraft(draft));

  /// The places a resumed form already uses: Nigeria's states, each
  /// chosen country's states, and each chosen state's LGAs.
  Future<void> _loadPlacesFor(BirthReissuanceForm form) async {
    final (:countries, :states) = form.places;
    await Future.wait([
      ...countries.map(_loadStates),
      ...states.map(_loadLgas),
    ]);
  }

  /// A failed load leaves the dropdown empty; choosing again retries.
  Future<void> _loadStates(String countryCode) async {
    if (state.statesByCountry.containsKey(countryCode)) return;
    final result = await _repository.states(countryCode);
    if (isClosed) return;
    if (result case Ok(:final value)) {
      emit(
        state.copyWith(
          statesByCountry: {...state.statesByCountry, countryCode: value},
        ),
      );
    }
  }

  Future<void> _loadLgas(String stateId) async {
    if (state.lgasByState.containsKey(stateId)) return;
    final result = await _repository.lgas(stateId);
    if (isClosed) return;
    if (result case Ok(:final value)) {
      emit(state.copyWith(lgasByState: {...state.lgasByState, stateId: value}));
    }
  }

  /// A correction's new files aren't needed once the user leaves without
  /// sending it.
  @override
  Future<void> close() async {
    if (state.isQueried && state.submitStatus != SubmitStatus.submitted) {
      for (final path in state.form?.files ?? const <String>[]) {
        await _repository.deleteFile(path);
      }
    }
    return super.close();
  }
}
