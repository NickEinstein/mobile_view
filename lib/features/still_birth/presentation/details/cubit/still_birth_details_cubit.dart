import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_draft.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_record.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_reference_data.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/still_birth_repository.dart';

/// "Certificate Details": one registered still birth, with the option
/// lists its answers are labelled from.
class StillBirthDetailsCubit extends Cubit<StillBirthDetailsState> {
  StillBirthDetailsCubit(this._repository, {required this.id})
    : super(const StillBirthDetailsState());

  final StillBirthRepository _repository;
  final String id;

  Future<void> load() async {
    emit(const StillBirthDetailsState());
    final record = await _repository.details(id);
    final reference = switch (record) {
      Ok(value: final r) => await _repository.referenceData(
        withLgasOf: stillBirthStates(mother: r.mother, informant: r.informant),
      ),
      Err(:final failure) => Err<StillBirthReferenceData>(failure),
    };
    if (isClosed) return;
    emit(switch ((record, reference)) {
      (Ok(value: final record), Ok(value: final data)) =>
        StillBirthDetailsState(record: record, referenceData: data),
      (Err(:final failure), _) ||
      (_, Err(:final failure)) => StillBirthDetailsState(failure: failure),
    });
  }
}

final class StillBirthDetailsState extends Equatable {
  const StillBirthDetailsState({this.record, this.referenceData, this.failure});

  final StillBirthRecord? record;
  final StillBirthReferenceData? referenceData;
  final Failure? failure;

  bool get isLoading => record == null && failure == null;

  @override
  List<Object?> get props => [record, referenceData, failure];
}
