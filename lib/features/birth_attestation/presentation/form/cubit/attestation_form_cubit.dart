import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/cancellation.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

part 'attestation_form_state.dart';

/// The four-step attestation form, saved on every change. With
/// [queriedRecordId] it corrects that record instead (in memory only).
class AttestationFormCubit extends Cubit<AttestationFormState> {
  AttestationFormCubit(
    this._repository, {
    this.queriedRecordId,
    DateTime Function()? now,
    String Function()? newSubmissionKey,
  }) : _now = now ?? DateTime.now,
       _newSubmissionKey = newSubmissionKey ?? _randomKey,
       super(const AttestationFormState());

  final BirthAttestationRepository _repository;
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
    final (draft, reference, payment) = await (
      _repository.loadDraft(),
      _repository.referenceData(),
      _repository.payments.storedPayment(),
    ).wait;
    if (isClosed) return;
    if (payment == null || !payment.isPaid) {
      emit(state.copyWith(status: FormStatus.missingPayment));
      return;
    }
    if (draft == null || draft.facePhoto == null) {
      emit(state.copyWith(status: FormStatus.missingIdentity));
      return;
    }
    switch (reference) {
      case Ok(value: final base):
        // The NIN record names the applicant's state and LGA; matching the
        // LGA needs that state's LGAs, as do the draft's chosen states.
        final ninState = base.stateIdNamed(draft.ninRecord?.stateOfOrigin);
        final wanted = {...draft.chosenStates, ?ninState};
        final withLgas = await _repository.referenceData(withLgasOf: wanted);
        if (isClosed) return;
        final referenceData = switch (withLgas) {
          Ok(:final value) => value,
          Err() => base,
        };
        if (withLgas is Ok) _statesWithLgas = wanted;
        emit(
          state.copyWith(
            status: FormStatus.ready,
            referenceData: referenceData,
            paymentReference: payment.reference,
            lgasUnavailable: withLgas is Err ? wanted : const {},
          ),
        );
        final prefilled = _prefill(draft, referenceData);
        if (prefilled == draft) {
          emit(state.copyWith(draft: draft));
        } else {
          _update(prefilled);
        }
      case Err(:final failure):
        emit(state.copyWith(status: FormStatus.failure, failure: failure));
    }
  }

  Future<void> _loadQueried(String id) async {
    final record = await _repository.details(id);
    final reference = switch (record) {
      Ok(value: final r) => await _repository.referenceData(
        withLgasOf: attestationStates(
          applicant: r.applicant,
          additional: r.additional,
          mother: r.mother,
          father: r.father,
        ),
      ),
      Err(:final failure) => Err<AttestationReferenceData>(failure),
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
            queryReason: record.queryReason,
          ),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(state.copyWith(status: FormStatus.failure, failure: failure));
    }
  }

  /// States whose LGAs are loaded or on their way.
  Set<String> _statesWithLgas = const {};

  /// A state's LGAs are fetched once it is chosen.
  Future<void> _loadLgas(AttestationDraft draft) async {
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

  /// Fills the applicant's details from the NIN record, once.
  AttestationDraft _prefill(
    AttestationDraft draft,
    AttestationReferenceData data,
  ) {
    final record = draft.ninRecord;
    if (record == null || draft.applicant.values.values.isNotEmpty) {
      return draft;
    }
    final stateId = data.stateIdNamed(record.stateOfOrigin);
    var applicant = const ApplicantParticulars();
    for (final (field, value) in [
      (ApplicantField.surname, record.surname),
      (ApplicantField.firstName, record.firstName),
      (ApplicantField.middleName, record.middleName),
      (
        ApplicantField.sex,
        switch (record.sex) {
          Sex.male => AttestationReferenceData.maleId,
          Sex.female => AttestationReferenceData.femaleId,
          null => null,
        },
      ),
      (ApplicantField.dateOfBirth, _isoDate(record.dateOfBirth)),
      (ApplicantField.phone, record.phone),
      (ApplicantField.stateOfOrigin, stateId),
      (
        ApplicantField.lgaOfOrigin,
        data.lgaIdNamed(stateId, record.lgaOfOrigin),
      ),
    ]) {
      applicant = applicant.set(field, value);
    }
    return draft.copyWith(applicant: applicant);
  }

  static String _isoDate(DateTime date) =>
      DateTime(date.year, date.month, date.day).toIso8601String();

  void applicantChanged(ApplicantField field, String? value) {
    final draft = state.draft;
    if (draft == null || state.isLocked(field)) return;
    _update(draft.copyWith(applicant: draft.applicant.set(field, value)));
  }

  void dateOfBirthChanged(DateTime date) =>
      applicantChanged(ApplicantField.dateOfBirth, _isoDate(date));

  void additionalChanged(AdditionalField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(additional: draft.additional.set(field, value)));
  }

  void parentChanged(Parent parent, ParentInfoField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    final info = draft.parent(parent).set(field, value);
    var next = switch (parent) {
      Parent.mother => draft.copyWith(mother: info),
      Parent.father => draft.copyWith(father: info),
    };
    // A Nigerian parent gives no passport: drop one picked earlier.
    final passport = next.documents[parent.passport];
    if (!info.needsPassport && passport != null) {
      next = next.copyWith(
        documents: next.documents.set(parent.passport, null),
      );
      unawaited(_repository.deleteFile(passport.path));
    }
    _update(next);
  }

  /// Checks and stores a picked image. Returns why it was refused, if it
  /// was.
  Future<DocumentError?> documentPicked(
    AttestationDocument document, {
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

  Future<void> documentRemoved(AttestationDocument document) async {
    final draft = state.draft;
    final file = draft?.documents[document];
    if (draft == null || file == null) return;
    _update(draft.copyWith(documents: draft.documents.set(document, null)));
    await _repository.deleteFile(file.path);
  }

  /// "Save & Continue" / "Next". Shows the errors instead if the step is
  /// incomplete.
  void next() {
    final draft = state.draft;
    if (draft == null) return;
    if (!state.isStepComplete(today)) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    if (state.returnToReview) {
      _update(draft.copyWith(step: AttestationStep.review), showErrors: false);
      emit(state.copyWith(returnToReview: false));
      return;
    }
    final nextIndex = draft.step.index + 1;
    if (nextIndex >= AttestationStep.count) return;
    _update(
      draft.copyWith(step: AttestationStep.values[nextIndex]),
      showErrors: false,
    );
  }

  void previous() {
    final draft = state.draft;
    if (draft == null || draft.step.index == 0) return;
    _update(
      draft.copyWith(step: AttestationStep.values[draft.step.index - 1]),
      showErrors: false,
    );
  }

  /// "Edit" on the review: opens [step]; "Next" there returns to the review.
  void editStep(AttestationStep step) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(step: step), showErrors: false);
    emit(state.copyWith(returnToReview: true));
  }

  void declarationChanged({required bool declared}) =>
      emit(state.copyWith(declared: declared));

  /// Sends the application. On success the draft, its files and the used
  /// payment are cleared from the device.
  Future<void> submit() async {
    final draft = state.draft;
    final reference = state.paymentReference;
    if (draft == null ||
        (reference == null && draft.queried == null) ||
        state.submitStatus == SubmitStatus.submitting) {
      return;
    }
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
    if (keyed.queried case final queried?) {
      return _sendCorrection(keyed, queried.certificateNumber);
    }
    final result = await _repository.submit(
      keyed,
      cancellation: _submission = Cancellation(),
      paymentReference: reference!,
      onProgress: (sent, total) {
        if (!isClosed && total > 0) {
          emit(state.copyWith(progress: () => sent / total));
        }
      },
    );
    if (isClosed) return;
    switch (result) {
      case Ok(value: final trackingId):
        await _repository.discardDraft();
        await _repository.payments.clearPayment();
        if (isClosed) return;
        emit(
          state.copyWith(
            submitStatus: SubmitStatus.submitted,
            trackingId: trackingId,
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

  Future<void> _sendCorrection(
    AttestationDraft draft,
    String certificateNumber,
  ) async {
    final result = await _repository.updateQueried(draft);
    if (isClosed) return;
    emit(switch (result) {
      Ok() => state.copyWith(
        submitStatus: SubmitStatus.submitted,
        trackingId: certificateNumber,
      ),
      Err(:final failure) => state.copyWith(
        submitStatus: SubmitStatus.failed,
        submitFailure: () => failure,
      ),
    });
  }

  /// Completes once every change is safely stored.
  Future<void> flush() => _saving;

  void _update(AttestationDraft draft, {bool? showErrors}) {
    emit(state.copyWith(draft: draft, showErrors: showErrors));
    unawaited(_loadLgas(draft));
    // A correction lives only in memory; the record is on the server.
    if (draft.queried != null) return;
    _saving = _saving.then((_) => _repository.saveDraft(draft));
  }
}
