import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';

/// "Mode of validation" and the applicant's NIN; "Face Match" starts the
/// request.
class NinValidationCubit extends Cubit<NinValidationState> {
  NinValidationCubit(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const NinValidationState());

  static final _ninPattern = RegExp(r'^\d{11}$');

  final ReissuanceRepository _repository;
  final DateTime Function() _now;

  /// A new mode clears the NIN.
  void modeChanged(ValidationMode? mode) {
    if (mode == null || mode == state.mode) return;
    emit(NinValidationState(mode: mode));
  }

  void ninChanged(String nin) => emit(state.copyWith(nin: nin.trim()));

  Future<void> validate() async {
    if (!state.canValidate) return;
    emit(state.copyWith(isChecking: true));
    final result = await _repository.verifyNin(state.nin);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(isChecking: false, record: () => value));
      case Err(failure: NotFoundFailure()):
        emit(state.copyWith(isChecking: false, notFound: true));
      case Err(:final failure):
        emit(state.copyWith(isChecking: false, failure: failure));
    }
  }

  /// "Cancel" on the NIN details.
  void detailsDismissed() => emit(state.copyWith(record: () => null));

  /// "Face Match" on the NIN details: a new request replaces any
  /// unfinished one (and its files). The payment is kept.
  Future<void> confirmed() async {
    final record = state.record;
    final mode = state.mode;
    if (record == null || mode == null || state.isDone) return;
    await _repository.discardDraft();
    await _repository.saveDraft(
      ReissuanceDraft(startedOn: _now(), mode: mode, ninRecord: record),
    );
    if (isClosed) return;
    emit(state.copyWith(isDone: true));
  }
}

final class NinValidationState extends Equatable {
  const NinValidationState({
    this.mode,
    this.nin = '',
    this.isChecking = false,
    this.record,
    this.isDone = false,
    this.notFound = false,
    this.failure,
  });

  /// Null until chosen; the NIN field is disabled until then.
  final ValidationMode? mode;
  final String nin;
  final bool isChecking;

  /// The verified NIN's details, shown for confirmation.
  final ApplicantNinRecord? record;

  /// The request is started; the page moves on to the face.
  final bool isDone;
  final bool notFound;
  final Failure? failure;

  bool get ninLooksValid => NinValidationCubit._ninPattern.hasMatch(nin);

  bool get canValidate => mode != null && ninLooksValid && !isChecking;

  /// [notFound] and [failure] are cleared unless passed, so editing
  /// dismisses the error. [record] is a function so it can be cleared.
  NinValidationState copyWith({
    String? nin,
    bool? isChecking,
    ApplicantNinRecord? Function()? record,
    bool? isDone,
    bool notFound = false,
    Failure? failure,
  }) => NinValidationState(
    mode: mode,
    nin: nin ?? this.nin,
    isChecking: isChecking ?? this.isChecking,
    record: record != null ? record() : this.record,
    isDone: isDone ?? this.isDone,
    notFound: notFound,
    failure: failure,
  );

  @override
  List<Object?> get props => [
    mode,
    nin,
    isChecking,
    record,
    isDone,
    notFound,
    failure,
  ];

  /// Keeps the NIN out of logs and test output.
  @override
  String toString() =>
      'NinValidationState(mode: ${mode?.name}, verified: ${record != null}, '
      'done: $isDone)';
}
