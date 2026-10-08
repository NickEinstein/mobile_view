import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';

part 'nin_check_state.dart';

/// "Does the child have a NIN?" A NIN's record prefills the child. Starts
/// the draft once answered.
class NinCheckCubit extends Cubit<NinCheckState> {
  NinCheckCubit(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const NinCheckState());

  static final _ninPattern = RegExp(r'^\d{11}$');

  final BirthRegistrationRepository _repository;
  final DateTime Function() _now;

  void answered(bool hasNin) => emit(state.copyWith(hasNin: hasNin));

  void ninChanged(String nin) => emit(state.copyWith(nin: nin));

  Future<void> proceed() async {
    final hasNin = state.hasNin;
    if (hasNin == null || state.isSubmitting || !state.canProceed) return;
    emit(state.copyWith(isSubmitting: true));

    var child = const ChildParticulars();
    if (hasNin) {
      final result = await _repository.verifyNin(state.nin);
      if (isClosed) return;
      switch (result) {
        case Ok(value: final record):
          child = _prefill(record);
        case Err(:final failure):
          emit(state.copyWith(isSubmitting: false, failure: failure));
          return;
      }
    }

    await _repository.saveDraft(
      RegistrationDraft(
        startedOn: _now(),
        childHasNin: hasNin,
        childNin: hasNin ? state.nin : null,
        child: child,
      ),
    );
    if (isClosed) return;
    emit(state.copyWith(isSubmitting: false, isDone: true));
  }

  /// The sex ids: 1 male, 2 female.
  static ChildParticulars _prefill(ApplicantNinRecord record) =>
      const ChildParticulars()
          .set(ChildField.surname, record.surname)
          .set(ChildField.firstName, record.firstName)
          .set(ChildField.middleName, record.middleName)
          .set(ChildField.dateOfBirth, record.dateOfBirth.toIso8601String())
          .set(ChildField.sex, switch (record.sex) {
            Sex.male => '1',
            Sex.female => '2',
            null => null,
          });
}
