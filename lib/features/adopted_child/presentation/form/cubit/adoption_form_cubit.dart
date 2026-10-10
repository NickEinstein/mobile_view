import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/adopted_child_repository.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_draft.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_form.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart'
    show RegistrarLocation;
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

part 'adoption_form_state.dart';

/// The seven-step adopted child form; each finished step is saved to the
/// server.
class AdoptionFormCubit extends Cubit<AdoptionFormState> {
  AdoptionFormCubit(
    this._repository, {
    this.registrarLocation,
    this.queriedId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const AdoptionFormState());

  final AdoptedChildRepository _repository;
  final DateTime Function() _now;

  /// Set when correcting a queried application; kept in memory and resent
  /// whole.
  final String? queriedId;

  /// The signed-in registrar's state and LGA. The
  /// registration state and LGA are fixed to them.
  final RegistrarLocation? registrarLocation;

  AdoptionDraft _located(AdoptionDraft draft) {
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
    final AdoptionReferenceData referenceData;
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
  Future<void> _loadLgas(AdoptionDraft draft) async {
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
      Err(:final failure) => Err<AdoptionReferenceData>(failure),
    };
    if (isClosed) return;
    switch ((record, reference)) {
      case (Ok(value: final record), Ok(value: final data)):
        _statesWithLgas = record.draft.chosenStates;
        emit(
          state.copyWith(
            status: FormStatus.ready,
            referenceData: data,
            // Opens on the review, to see what needs correcting.
            draft: _located(record.draft).copyWith(step: AdoptionStep.review),
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

  void adopterChanged(Adopter adopter, AdopterField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    _update(
      _withAdopter(draft, adopter, draft.adopter(adopter).set(field, value)),
    );
    // A new NIN dismisses the last validation's error.
    if (field == AdopterField.nin && state.ninFailure?.$1 == adopter) {
      emit(state.copyWith(ninFailure: () => null));
    }
  }

  static AdoptionDraft _withAdopter(
    AdoptionDraft draft,
    Adopter adopter,
    AdopterParticulars particulars,
  ) => switch (adopter) {
    Adopter.first => draft.copyWith(adopter1: particulars),
    Adopter.second => draft.copyWith(adopter2: particulars),
  };

  void detailsChanged(AdoptionDetailsField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(details: draft.details.set(field, value)));
  }

  void orderDateChanged(DateTime date) => detailsChanged(
    AdoptionDetailsField.orderDate,
    DateTime(date.year, date.month, date.day).toIso8601String(),
  );

  void informantChanged(InformantField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    var informant = draft.informant.set(field, value);
    // "Yes" copies Adopter 1's residence.
    if (field == InformantField.sameResidence && value == Answer.yes) {
      informant = informant.copyResidenceFrom(draft.adopter1);
    }
    _update(draft.copyWith(informant: informant));
    // A new NIN dismisses the last validation's error.
    if (field == InformantField.nin && state.informantNinFailure != null) {
      emit(state.copyWith(informantNinFailure: () => null));
    }
  }

  /// "Validate" beside the informant's NIN: fills the name, which stays
  /// editable.
  Future<void> validateInformantNin() async {
    final draft = state.draft;
    if (draft == null || state.informantNinChecking) return;
    final nin = draft.informant[InformantField.nin];
    if (nin == null || !RegExp(r'^\d{11}$').hasMatch(nin)) return;
    emit(
      state.copyWith(
        informantNinChecking: true,
        informantNinFailure: () => null,
      ),
    );
    final result = await _repository.lookupNin(nin);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final record):
        final latest = state.draft ?? draft;
        _update(
          latest.copyWith(
            informant: latest.informant
                .set(InformantField.surname, record.surname)
                .set(InformantField.firstName, record.firstName)
                .set(InformantField.middleName, record.middleName)
                .set(InformantField.verifiedNin, nin),
          ),
        );
        emit(
          state.copyWith(
            informantNinChecking: false,
            ninValidations: state.ninValidations + 1,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            informantNinChecking: false,
            informantNinFailure: () => failure,
          ),
        );
    }
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
    AdoptionDocument document, {
    required String path,
    required String name,
    required int sizeBytes,
  }) => _attach(
    path: path,
    name: name,
    sizeBytes: sizeBytes,
    current: state.draft?.documents[document],
    apply: (draft, file) =>
        draft.copyWith(documents: {...draft.documents, document: file}),
  );

  Future<void> documentRemoved(AdoptionDocument document) => _detach(
    state.draft?.documents[document],
    (draft) =>
        draft.copyWith(documents: Map.of(draft.documents)..remove(document)),
  );

  Future<DocumentError?> _attach({
    required String path,
    required String name,
    required int sizeBytes,
    required AttachedFile? current,
    required AdoptionDraft Function(AdoptionDraft, AttachedFile) apply,
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
    AdoptionDraft Function(AdoptionDraft) apply,
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
  void editStep(AdoptionStep step) {
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

  /// "Validate" beside an adopter's NIN; it fills the (editable) name.
  Future<void> validateNin(Adopter adopter) async {
    final draft = state.draft;
    if (draft == null || state.ninChecking != null) return;
    final nin = draft.adopter(adopter)[AdopterField.nin];
    if (nin == null || !RegExp(r'^\d{11}$').hasMatch(nin)) return;
    emit(state.copyWith(ninChecking: () => adopter, ninFailure: () => null));
    final result = await _repository.lookupNin(nin);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final record):
        final latest = state.draft ?? draft;
        _update(
          _withAdopter(
            latest,
            adopter,
            latest
                .adopter(adopter)
                .set(AdopterField.surname, record.surname)
                .set(AdopterField.firstName, record.firstName)
                .set(AdopterField.middleName, record.middleName)
                .set(AdopterField.verifiedNin, nin),
          ),
        );
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
            ninFailure: () => (adopter, failure),
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
    // A correction is sent whole at the end, not section by section.
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
            ? AdoptionStep.review
            : nextIndex < AdoptionStep.count
            ? AdoptionStep.values[nextIndex]
            : saved.step,
      ),
      showErrors: false,
    );
    emit(state.copyWith(isSaving: false, returnToReview: false));
  }

  void previous() {
    final draft = state.draft;
    if (draft == null || draft.step.index == 0 || state.isSaving) return;
    _update(
      draft.copyWith(step: AdoptionStep.values[draft.step.index - 1]),
      showErrors: false,
    );
  }

  /// Completes once every change is safely stored on the device.
  Future<void> flush() => _saving;

  void _update(AdoptionDraft draft, {bool? showErrors}) {
    emit(state.copyWith(draft: draft, showErrors: showErrors));
    unawaited(_loadLgas(draft));
    if (isQueried) return;
    _saving = _saving.then((_) => _repository.saveDraft(draft));
  }
}
