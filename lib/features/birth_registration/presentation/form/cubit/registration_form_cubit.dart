import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/cancellation.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';

part 'registration_form_state.dart';

/// The six-step form. Every change is saved to the draft straight away, so
/// the user can leave at any point and continue later.
class RegistrationFormCubit extends Cubit<RegistrationFormState> {
  RegistrationFormCubit(
    this._repository, {
    DateTime Function()? now,
    String Function()? newSubmissionKey,
  }) : _now = now ?? DateTime.now,
       _newSubmissionKey = newSubmissionKey ?? _randomKey,
       super(const RegistrationFormState());

  final BirthRegistrationRepository _repository;
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
    final draft =
        await _repository.loadDraft() ?? RegistrationDraft(startedOn: _now());
    final reference = await _repository.referenceData();
    if (isClosed) return;
    switch (reference) {
      case Ok(value: final referenceData):
        // The draft's states' LGAs follow; if they fail, only those
        // fields say so.
        unawaited(_loadLgas(draft));
        emit(
          state.copyWith(
            status: FormStatus.ready,
            draft: draft,
            referenceData: referenceData,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(status: FormStatus.failure, failure: failure));
    }
  }

  /// States whose LGAs are loaded or on their way.
  Set<String> _statesWithLgas = const {};

  /// A state's LGAs are fetched once it is chosen.
  Future<void> _loadLgas(RegistrationDraft draft) async {
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

  void childChanged(ChildField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(child: draft.child.set(field, value)));
  }

  Future<void> childPhotoCaptured(String capturedPath) async {
    final draft = state.draft;
    if (draft == null) return;
    final path = await _repository.keepPhoto(
      capturedPath,
      replacing: draft.child[ChildField.facePhoto],
    );
    if (isClosed) return;
    childChanged(ChildField.facePhoto, path);
  }

  void parentChanged(ParentRole role, ParentField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    _update(switch (role) {
      ParentRole.mother => draft.copyWith(
        mother: draft.mother.set(field, value),
      ),
      ParentRole.father => draft.copyWith(
        father: draft.father.set(field, value),
      ),
    });
  }

  void informantChanged(InformantField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(informant: draft.informant.set(field, value)));
  }

  Future<void> informantPhotoCaptured(String capturedPath) async {
    final draft = state.draft;
    if (draft == null) return;
    final path = await _repository.keepPhoto(
      capturedPath,
      replacing: draft.informant[InformantField.facePhoto],
    );
    if (isClosed) return;
    informantChanged(InformantField.facePhoto, path);
  }

  /// Stores the informant's drawn signature (a PNG).
  Future<void> signatureDrawn(Uint8List png) async {
    final draft = state.draft;
    if (draft == null) return;
    final path = await _repository.keepSignature(
      png,
      replacing: draft.informant[InformantField.signature],
    );
    if (isClosed) return;
    informantChanged(InformantField.signature, path);
  }

  Future<void> signatureCleared() async {
    final path = state.draft?.informant[InformantField.signature];
    if (path == null) return;
    informantChanged(InformantField.signature, null);
    await _repository.deleteFile(path);
  }

  /// Checks and stores a picked image. Returns why it was refused, if it
  /// was.
  Future<DocumentError?> documentPicked(
    DocumentType type, {
    required String path,
    required String name,
    required int sizeBytes,
  }) async {
    final error = SupportingDocuments.check(name, sizeBytes);
    final draft = state.draft;
    if (error != null || draft == null) return error;
    final kept = await _repository.keepDocument(
      path,
      replacing: draft.documents[type]?.path,
    );
    final latest = state.draft;
    if (isClosed || latest == null) return null;
    final file = AttachedFile(path: kept, name: name, sizeBytes: sizeBytes);
    _update(latest.copyWith(documents: latest.documents.set(type, file)));
    return null;
  }

  Future<void> documentRemoved(DocumentType type) async {
    final draft = state.draft;
    final file = draft?.documents[type];
    if (draft == null || file == null) return;
    _update(draft.copyWith(documents: draft.documents.set(type, null)));
    await _repository.deleteFile(file.path);
  }

  /// "Edit" on the review: opens [step]; "Next" there returns to the review.
  void editStep(RegistrationStep step) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(step: step), showErrors: false);
    emit(state.copyWith(returnToReview: true));
  }

  void declarationChanged({required bool declared}) =>
      emit(state.copyWith(declared: declared));

  /// Sends the application. On success the draft and its files are deleted
  /// from the device.
  Future<void> submit() async {
    final draft = state.draft;
    if (draft == null || state.submitStatus == SubmitStatus.submitting) return;
    if (!state.canSubmit(today)) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    // The date of birth may have changed since Step 1.
    if (!draft.isPaidFor(today)) {
      await _requestPayment();
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
    final result = await _repository.submit(
      keyed,
      cancellation: _submission = Cancellation(),
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

  /// "Save & Continue" / "Next". Shows the errors instead if the step is
  /// incomplete.
  void next() {
    final draft = state.draft;
    if (draft == null) return;
    if (!state.isStepComplete(today)) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    // The fee is taken once the date of birth is known.
    if (draft.step == RegistrationStep.child && !draft.isPaidFor(today)) {
      unawaited(_requestPayment());
      return;
    }
    if (state.returnToReview) {
      _update(draft.copyWith(step: RegistrationStep.review), showErrors: false);
      emit(state.copyWith(returnToReview: false));
      return;
    }
    final nextIndex = draft.step.index + 1;
    if (nextIndex >= RegistrationStep.count) return;
    _update(
      draft.copyWith(step: RegistrationStep.values[nextIndex]),
      showErrors: false,
    );
  }

  void previous() {
    final draft = state.draft;
    if (draft == null || draft.step.index == 0) return;
    _update(
      draft.copyWith(step: RegistrationStep.values[draft.step.index - 1]),
      showErrors: false,
    );
  }

  /// Uses a payment already confirmed on this device, or asks the page to
  /// take one ([RegistrationFormState.askForPayment]).
  Future<void> _requestPayment() async {
    final stored = await _repository.payments.storedPayment();
    if (isClosed) return;
    if (stored case StoredPayment(isPaid: true, :final reference)) {
      _paid(reference);
    } else {
      emit(state.copyWith(askForPayment: true));
    }
  }

  /// The payment screen was closed, paid or not.
  Future<void> paymentClosed() async {
    emit(state.copyWith(askForPayment: false));
    final stored = await _repository.payments.storedPayment();
    if (isClosed) return;
    if (stored case StoredPayment(isPaid: true, :final reference)) {
      _paid(reference);
    }
  }

  /// Records the fee and carries on with what asked for it: Step 1's
  /// Next, or the submission.
  void _paid(String reference) {
    final draft = state.draft;
    if (draft == null) return;
    _update(draft.copyWith(paymentReference: reference));
    if (draft.step == RegistrationStep.child) {
      next();
    } else if (draft.step == RegistrationStep.review && state.declared) {
      unawaited(submit());
    }
  }

  /// Completes once every change is safely stored.
  Future<void> flush() => _saving;

  void _update(RegistrationDraft draft, {bool? showErrors}) {
    emit(state.copyWith(draft: draft, showErrors: showErrors));
    _saving = _saving.then((_) => _repository.saveDraft(draft));
    unawaited(_loadLgas(draft));
  }
}
