import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_draft.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_form.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_record.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_reference_data.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/foreign_birth_repository.dart';

part 'foreign_birth_form_state.dart';

/// The foreign birth notification form, saved on the device on every
/// change.
class ForeignBirthFormCubit extends Cubit<ForeignBirthFormState> {
  ForeignBirthFormCubit(
    this._repository, {
    this.queriedId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const ForeignBirthFormState());

  final ForeignBirthRepository _repository;
  final DateTime Function() _now;

  /// Set when correcting a queried notification; kept in memory and resent
  /// whole.
  final String? queriedId;

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
    final ForeignBirthReferenceData referenceData;
    switch (reference) {
      case Ok(:final value):
        referenceData = value;
      case Err(:final failure):
        emit(state.copyWith(status: FormStatus.failure, failure: failure));
        return;
    }

    var draft = stored;
    if (draft?.paymentReference == null) {
      // Just paid: the notification starts here, carrying the reference.
      final payment = await _repository.payments.storedPayment();
      if (isClosed) return;
      if (payment == null || !payment.isPaid) {
        emit(state.copyWith(status: FormStatus.notPaid));
        return;
      }
      final day = today;
      draft = (draft ?? ForeignBirthDraft(startedOn: day)).copyWith(
        paymentReference: payment.reference,
      );
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
    await _loadPlaces(draft!);
  }

  Future<void> _loadQueried(String id) async {
    final (record, reference) = await (
      _repository.details(id),
      _repository.referenceData(),
    ).wait;
    if (isClosed) return;
    switch ((record, reference)) {
      case (Ok(value: final record), Ok(value: final data)):
        // Opens on the review, to see what needs correcting.
        final draft = record.draft.copyWith(step: ForeignBirthStep.review);
        emit(
          state.copyWith(
            status: FormStatus.ready,
            draft: draft,
            referenceData: data,
            record: record,
          ),
        );
        await _loadPlaces(draft);
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(state.copyWith(status: FormStatus.failure, failure: failure));
    }
  }

  /// Loads the states of every country chosen so far, and the LGAs of
  /// every Nigerian state, that aren't loaded yet.
  Future<void> _loadPlaces(ForeignBirthDraft draft) async {
    final countries = draft.countryIds.where(
      (id) => !state.states.containsKey(id),
    );
    final nigerianStates = draft.nigerianStateIds.where(
      (id) => !state.lgas.containsKey(id),
    );
    if (countries.isEmpty && nigerianStates.isEmpty) return;

    final (states, lgas) = await (
      Future.wait([
        for (final id in countries)
          _repository.states(id).then((result) => (id, result)),
      ]),
      Future.wait([
        for (final id in nigerianStates)
          _repository.lgas(id).then((result) => (id, result)),
      ]),
    ).wait;
    if (isClosed) return;
    Failure? failure;
    Map<String, List<Option>> merge(
      Map<String, List<Option>> loaded,
      List<(String, Result<List<Option>>)> results,
    ) {
      final merged = Map.of(loaded);
      for (final (id, result) in results) {
        switch (result) {
          case Ok(:final value):
            merged[id] = value;
          case Err(failure: final error):
            failure = error;
        }
      }
      return merged;
    }

    emit(
      state.copyWith(
        states: merge(state.states, states),
        lgas: merge(state.lgas, lgas),
        placesFailure: () => failure,
      ),
    );
  }

  void childChanged(ChildField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(child: draft.child.set(field, value)));
  }

  void childDateChanged(ChildField field, DateTime date) => childChanged(
    field,
    DateTime(date.year, date.month, date.day).toIso8601String(),
  );

  /// Stores the camera photo privately, replacing any earlier one.
  Future<void> childPhotoCaptured(String capturedPath) async {
    final previous = state.draft?.child[ChildField.facePhoto];
    final path = await _repository.keepPhoto(capturedPath, replacing: previous);
    final latest = state.draft;
    if (isClosed || latest == null) return;
    _update(
      latest.copyWith(child: latest.child.set(ChildField.facePhoto, path)),
    );
  }

  void parentChanged(Parent parent, ParentField field, String? value) {
    final draft = state.draft;
    if (draft == null || draft.parent(parent).isLocked(field)) return;
    var particulars = draft.parent(parent).set(field, value);
    // "Yes" copies the mother's residence.
    if (field == ParentField.sameResidence && value == Answer.yes) {
      particulars = particulars.copyResidenceFrom(draft.mother);
    }
    _update(draft.withParent(parent, particulars));
    // A new NIN dismisses the last validation's error.
    if (field == ParentField.nin && state.ninFailure?.$1 == parent) {
      emit(state.copyWith(ninFailure: () => null));
    }
  }

  /// "Validate" beside a parent's NIN: the identity service must know it.
  /// It then fills (and locks) the name.
  Future<void> validateNin(Parent parent) async {
    final draft = state.draft;
    if (draft == null || state.ninChecking != null) return;
    final nin = draft.parent(parent)[ParentField.nin];
    if (nin == null || !RegExp(r'^\d{11}$').hasMatch(nin)) return;
    emit(state.copyWith(ninChecking: () => parent, ninFailure: () => null));
    final result = await _repository.lookupNin(nin);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final record):
        final latest = state.draft ?? draft;
        _update(
          latest.withParent(
            parent,
            latest
                .parent(parent)
                .set(ParentField.surname, record.surname)
                .set(ParentField.firstName, record.firstName)
                .set(ParentField.middleName, record.middleName)
                .set(ParentField.verifiedNin, nin),
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
            ninFailure: () => (parent, failure),
          ),
        );
    }
  }

  void informantChanged(InformantField field, String? value) {
    final draft = state.draft;
    if (draft == null || draft.informant.isLocked(field)) return;
    var informant = draft.informant.set(field, value);
    switch ((field, value)) {
      // The father or the mother is the informant, so
      // their particulars fill the informant's.
      case (InformantField.relationship, ForeignBirthCodes.father):
        informant = informant.copyFrom(draft.father);
      case (InformantField.relationship, ForeignBirthCodes.mother):
        informant = informant.copyFrom(draft.mother);
      case (InformantField.sameResidence, Answer.yes):
        informant = informant.copyResidenceFrom(draft.mother);
    }
    _update(draft.copyWith(informant: informant));
    // A new NIN dismisses the last validation's error.
    if (field == InformantField.nin && state.informantNinFailure != null) {
      emit(state.copyWith(informantNinFailure: () => null));
    }
  }

  /// "Validate" beside the informant's NIN: fills and locks the name.
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

  /// Keeps a picked photo of the foreign birth certificate. Returns why it
  /// can't be used, if it can't.
  Future<DocumentError?> certificatePicked({
    required String path,
    required String name,
    required int sizeBytes,
  }) async {
    final error = SupportingDocuments.check(name, sizeBytes);
    if (error != null) return error;
    final current = state.draft?.certificate;
    final kept = await _repository.keepDocument(path, replacing: current?.path);
    final latest = state.draft;
    if (isClosed || latest == null) return null;
    _update(
      latest.copyWith(
        certificate: () =>
            AttachedFile(path: kept, name: name, sizeBytes: sizeBytes),
        uploads: Map<String, String>.of(latest.uploads)..remove(current?.path),
      ),
    );
    return null;
  }

  Future<void> certificateRemoved() async {
    final draft = state.draft;
    final current = draft?.certificate;
    if (draft == null || current == null) return;
    _update(
      draft.copyWith(
        certificate: () => null,
        uploads: Map<String, String>.of(draft.uploads)..remove(current.path),
      ),
    );
    await _repository.deleteFile(current.path);
  }

  void declarationChanged({required bool declared}) =>
      emit(state.copyWith(declared: declared));

  /// "Submit": uploads the files, then sends the whole notification with
  /// the paid reference. The payment and the draft are then cleared.
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
        submitFailure: () => null,
      ),
    );
    await flush();
    final uploaded = await _repository.uploadFiles(draft);
    if (isClosed) return;
    final ForeignBirthDraft ready;
    switch (uploaded) {
      case Ok(:final value):
        ready = value;
        // Kept, so a retry doesn't upload them again.
        _update(ready);
      case Err(:final failure):
        _submitFailed(failure);
        return;
    }
    if (state.record case final record?) return _amend(ready, record);
    final result = await _repository.submit(ready);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        await flush();
        await _repository.payments.clearPayment();
        await _repository.discardDraft();
        if (isClosed) return;
        emit(
          state.copyWith(
            submitStatus: SubmitStatus.submitted,
            trackingId: value ?? ready.paymentReference,
          ),
        );
      case Err(:final failure):
        _submitFailed(failure);
    }
  }

  Future<void> _amend(
    ForeignBirthDraft draft,
    ForeignBirthRecord record,
  ) async {
    final result = await _repository.amend(draft, record: record);
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            submitStatus: SubmitStatus.submitted,
            trackingId: record.notificationNumber ?? '${record.id}',
          ),
        );
      case Err(:final failure):
        _submitFailed(failure);
    }
  }

  void _submitFailed(Failure failure) => emit(
    state.copyWith(
      submitStatus: SubmitStatus.idle,
      submitFailure: () => failure,
    ),
  );

  /// "Edit" on the review: opens [step]; finishing it returns to the
  /// review.
  void editStep(ForeignBirthStep step) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(step: step), showErrors: false);
    emit(state.copyWith(returnToReview: true));
  }

  /// "Save & Continue" / "Next": shows the errors if the step is
  /// incomplete; otherwise moves on.
  void next() {
    final draft = state.draft;
    if (draft == null) return;
    if (!state.isStepComplete(today)) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    final nextIndex = draft.step.index + 1;
    _update(
      draft.copyWith(
        step: state.returnToReview
            ? ForeignBirthStep.review
            : nextIndex < ForeignBirthStep.count
            ? ForeignBirthStep.values[nextIndex]
            : draft.step,
      ),
      showErrors: false,
    );
    emit(state.copyWith(returnToReview: false));
  }

  void previous() {
    final draft = state.draft;
    if (draft == null || draft.step.index == 0) return;
    _update(
      draft.copyWith(step: ForeignBirthStep.values[draft.step.index - 1]),
      showErrors: false,
    );
  }

  /// Completes once every change is safely stored on the device.
  Future<void> flush() => _saving;

  void _update(ForeignBirthDraft draft, {bool? showErrors}) {
    emit(state.copyWith(draft: draft, showErrors: showErrors));
    if (!isQueried) {
      _saving = _saving.then((_) => _repository.saveDraft(draft));
    }
    // A new country or Nigerian state needs its places.
    _loadPlaces(draft).ignore();
  }
}
