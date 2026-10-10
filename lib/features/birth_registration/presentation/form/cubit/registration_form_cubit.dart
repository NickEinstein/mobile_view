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

/// The six-step form, saved on every change. With [queriedRecordId] it
/// corrects that record instead, and with [outboxId] an application saved
/// offline (both in memory only).
class RegistrationFormCubit extends Cubit<RegistrationFormState> {
  RegistrationFormCubit(
    this._repository, {
    this.registrarLocation,
    this.queriedRecordId,
    this.outboxId,
    this.offline = false,
    DateTime Function()? now,
    String Function()? newSubmissionKey,
  }) : _now = now ?? DateTime.now,
       _newSubmissionKey = newSubmissionKey ?? _randomKey,
       super(const RegistrationFormState());

  final BirthRegistrationRepository _repository;

  /// When known, the registration state and LGA are fixed to it.
  final RegistrarLocation? registrarLocation;

  /// `Birth_Reg_ID` of the queried record being corrected.
  final String? queriedRecordId;

  /// The outbox entry being edited.
  final String? outboxId;

  /// Offline mode: applications go to the outbox, and as the fee can't be
  /// paid, a child of 5 or older can't be registered.
  final bool offline;

  /// Saved on the device rather than sent: offline, or editing the outbox.
  bool get savesOnDevice => offline || outboxId != null;

  /// The outbox entry's files, deleted only once the edit is saved.
  Set<String> _entryFiles = const {};
  bool _editSaved = false;
  final DateTime Function() _now;
  final String Function() _newSubmissionKey;

  /// The upload in flight. Leaving the screen cancels it; the draft keeps
  /// its submission key, so sending it again later is safe.
  Cancellation? _submission;

  @override
  Future<void> close() async {
    _submission?.cancel();
    // An unsaved edit leaves the entry as it was: drop the new files.
    if (outboxId != null && !_editSaved) {
      for (final path in state.draft?.files ?? const <String>[]) {
        if (!_entryFiles.contains(path)) await _repository.deleteFile(path);
      }
    }
    return super.close();
  }

  /// [path], unless the outbox entry still uses it.
  String? _ownFile(String? path) => _entryFiles.contains(path) ? null : path;

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
    if (outboxId case final id?) return _loadFromOutbox(id);
    final saved = await _repository.loadDraft();
    final draft = _located(saved ?? RegistrationDraft(startedOn: _now()));
    if (saved != null && draft != saved) await _repository.saveDraft(draft);
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

  Future<void> _loadFromOutbox(String id) async {
    final entries = await _repository.outbox();
    final entry = entries.where((e) => e.id == id).firstOrNull;
    if (isClosed) return;
    if (entry == null) {
      emit(
        state.copyWith(
          status: FormStatus.failure,
          failure: const NotFoundFailure(),
        ),
      );
      return;
    }
    _entryFiles = entry.item.files.toSet();
    final draft = _located(entry.item.copyWith(step: RegistrationStep.review));
    final reference = await _repository.referenceData();
    if (isClosed) return;
    switch (reference) {
      case Ok(value: final referenceData):
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

  RegistrationDraft _located(RegistrationDraft draft) {
    final location = registrarLocation;
    return location == null
        ? draft
        : draft.copyWith(child: draft.child.locatedAt(location));
  }

  Future<void> _loadQueried(String id) async {
    final details = await _repository.details(id);
    if (isClosed) return;
    final RegistrationDraft draft;
    switch (details) {
      case Ok(value: final record):
        draft = _located(record.toQueriedDraft(_now()));
      case Err(:final failure):
        emit(state.copyWith(status: FormStatus.failure, failure: failure));
        return;
    }
    final reference = await _repository.referenceData();
    if (isClosed) return;
    switch (reference) {
      case Ok(value: final referenceData):
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
      replacing: _ownFile(draft.child[ChildField.facePhoto]),
    );
    if (isClosed) return;
    childChanged(ChildField.facePhoto, path);
  }

  void parentChanged(ParentRole role, ParentField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    _update(_withParent(draft, role, draft.parentOf(role).set(field, value)));
  }

  /// [draft] with [parent] as [role]. A parent informant follows: what the
  /// informant step shows of them stays that parent's.
  RegistrationDraft _withParent(
    RegistrationDraft draft,
    ParentRole role,
    ParentParticulars parent,
  ) {
    final updated = switch (role) {
      ParentRole.mother => draft.copyWith(mother: parent),
      ParentRole.father => draft.copyWith(father: parent),
    };
    return updated.informant.parentRole == role
        ? updated.copyWith(
            informant: updated.informant.copiedFrom(parent, role),
          )
        : updated;
  }

  /// Father or Mother fills the informant from that parent; their phone
  /// and NIN edit the parent's.
  void informantChanged(InformantField field, String? value) {
    final draft = state.draft;
    if (draft == null) return;
    final before = draft.informant;
    if (field == InformantField.relationship) {
      final chosen = before.set(field, value);
      final role = chosen.parentRole;
      _update(
        draft.copyWith(
          informant: role != null
              ? chosen.copiedFrom(draft.parentOf(role), role)
              : before.parentRole != null
              // No longer a parent: start the person's details afresh.
              ? chosen.withoutParent()
              : chosen,
        ),
      );
      return;
    }
    final role = before.parentRole;
    final parentField = switch (field) {
      InformantField.phone => ParentField.phone,
      InformantField.nin => ParentField.nin,
      _ => null,
    };
    if (role != null && parentField != null) {
      _update(
        _withParent(draft, role, draft.parentOf(role).set(parentField, value)),
      );
      return;
    }
    _update(draft.copyWith(informant: before.set(field, value)));
  }

  Future<void> informantPhotoCaptured(String capturedPath) async {
    final draft = state.draft;
    if (draft == null) return;
    final path = await _repository.keepPhoto(
      capturedPath,
      replacing: _ownFile(draft.informant[InformantField.facePhoto]),
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
      replacing: _ownFile(draft.informant[InformantField.signature]),
    );
    if (isClosed) return;
    informantChanged(InformantField.signature, path);
  }

  Future<void> signatureCleared() async {
    final path = state.draft?.informant[InformantField.signature];
    if (path == null) return;
    informantChanged(InformantField.signature, null);
    if (_ownFile(path) case final own?) await _repository.deleteFile(own);
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
      replacing: _ownFile(draft.documents[type]?.path),
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
    if (_ownFile(file.path) case final own?) await _repository.deleteFile(own);
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
      if (savesOnDevice) return emit(state.copyWith(showErrors: true));
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
    if (keyed.queried case final queried?) {
      return _sendCorrection(keyed, queried.certificateNumber);
    }
    if (outboxId case final id?) return _saveEdit(id, keyed);
    if (offline) return _saveForLater(keyed);
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

  Future<void> _saveForLater(RegistrationDraft draft) async {
    await _repository.saveForLater(draft);
    if (isClosed) return;
    emit(state.copyWith(submitStatus: SubmitStatus.savedForLater));
  }

  Future<void> _saveEdit(String id, RegistrationDraft draft) async {
    await _repository.replaceInOutbox(id, draft);
    _editSaved = true;
    if (isClosed) return;
    emit(state.copyWith(submitStatus: SubmitStatus.savedForLater));
  }

  /// Updates the queried record. Unlike a new application, no draft on
  /// the device is involved, so none is discarded.
  Future<void> _sendCorrection(
    RegistrationDraft draft,
    String certificateNumber,
  ) async {
    final result = await _repository.updateQueried(
      draft,
      cancellation: _submission = Cancellation(),
      onProgress: (sent, total) {
        if (!isClosed && total > 0) {
          emit(state.copyWith(progress: () => sent / total));
        }
      },
    );
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
      if (savesOnDevice) return emit(state.copyWith(showErrors: true));
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
    unawaited(_loadLgas(draft));
    // A correction lives only in memory, as does an outbox edit until
    // it is saved.
    if (draft.queried != null || outboxId != null) return;
    _saving = _saving.then((_) => _repository.saveDraft(draft));
  }
}
