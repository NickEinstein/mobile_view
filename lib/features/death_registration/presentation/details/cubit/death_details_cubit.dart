import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/death_registration_repository.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_draft.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_record.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_reference_data.dart';

/// "Certificate Details": one death registration, with the option
/// lists its answers are labelled from.
class DeathDetailsCubit extends Cubit<DeathDetailsState> {
  DeathDetailsCubit(this._repository, {required this.id})
    : super(const DeathDetailsState());

  final DeathRegistrationRepository _repository;
  final String id;

  Future<void> load() async {
    emit(const DeathDetailsState());
    final record = await _repository.details(id);
    final reference = switch (record) {
      Ok(value: final r) => await _repository.referenceData(
        withLgasOf: deathStates(deceased: r.deceased, informant: r.informant),
      ),
      Err(:final failure) => Err<DeathReferenceData>(failure),
    };
    if (isClosed) return;
    emit(switch ((record, reference)) {
      (Ok(value: final record), Ok(value: final data)) => DeathDetailsState(
        record: record,
        referenceData: data,
      ),
      (Err(:final failure), _) ||
      (_, Err(:final failure)) => DeathDetailsState(failure: failure),
    });
  }
}

final class DeathDetailsState extends Equatable {
  const DeathDetailsState({this.record, this.referenceData, this.failure});

  final DeathRecord? record;
  final DeathReferenceData? referenceData;
  final Failure? failure;

  bool get isLoading => record == null && failure == null;

  @override
  List<Object?> get props => [record, referenceData, failure];
}
