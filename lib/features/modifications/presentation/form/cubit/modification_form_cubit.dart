import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_documents.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_submission.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/queried_modification.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/record_edit.dart';
import 'package:vital_reg_mobile/features/modifications/domain/modifications_repository.dart';

part 'modification_form_state.dart';

/// The record's form with only the requested change editable.
class ModificationFormCubit extends Cubit<ModificationFormState> {
  ModificationFormCubit(
    this._repository, {
    required this.request,
    required ModificationRecord record,
    DateTime Function()? today,
  }) : queried = null,
       _today = today ?? DateTime.now,
       super(
         ModificationFormState(
           edit: RecordEdit.start(record, request.editableFields),
         ),
       );

  /// Correcting [queried]: starts from what it was sent with (documents
  /// too) and resends it under its own payment.
  ModificationFormCubit.queried(
    this._repository,
    QueriedModification this.queried, {
    DateTime Function()? today,
  }) : request = queried.request,
       _today = today ?? DateTime.now,
       super(
         ModificationFormState(
           edit: RecordEdit.start(
             queried.record,
             queried.request.editableFields,
           ),
           documents: ModificationDocuments(const {}, queried.documents),
         ),
       );

  final ModificationsRepository _repository;
  final ModificationRequest request;
  final QueriedModification? queried;
  final DateTime Function() _today;

  bool get isQueried => queried != null;

  DateTime get today => _today();

  /// The state fields this form shows.
  List<RecordField> get _stateFields => [
    for (final field in const [RecordField.birthState, RecordField.originState])
      if (switch (request.kind) {
            ModificationKind.birth => field == RecordField.birthState,
            ModificationKind.attestation => true,
            ModificationKind.death => false,
          } &&
          (!isQueried || state.edit.editable.contains(field)))
        field,
  ];

  /// The states, and the LGAs of each state chosen.
  Future<void> load() async {
    final stateFields = _stateFields;
    if (stateFields.isEmpty) return;
    emit(state.copyWith(optionsLoading: true));
    final states = await _repository.states();
    if (isClosed) return;
    switch (states) {
      case Ok(value: final options):
        emit(state.copyWith(states: options, optionsLoading: false));
        for (final field in stateFields) {
          await _loadLgas(state.edit[field]);
        }
      case Err(:final failure):
        emit(state.copyWith(optionsLoading: false, optionsFailure: failure));
    }
  }

  Future<void> _loadLgas(String? stateId) async {
    if (stateId == null || state.lgasByState.containsKey(stateId)) return;
    final result = await _repository.lgas(stateId);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final lgas):
        emit(
          state.copyWith(lgasByState: {...state.lgasByState, stateId: lgas}),
        );
      case Err(:final failure):
        emit(state.copyWith(optionsFailure: failure));
    }
  }

  Future<void> valueChanged(RecordField field, String? value) async {
    final before = state.edit[field];
    emit(state.copyWith(edit: state.edit.set(field, value)));
    final after = state.edit[field];
    if (field.lgaField != null && after != before) await _loadLgas(after);
  }

  void declaredChanged(bool declared) =>
      emit(state.copyWith(declared: declared));

  /// "Modify": a date of birth goes on to its documents; anything else is
  /// sent now.
  Future<void> modify() async {
    if (state.isSubmitting) return;
    final valid = state.edit.isValid(today: today, requireChange: !isQueried);
    if (!valid || !state.declared) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    if (request.changesDateOfBirth) {
      emit(
        state.copyWith(step: ModificationFormStep.documents, showErrors: false),
      );
    } else {
      await _submit();
    }
  }

  /// "Previous", from the documents.
  void backToForm() =>
      emit(state.copyWith(step: ModificationFormStep.form, showErrors: false));

  /// Keeps the picked file privately. Returns why it can't be used, if so.
  Future<DocumentError?> documentPicked(
    ModificationDocument type, {
    required String path,
    required String name,
    required int sizeBytes,
  }) async {
    final error = ModificationDocuments.check(
      AttachedFile(path: path, name: name, sizeBytes: sizeBytes),
    );
    if (error != null) {
      await _repository.deleteFile(path);
      return error;
    }
    final kept = await _repository.keepDocument(
      path,
      replacing: state.documents[type]?.path,
    );
    final file = AttachedFile(path: kept, name: name, sizeBytes: sizeBytes);
    if (isClosed) {
      await _repository.deleteFile(kept);
      return null;
    }
    emit(state.copyWith(documents: state.documents.withFile(type, file)));
    return null;
  }

  /// Removes a new photo, or one the queried request was sent with.
  Future<void> documentRemoved(ModificationDocument type) async {
    if (!state.documents.has(type)) return;
    final file = state.documents[type];
    emit(state.copyWith(documents: state.documents.withFile(type, null)));
    if (file != null) await _repository.deleteFile(file.path);
  }

  /// "Submit", on the documents.
  Future<void> submitDocuments() async {
    if (state.isSubmitting) return;
    if (!state.documents.isComplete) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    emit(state.copyWith(isSubmitting: true, showErrors: false));
    final queried = this.queried;
    final payments = queried == null ? _repository.payments(request) : null;
    final String reference;
    if (payments == null) {
      reference = queried!.paymentReference;
    } else {
      final payment = await payments.storedPayment();
      if (isClosed) return;
      if (payment == null || !payment.isPaid) {
        // Not expected: payment comes before this screen.
        emit(state.copyWith(isSubmitting: false, paymentMissing: true));
        return;
      }
      reference = payment.reference;
    }
    final result = await _repository.submit(
      ModificationSubmission(
        request: request,
        edit: state.edit,
        paymentReference: reference,
        documents: request.changesDateOfBirth
            ? state.documents
            : const ModificationDocuments(),
        modificationId: queried?.id,
      ),
    );
    if (isClosed) return;
    switch (result) {
      case Ok(value: final message):
        // The fee is spent; a new request pays again.
        await payments?.clearPayment();
        await _deleteDocuments();
        emit(
          state.copyWith(
            isSubmitting: false,
            submitted: true,
            message: message,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }

  Future<void> _deleteDocuments() async {
    for (final file in state.documents.files.values) {
      await _repository.deleteFile(file.path);
    }
  }

  /// Leaving without sending: the documents aren't kept (the payment is).
  @override
  Future<void> close() async {
    if (!state.submitted) await _deleteDocuments();
    return super.close();
  }
}
