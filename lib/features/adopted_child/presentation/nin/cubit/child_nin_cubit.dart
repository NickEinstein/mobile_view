import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/adopted_child_repository.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_draft.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_form.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';

part 'child_nin_state.dart';

/// "Child's National Identity Number": creates the application, then
/// records the verified NIN (or a skip) against it.
class ChildNinCubit extends Cubit<ChildNinState> {
  ChildNinCubit(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const ChildNinState());

  static final _ninPattern = RegExp(r'^\d{11}$');

  final AdoptedChildRepository _repository;
  final DateTime Function() _now;

  /// Continues the registration on the device, or creates a new one.
  Future<void> load() async {
    emit(state.copyWith(step: ChildNinStep.starting));
    final draft = await _repository.loadDraft();
    if (isClosed) return;
    if (draft != null) {
      emit(
        state.copyWith(
          step: ChildNinStep.ready,
          referenceId: draft.referenceId,
        ),
      );
      return;
    }
    final result = await _repository.initiate();
    if (isClosed) return;
    switch (result) {
      case Ok(value: final referenceId):
        await _repository.saveDraft(
          AdoptionDraft(referenceId: referenceId, startedOn: _now()),
        );
        if (isClosed) return;
        emit(
          state.copyWith(
            step: ChildNinStep.ready,
            referenceId: referenceId,
            justCreated: true,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(step: ChildNinStep.startFailed, failure: failure));
    }
  }

  void ninChanged(String nin) => emit(state.copyWith(nin: nin.trim()));

  /// "Validate": the identity service must know the NIN; it then fills
  /// the child's surname, first name and sex, which stay locked.
  Future<void> validate() async {
    final referenceId = state.referenceId;
    if (!state.canValidate || referenceId == null) return;
    emit(state.copyWith(step: ChildNinStep.validating));
    final lookup = await _repository.lookupNin(state.nin);
    if (isClosed) return;
    final ApplicantNinRecord record;
    switch (lookup) {
      case Ok(:final value):
        record = value;
      case Err(:final failure):
        emit(state.copyWith(step: ChildNinStep.ready, failure: failure));
        return;
    }
    final saved = await _repository.verifyChildNin(
      referenceId: referenceId,
      nin: state.nin,
    );
    if (isClosed) return;
    if (saved case Err(:final failure)) {
      emit(state.copyWith(step: ChildNinStep.ready, failure: failure));
      return;
    }
    await _decide(ChildNinDecision.verified, record: record);
  }

  /// "Proceed" in the skip warning.
  Future<void> skip() async {
    final referenceId = state.referenceId;
    if (state.step != ChildNinStep.ready || referenceId == null) return;
    emit(state.copyWith(step: ChildNinStep.skipping));
    final result = await _repository.skipChildNin(referenceId);
    if (isClosed) return;
    switch (result) {
      case Ok():
        await _decide(ChildNinDecision.skipped);
      case Err(:final failure):
        emit(state.copyWith(step: ChildNinStep.ready, failure: failure));
    }
  }

  Future<void> _decide(
    ChildNinDecision decision, {
    ApplicantNinRecord? record,
  }) async {
    final draft = await _repository.loadDraft();
    if (isClosed) return;
    if (draft != null) {
      var child = draft.child;
      if (record != null) {
        child = child
            .set(ChildField.surname, record.surname)
            .set(ChildField.firstName, record.firstName)
            .set(ChildField.sex, switch (record.sex) {
              Sex.male => AdoptionCodes.male,
              Sex.female => AdoptionCodes.female,
              null => child[ChildField.sex],
            });
      }
      await _repository.saveDraft(
        draft.copyWith(
          ninDecision: decision,
          childNin: () => record?.nin,
          child: child,
        ),
      );
      if (isClosed) return;
    }
    emit(state.copyWith(step: ChildNinStep.done, decision: decision));
  }
}
