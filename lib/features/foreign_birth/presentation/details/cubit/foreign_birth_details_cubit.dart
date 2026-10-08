import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_record.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_reference_data.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/foreign_birth_repository.dart';

/// "Certificate Details" for one notification, with the names of its
/// places.
class ForeignBirthDetailsCubit extends Cubit<ForeignBirthDetailsState> {
  ForeignBirthDetailsCubit(this._repository, {required this.id})
    : super(const ForeignBirthDetailsState());

  final ForeignBirthRepository _repository;

  /// The backend's numeric id.
  final String id;

  Future<void> load() async {
    emit(const ForeignBirthDetailsState());
    final (record, reference) = await (
      _repository.details(id),
      _repository.referenceData(),
    ).wait;
    if (isClosed) return;
    switch ((record, reference)) {
      case (Ok(value: final record), Ok(value: final data)):
        emit(
          ForeignBirthDetailsState(
            isLoading: false,
            record: record,
            referenceData: data,
          ),
        );
        await _loadPlaces(record);
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(ForeignBirthDetailsState(isLoading: false, failure: failure));
    }
  }

  /// A place that can't be loaded shows as "-"; the rest still shows.
  Future<void> _loadPlaces(ForeignBirthRecord record) async {
    final draft = record.draft;
    final (states, lgas) = await (
      Future.wait([
        for (final id in draft.countryIds)
          _repository.states(id).then((result) => (id, result)),
      ]),
      Future.wait([
        for (final id in draft.nigerianStateIds)
          _repository.lgas(id).then((result) => (id, result)),
      ]),
    ).wait;
    if (isClosed) return;
    Map<String, List<Option>> loaded(
      List<(String, Result<List<Option>>)> results,
    ) => {
      for (final (id, result) in results)
        if (result case Ok(:final value)) id: value,
    };
    emit(state.copyWith(states: loaded(states), lgas: loaded(lgas)));
  }
}

final class ForeignBirthDetailsState extends Equatable {
  const ForeignBirthDetailsState({
    this.isLoading = true,
    this.record,
    this.referenceData,
    this.failure,
    this.states = const {},
    this.lgas = const {},
  });

  final bool isLoading;
  final ForeignBirthRecord? record;
  final ForeignBirthReferenceData? referenceData;
  final Failure? failure;

  /// States by country id, and LGAs by Nigerian state id.
  final Map<String, List<Option>> states;
  final Map<String, List<Option>> lgas;

  String? stateName(String? countryId, String? stateId) =>
      _label(states[countryId], stateId);

  String? lgaName(String? stateId, String? lgaId) =>
      _label(lgas[stateId], lgaId);

  static String? _label(List<Option>? options, String? id) {
    for (final option in options ?? const <Option>[]) {
      if (option.id == id) return option.label;
    }
    return null;
  }

  ForeignBirthDetailsState copyWith({
    Map<String, List<Option>>? states,
    Map<String, List<Option>>? lgas,
  }) => ForeignBirthDetailsState(
    isLoading: isLoading,
    record: record,
    referenceData: referenceData,
    failure: failure,
    states: states ?? this.states,
    lgas: lgas ?? this.lgas,
  );

  @override
  List<Object?> get props => [
    isLoading,
    record,
    referenceData,
    failure,
    states,
    lgas,
  ];
}
