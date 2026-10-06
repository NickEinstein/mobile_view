import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_options.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';

/// "Certificate Details": one reissuance request of [kind] as it was sent,
/// with the names of the places it uses.
class ReissuanceDetailsCubit extends Cubit<ReissuanceDetailsState> {
  ReissuanceDetailsCubit(
    this._repository, {
    required this.kind,
    required this.id,
  }) : super(const ReissuanceDetailsState());

  final ReissuanceRepository _repository;
  final ReissuanceKind kind;
  final String id;

  Future<void> load() async {
    emit(const ReissuanceDetailsState());
    final options = await _repository.options();
    if (isClosed) return;
    if (options case Err(:final failure)) {
      emit(ReissuanceDetailsState(isLoading: false, failure: failure));
      return;
    }
    final loaded = (options as Ok<ReissuanceOptions>).value;
    switch (kind) {
      case ReissuanceKind.birth:
        final record = await _repository.birthRecord(id);
        if (isClosed) return;
        switch (record) {
          case Ok(value: final record):
            final (:countries, :states) = record.form.places;
            await _finish(loaded, countries, states, birth: record);
          case Err(:final failure):
            emit(ReissuanceDetailsState(isLoading: false, failure: failure));
        }
      case ReissuanceKind.attestation:
        final record = await _repository.attestationRecord(id);
        if (isClosed) return;
        switch (record) {
          case Ok(value: final record):
            await _finish(
              loaded,
              const {ReissuanceCodes.nigeria},
              record.form.states,
              attestation: record,
            );
          case Err(:final failure):
            emit(ReissuanceDetailsState(isLoading: false, failure: failure));
        }
    }
  }

  Future<void> _finish(
    ReissuanceOptions options,
    Set<String> countries,
    Set<String> states, {
    BirthReissuanceRecord? birth,
    AttestationReissuanceRecord? attestation,
  }) async {
    final (stateLists, lgaLists) = await (
      Future.wait(countries.map(_repository.states)),
      Future.wait(states.map(_repository.lgas)),
    ).wait;
    if (isClosed) return;
    // A list that didn't load only leaves its names out.
    Map<String, List<Option>> loaded(
      Iterable<String> ids,
      List<Result<List<Option>>> results,
    ) => {
      for (final (i, id) in ids.indexed)
        if (results[i] case Ok(:final value)) id: value,
    };
    emit(
      ReissuanceDetailsState(
        isLoading: false,
        birth: birth,
        attestation: attestation,
        options: options,
        statesByCountry: loaded(countries, stateLists),
        lgasByState: loaded(states, lgaLists),
      ),
    );
  }
}

final class ReissuanceDetailsState extends Equatable {
  const ReissuanceDetailsState({
    this.isLoading = true,
    this.birth,
    this.attestation,
    this.options,
    this.statesByCountry = const {},
    this.lgasByState = const {},
    this.failure,
  });

  final bool isLoading;

  /// One of these, by kind.
  final BirthReissuanceRecord? birth;
  final AttestationReissuanceRecord? attestation;
  final ReissuanceOptions? options;
  final Map<String, List<Option>> statesByCountry;
  final Map<String, List<Option>> lgasByState;
  final Failure? failure;

  ReissuanceRecord<Object>? get record => birth ?? attestation;

  List<Option> statesOf(String? countryCode) =>
      statesByCountry[countryCode] ?? const [];

  List<Option> lgasOf(String? stateId) => lgasByState[stateId] ?? const [];

  @override
  List<Object?> get props => [
    isLoading,
    birth,
    attestation,
    options,
    statesByCountry,
    lgasByState,
    failure,
  ];
}
