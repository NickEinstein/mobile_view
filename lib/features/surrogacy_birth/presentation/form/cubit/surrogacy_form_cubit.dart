import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart'
    show RegistrarLocation;
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_form.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_reference_data.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/surrogacy_birth_repository.dart';

part 'surrogacy_form_state.dart';

/// The eight-step surrogacy birth form; each finished step is saved to
/// the server.
class SurrogacyFormCubit extends Cubit<SurrogacyFormState> {
  SurrogacyFormCubit(
    this._repository, {
    this.registrarLocation,
    this.queriedId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const SurrogacyFormState());

  final SurrogacyBirthRepository _repository;
  final DateTime Function() _now;

  /// Set when correcting a queried application; kept in memory and resent
  /// whole.
  final String? queriedId;

  /// The signed-in registrar's state and LGA. The
  /// registration state and LGA are fixed to them.
  final RegistrarLocation? registrarLocation;

  SurrogacyDraft _located(SurrogacyDraft draft) {
    final location = registrarLocation;
    if (location == null) return draft;
    var child = draft.child;
    if (child[ChildField.registrationState] != location.stateId) {
      child = child.set(ChildField.registrationState, location.stateId);
    }
    if (child[ChildField.registrationLga] != location.lgaId) {
      child = child.set(ChildField.registrationLga, location.lgaId);
    }
    return child == draft.child ? draft : draft.copyWith(child: child);
  }

  bool get isQueried => queriedId != null;

  /// Device saves run one after another, in order.
  Future<void> _saving = Future.value();

  DateTime get today => _now();

  Future<void> load() async {
    emit(state.copyWith(status: FormStatus.loading));
    if (queriedId case final id?) return _loadQueried(id);
    final (stored, reference) = await (
      _repository.loadDraft(),
      _repository.referenceData(),
    ).wait;
    if (isClosed) return;
    if (stored == null || stored.ninDecision == null) {
      emit(state.copyWith(status: FormStatus.notStarted));
      return;
    }
    final SurrogacyReferenceData referenceData;
    switch (reference) {
      case Ok(:final value):
        referenceData = value;
      case Err(:final failure):
        _fail(failure);
        return;
    }

    var draft = stored;
    if (draft.paymentReference == null) {
      // Paid but not yet attached to the application (on returning from
      // the gateway).
      final payment = await _repository.payments.storedPayment();
      if (isClosed) return;
      if (payment == null || !payment.isPaid) {
        emit(state.copyWith(status: FormStatus.notPaid));
        return;
      }
      final attached = await _repository.attachPayment(
        referenceId: draft.referenceId,
        reference: payment.reference,
      );
      if (isClosed) return;
      if (attached case Err(:final failure)) {
        _fail(failure);
        return;
      }
      draft = draft.copyWith(paymentReference: payment.reference);
      await _repository.saveDraft(draft);
      if (isClosed) return;
    }
    final located = _located(draft);
    if (located != draft) {
      draft = located;
      await _repository.saveDraft(draft);
      if (isClosed) return;
    }
    emit(
      state.copyWith(
        status: FormStatus.ready,
        draft: draft,
        referenceData: referenceData,
      ),
    );
    // The draft's states' LGAs follow; if they fail, only those fields
    // say so.
    await _loadLgas(draft);
  }

  /// States whose LGAs are loaded or on their way.
  Set<String> _statesWithLgas = const {};

  /// A state's LGAs are fetched once it is chosen.
  Future<void> _loadLgas(SurrogacyDraft draft) async {
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

  Future<void> _loadQueried(String id) async {
    final record = await _repository.details(id);
    final reference = switch (record) {
      Ok(value: final r) => await _repository.referenceData(
        withLgasOf: r.draft.chosenStates,
      ),
      Err(:final failure) => Err<SurrogacyReferenceData>(failure),
    };
    if (isClosed) return;
    switch ((record, reference)) {
      case (Ok(value: final record), Ok(value: final data)):
        _statesWithLgas = record.draft.chosenStates;
        emit(
          state.copyWith(
            status: FormStatus.ready,
            referenceData: data,
            draft:
                _located(
                  record.draft.withRegistrationLocation(data.locationOfCenter),
                )
                // Opens on the review, to see what needs correcting.
                .copyWith(step: SurrogacyStep.review),
            queryReason: record.remarks,
          ),
        );
        // The registrar's state, if the record had another.
        unawaited(_loadLgas(state.draft!));
      case (Err(:final failure), _) || (_, Err(:final failure)):
        _fail(failure);
    }
  }

  void _fail(Failure failure) {
    if (!isClosed) {
      emit(state.copyWith(status: FormStatus.failure, failure: failure));
    }
  }

  void childChanged(ChildField field, String? value) {
    final draft = state.draft;
    if (draft == null || draft.isLocked(field)) return;
    _update(draft.copyWith(child: draft.child.set(field, value)));
  }

  void childDateChanged(ChildField field, DateTime date) => childChanged(
    field,
    DateTime(date.year, date.month, date.day).toIso8601String(),
  );

  /// Stores the camera photo privately, replacing any earlier one.
  Future<void> childPhotoCaptured(String capturedPath) async {
    final draft = state.draft;
    if (draft == null) return;
    final previous = draft.child[ChildField.facePhoto];
    final path = await _repository.keepPhoto(capturedPath, replacing: previous);
    final latest = state.draft;
    if (isClosed || latest == null) return;
    _update(
      latest.copyWith(
        child: latest.child.set(ChildField.facePhoto, path),
        uploads: Map<String, String>.of(latest.uploads)..remove(previous),
      ),
    );
  }

  void surrogacyChanged(SurrogacyDetailsField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(surrogacy: draft.surrogacy.set(field, value)));
  }

  void orderDateChanged(DateTime date) => surrogacyChanged(
    SurrogacyDetailsField.orderDate,
    DateTime(date.year, date.month, date.day).toIso8601String(),
  );

  void legalParentChanged(
    SurrogacyPerson person,
    ParentField field,
    String? value,
  ) {
    final draft = state.draft;
    if (draft == null) return;
    _update(switch (person) {
      SurrogacyPerson.legalFather => draft.copyWith(
        legalFather: draft.legalFather.set(field, value),
      ),
      _ => draft.copyWith(legalMother: draft.legalMother.set(field, value)),
    });
  }

  void surrogateMotherChanged(SurrogateField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    _update(
      draft.copyWith(surrogateMother: draft.surrogateMother.set(field, value)),
    );
  }

  /// "Is a second legal parent (Father) named in the court order?"
  void hasLegalFatherChanged({required bool named}) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(hasLegalFather: named));
  }

  /// "Validate" beside a parent's NIN; it fills the (editable) name.
  Future<void> validateNin(SurrogacyPerson person) async {
    final draft = state.draft;
    if (draft == null || state.ninChecking != null) return;
    final nin = switch (person) {
      SurrogacyPerson.legalMother => draft.legalMother[ParentField.nin],
      SurrogacyPerson.legalFather => draft.legalFather[ParentField.nin],
      SurrogacyPerson.surrogateMother =>
        draft.surrogateMother[SurrogateField.nin],
      SurrogacyPerson.informant => draft.informant[InformantField.nin],
    };
    if (nin == null || !RegExp(r'^\d{11}$').hasMatch(nin)) return;
    emit(state.copyWith(ninChecking: () => person, ninFailure: () => null));
    final result = await _repository.lookupNin(nin);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final record):
        final latest = state.draft ?? draft;
        ParentParticulars parent(ParentParticulars p) => p
            .set(ParentField.surname, record.surname)
            .set(ParentField.firstName, record.firstName)
            .set(ParentField.middleName, record.middleName)
            .set(ParentField.verifiedNin, nin);
        _update(switch (person) {
          SurrogacyPerson.legalMother => latest.copyWith(
            legalMother: parent(latest.legalMother),
          ),
          SurrogacyPerson.legalFather => latest.copyWith(
            legalFather: parent(latest.legalFather),
          ),
          SurrogacyPerson.surrogateMother => latest.copyWith(
            surrogateMother: latest.surrogateMother
                .set(SurrogateField.surname, record.surname)
                .set(SurrogateField.firstName, record.firstName)
                .set(SurrogateField.middleName, record.middleName)
                .set(SurrogateField.verifiedNin, nin),
          ),
          SurrogacyPerson.informant => latest.copyWith(
            informant: latest.informant
                .set(InformantField.surname, record.surname)
                .set(InformantField.firstName, record.firstName)
                .set(InformantField.middleName, record.middleName)
                .set(InformantField.verifiedNin, nin),
          ),
        });
        emit(
          state.copyWith(
            ninChecking: () => null,
            ninValidations: state.ninValidations + 1,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            ninChecking: () => null,
            ninFailure: () => (person, failure),
          ),
        );
    }
  }

  /// "Save & Continue" / "Next": shows the errors if the step is
  /// incomplete; otherwise saves its section on the server and moves on.
  Future<void> next() async {
    final draft = state.draft;
    if (draft == null || state.isSaving) return;
    if (!state.isStepComplete(today)) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    final section = isQueried ? null : draft.step.section;
    var saved = draft;
    if (section != null) {
      emit(state.copyWith(isSaving: true, saveFailure: () => null));
      await flush();
      final result = await _repository.saveSection(draft, section);
      if (isClosed) return;
      switch (result) {
        case Ok(:final value):
          // Keep what changed while saving; add the uploads.
          saved = (state.draft ?? draft).copyWith(uploads: value.uploads);
        case Err(:final failure):
          emit(state.copyWith(isSaving: false, saveFailure: () => failure));
          return;
      }
    }
    final nextIndex = saved.step.index + 1;
    _update(
      saved.copyWith(
        step: state.returnToReview
            ? SurrogacyStep.review
            : nextIndex < SurrogacyStep.count
            ? SurrogacyStep.values[nextIndex]
            : saved.step,
      ),
      showErrors: false,
    );
    emit(state.copyWith(isSaving: false, returnToReview: false));
  }

  void informantChanged(InformantField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    var informant = draft.informant.set(field, value);
    // "Yes" copies the legal mother's residence.
    if (field == InformantField.sameResidence && value == Answer.yes) {
      informant = informant.copyResidenceFrom(draft.legalMother);
    }
    _update(draft.copyWith(informant: informant));
  }

  /// Stores the drawn signature, replacing any earlier one.
  Future<void> informantSignatureDrawn(Uint8List png) async {
    final previous = state.draft?.informant[InformantField.signature];
    final path = await _repository.keepSignature(png, replacing: previous);
    _setInformantFile(InformantField.signature, path, previous);
  }

  Future<void> informantSignatureCleared() async {
    final previous = state.draft?.informant[InformantField.signature];
    if (previous == null) return;
    _setInformantFile(InformantField.signature, null, previous);
    await _repository.deleteFile(previous);
  }

  /// Stores the camera photo privately, replacing any earlier one.
  Future<void> informantFaceCaptured(String capturedPath) async {
    final previous = state.draft?.informant[InformantField.face];
    final path = await _repository.keepPhoto(capturedPath, replacing: previous);
    _setInformantFile(InformantField.face, path, previous);
  }

  void _setInformantFile(InformantField field, String? path, String? old) {
    final latest = state.draft;
    if (isClosed || latest == null) return;
    _update(
      latest.copyWith(
        informant: latest.informant.set(field, path),
        uploads: Map<String, String>.of(latest.uploads)..remove(old),
      ),
    );
  }

  /// Keeps a picked photo of the informant's passport. Returns why it
  /// can't be used, if it can't.
  Future<DocumentError?> passportPicked({
    required String path,
    required String name,
    required int sizeBytes,
  }) => _attach(
    path: path,
    name: name,
    sizeBytes: sizeBytes,
    current: state.draft?.informantPassport,
    apply: (draft, file) => draft.copyWith(informantPassport: () => file),
  );

  Future<void> passportRemoved() => _detach(
    state.draft?.informantPassport,
    (draft) => draft.copyWith(informantPassport: () => null),
  );

  /// Keeps a picked photo of [document]. Returns why it can't be used, if
  /// it can't.
  Future<DocumentError?> documentPicked(
    SurrogacyDocument document, {
    required String path,
    required String name,
    required int sizeBytes,
  }) => _attach(
    path: path,
    name: name,
    sizeBytes: sizeBytes,
    current: state.draft?.documents[document],
    apply: (draft, file) =>
        draft.copyWith(documents: {...draft.documents, document: file!}),
  );

  Future<void> documentRemoved(SurrogacyDocument document) => _detach(
    state.draft?.documents[document],
    (draft) =>
        draft.copyWith(documents: Map.of(draft.documents)..remove(document)),
  );

  Future<DocumentError?> _attach({
    required String path,
    required String name,
    required int sizeBytes,
    required AttachedFile? current,
    required SurrogacyDraft Function(SurrogacyDraft, AttachedFile?) apply,
  }) async {
    final error = SupportingDocuments.check(name, sizeBytes);
    if (error != null) return error;
    final kept = await _repository.keepDocument(path, replacing: current?.path);
    final latest = state.draft;
    if (isClosed || latest == null) return null;
    _update(
      apply(
        latest,
        AttachedFile(path: kept, name: name, sizeBytes: sizeBytes),
      ).copyWith(
        uploads: Map<String, String>.of(latest.uploads)..remove(current?.path),
      ),
    );
    return null;
  }

  Future<void> _detach(
    AttachedFile? current,
    SurrogacyDraft Function(SurrogacyDraft) apply,
  ) async {
    final draft = state.draft;
    if (draft == null || current == null) return;
    _update(
      apply(draft).copyWith(
        uploads: Map<String, String>.of(draft.uploads)..remove(current.path),
      ),
    );
    await _repository.deleteFile(current.path);
  }

  /// "Edit" on the review: opens [step]; finishing it returns to the
  /// review.
  void editStep(SurrogacyStep step) {
    final draft = state.draft;
    if (draft == null || state.isSaving) return;
    _update(draft.copyWith(step: step), showErrors: false);
    emit(state.copyWith(returnToReview: true));
  }

  void declarationChanged({required bool declared}) =>
      emit(state.copyWith(declared: declared));

  /// "Submit": the server finalises the application; then the payment and
  /// draft are cleared.
  Future<void> submit() async {
    final draft = state.draft;
    if (draft == null || state.submitStatus == SubmitStatus.submitting) return;
    if (!state.canSubmit(today)) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    emit(
      state.copyWith(
        submitStatus: SubmitStatus.submitting,
        saveFailure: () => null,
      ),
    );
    await flush();
    if (isQueried) {
      final amended = await _repository.amend(draft);
      if (isClosed) return;
      emit(switch (amended) {
        Ok() => state.copyWith(
          submitStatus: SubmitStatus.submitted,
          trackingId: draft.referenceId,
        ),
        Err(:final failure) => state.copyWith(
          submitStatus: SubmitStatus.idle,
          saveFailure: () => failure,
        ),
      });
      return;
    }
    final result = await _repository.submit(draft.referenceId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        await _repository.payments.clearPayment();
        await _repository.discardDraft();
        if (isClosed) return;
        emit(
          state.copyWith(
            submitStatus: SubmitStatus.submitted,
            trackingId: value ?? draft.referenceId,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            submitStatus: SubmitStatus.idle,
            saveFailure: () => failure,
          ),
        );
    }
  }

  void previous() {
    final draft = state.draft;
    if (draft == null || draft.step.index == 0 || state.isSaving) return;
    _update(
      draft.copyWith(step: SurrogacyStep.values[draft.step.index - 1]),
      showErrors: false,
    );
  }

  /// Completes once every change is safely stored on the device.
  Future<void> flush() => _saving;

  void _update(SurrogacyDraft draft, {bool? showErrors}) {
    emit(state.copyWith(draft: draft, showErrors: showErrors));
    unawaited(_loadLgas(draft));
    if (isQueried) return;
    _saving = _saving.then((_) => _repository.saveDraft(draft));
  }
}
