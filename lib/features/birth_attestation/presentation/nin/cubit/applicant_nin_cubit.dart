import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';

part 'applicant_nin_state.dart';

/// "Does the applicant have a NIN?" A NIN must belong to an adult and
/// prefills the form. Starts the draft once answered.
class ApplicantNinCubit extends Cubit<ApplicantNinState> {
  ApplicantNinCubit(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const ApplicantNinState());

  static final _ninPattern = RegExp(r'^\d{11}$');

  final BirthAttestationRepository _repository;
  final DateTime Function() _now;

  void answered(bool hasNin) => emit(state.copyWith(hasNin: hasNin));

  void ninChanged(String nin) => emit(state.copyWith(nin: nin));

  Future<void> proceed() async {
    final hasNin = state.hasNin;
    if (hasNin == null || state.isSubmitting || !state.canProceed) return;
    emit(state.copyWith(isSubmitting: true));

    ApplicantNinRecord? record;
    if (hasNin) {
      final result = await _repository.verifyNin(state.nin);
      if (isClosed) return;
      switch (result) {
        case Ok(:final value) when value.isAdultOn(_now()):
          record = value;
        case Ok():
          emit(state.copyWith(isSubmitting: false, isUnderAge: true));
          return;
        case Err(:final failure):
          emit(state.copyWith(isSubmitting: false, failure: failure));
          return;
      }
    }

    // A new application replaces any unfinished one (and its photo).
    await _repository.discardDraft();
    await _repository.saveDraft(
      AttestationDraft(startedOn: _now(), hasNin: hasNin, ninRecord: record),
    );
    if (isClosed) return;
    emit(state.copyWith(isSubmitting: false, isDone: true));
  }
}
