import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/attestation_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_options.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';

part 'attestation_reissuance_form_state.dart';

/// The attestation certificate's form, saved on every change. With a
/// [queriedId] it corrects that request instead (in memory only).
class AttestationReissuanceFormCubit
    extends Cubit<AttestationReissuanceFormState> {
  AttestationReissuanceFormCubit(
    this._repository, {
    this.queriedId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const AttestationReissuanceFormState());

  final ReissuanceRepository _repository;
  final String? queriedId;
  final DateTime Function() _now;

  DateTime get today => _now();

  /// Saves run one after another, in order.
  Future<void> _saving = Future.value();

  Future<void> load() async {
    emit(state.copyWith(status: FormStatus.loading));
    final (options, nigeria) = await (
      _repository.options(),
      _repository.states(ReissuanceCodes.nigeria),
    ).wait;
    if (isClosed) return;
    final failure = switch ((options, nigeria)) {
      (Err(:final failure), _) || (_, Err(:final failure)) => failure,
      _ => null,
    };
    if (failure != null) {
      emit(state.copyWith(status: FormStatus.failure, failure: failure));
      return;
    }
    final states = (nigeria as Ok<List<Option>>).value;
    final loaded = (options as Ok<ReissuanceOptions>).value;
    if (queriedId case final id?) {
      final record = await _repository.attestationRecord(id);
      if (isClosed) return;
      switch (record) {
        case Ok(value: final record):
          emit(
            state.copyWith(
              status: FormStatus.ready,
              options: loaded,
              nigeria: states,
              record: record,
            ),
          );
          await Future.wait(record.form.states.map(_loadLgas));
        case Err(:final failure):
          emit(state.copyWith(status: FormStatus.failure, failure: failure));
      }
      return;
    }

    final draft = await _repository.loadDraft();
    if (isClosed) return;
    if (draft == null || draft.certificate == null) {
      emit(state.copyWith(status: FormStatus.missing));
      return;
    }
    var form = draft.attestationForm;
    final isNew = form == null;
    form ??= await _prefilled(draft.ninRecord, states);
    if (isClosed) return;
    emit(
      state.copyWith(
        status: FormStatus.ready,
        options: loaded,
        nigeria: states,
        draft: draft.withAttestationForm(form),
      ),
    );
    if (isNew) _save(state.draft!);
    await Future.wait(form.states.map(_loadLgas));
  }

  /// The NIN's names, sex, phone and state and LGA of
  /// origin (matched by name) are the applicant's.
  Future<AttestationReissuanceForm> _prefilled(
    ApplicantNinRecord nin,
    List<Option> nigeria,
  ) async {
    String? idNamed(List<Option> options, String? name) {
      if (name == null) return null;
      for (final option in options) {
        if (option.label.toLowerCase() == name.trim().toLowerCase()) {
          return option.id;
        }
      }
      return null;
    }

    var applicant = const ApplicantParticulars()
        .set(ApplicantDetail.surname, nin.surname)
        .set(ApplicantDetail.firstName, nin.firstName)
        .set(ApplicantDetail.phone, nin.phone);
    if (nin.sex case final sex?) {
      applicant = applicant.set(
        ApplicantDetail.sex,
        sex == Sex.male ? ReissuanceCodes.male : ReissuanceCodes.female,
      );
    }
    final stateId = idNamed(nigeria, nin.stateOfOrigin);
    if (stateId != null) {
      applicant = applicant.set(ApplicantDetail.stateOfOrigin, stateId);
      await _loadLgas(stateId);
      final lgaId = idNamed(state.lgasOf(stateId), nin.lgaOfOrigin);
      applicant = applicant.set(ApplicantDetail.lgaOfOrigin, lgaId);
    }
    return AttestationReissuanceForm(applicant: applicant);
  }

  void applicantChanged(ApplicantDetail field, String? value) {
    final form = state.form;
    if (form == null) return;
    _update(form.copyWith(applicant: form.applicant.set(field, value)));
    if (field == ApplicantDetail.stateOfOrigin && value != null) {
      unawaited(_loadLgas(value));
    }
  }

  void dateOfBirthChanged(DateTime date) => applicantChanged(
    ApplicantDetail.dateOfBirth,
    DateTime(date.year, date.month, date.day).toIso8601String(),
  );

  void additionalChanged(AdditionalDetail field, String? value) {
    final form = state.form;
    if (form == null) return;
    _update(form.copyWith(additional: form.additional.set(field, value)));
    if ((field == AdditionalDetail.stateOfBirth ||
            field == AdditionalDetail.registrationState) &&
        value != null) {
      unawaited(_loadLgas(value));
    }
  }

  void parentChanged(
    ParentRole role,
    AttestationParentDetail field,
    String? value,
  ) {
    final form = state.form;
    if (form == null) return;
    final parent = form.parent(role).set(field, value);
    _update(
      role == ParentRole.mother
          ? form.copyWith(mother: parent)
          : form.copyWith(father: parent),
    );
    if (field == AttestationParentDetail.state && value != null) {
      unawaited(_loadLgas(value));
    }
  }

  /// Why the affidavit can't be attached, if it can't. Photos only.
  Future<DocumentError?> affidavitPicked({
    required String path,
    required String name,
    required int sizeBytes,
  }) async {
    final error = SupportingDocuments.check(name, sizeBytes);
    if (error != null) return error;
    final kept = await _repository.keepDocument(
      path,
      replacing: state.form?.affidavit?.path,
    );
    final form = state.form;
    if (isClosed || form == null) return null;
    _update(
      form.copyWith(
        affidavit: () =>
            AttachedFile(path: kept, name: name, sizeBytes: sizeBytes),
        keptAffidavit: () => null,
      ),
    );
    return null;
  }

  /// Removes the new affidavit, or a queried request's earlier one.
  Future<void> affidavitRemoved() async {
    final form = state.form;
    if (form == null || !form.hasAffidavit) return;
    final path = form.affidavit?.path;
    _update(form.copyWith(affidavit: () => null, keptAffidavit: () => null));
    if (path != null) await _repository.deleteFile(path);
  }

  /// Stores the applicant's drawn signature, replacing any earlier one.
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

  /// "Next"; on the first step the email must be confirmed too.
  void next({bool emailVerified = true}) {
    final form = state.form;
    if (form == null) return;
    if (!form.isComplete(form.step, today: today) ||
        (form.step == AttestationReissuanceStep.applicant && !emailVerified)) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    if (state.returnToReview) {
      _update(
        form.copyWith(step: AttestationReissuanceStep.review),
        showErrors: false,
      );
      emit(state.copyWith(returnToReview: false));
      return;
    }
    final nextIndex = form.step.index + 1;
    if (nextIndex >= AttestationReissuanceStep.count) return;
    _update(
      form.copyWith(step: AttestationReissuanceStep.values[nextIndex]),
      showErrors: false,
    );
  }

  void previous() {
    final form = state.form;
    if (form == null || form.step.index == 0) return;
    _update(
      form.copyWith(
        step: AttestationReissuanceStep.values[form.step.index - 1],
      ),
      showErrors: false,
    );
  }

  /// "Edit" on the preview: opens [step]; "Next" there returns to the
  /// preview.
  void editStep(AttestationReissuanceStep step) {
    final form = state.form;
    if (form == null) return;
    _update(form.copyWith(step: step), showErrors: false);
    emit(state.copyWith(returnToReview: true));
  }

  /// The preview's "I hereby certify…". Not saved: it must be ticked again
  /// after resuming.
  void declarationChanged({required bool declared}) =>
      emit(state.copyWith(declared: declared));

  /// "Submit" on the preview. On success the payment and the request are
  /// cleared from the device.
  Future<void> submit() async {
    final form = state.form;
    if (form == null || state.submitStatus == SubmitStatus.submitting) {
      return;
    }
    if (!state.canSubmit(today)) {
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
    final result = record != null
        ? await _repository.updateAttestation(record, form)
        : await _repository.submitAttestation(state.draft!);
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

  void _update(AttestationReissuanceForm form, {bool? showErrors}) {
    final record = state.record;
    if (record != null) {
      // A correction stays in memory.
      emit(
        state.copyWith(record: record.withForm(form), showErrors: showErrors),
      );
      return;
    }
    final draft = state.draft!.withAttestationForm(form);
    emit(state.copyWith(draft: draft, showErrors: showErrors));
    _save(draft);
  }

  void _save(ReissuanceDraft draft) =>
      _saving = _saving.then((_) => _repository.saveDraft(draft));

  /// A failed load leaves the dropdown empty; choosing again retries.
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
