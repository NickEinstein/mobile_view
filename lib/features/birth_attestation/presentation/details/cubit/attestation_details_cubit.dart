import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_reference_data.dart';

/// "Certificate Details": one submitted attestation, with the option lists
/// its answers are labelled from.
class AttestationDetailsCubit extends Cubit<AttestationDetailsState> {
  AttestationDetailsCubit(this._repository, {required this.id})
    : super(const AttestationDetailsState());

  final BirthAttestationRepository _repository;
  final String id;

  Future<void> load() async {
    emit(const AttestationDetailsState());
    final record = await _repository.details(id);
    final reference = switch (record) {
      Ok(value: final r) => await _repository.referenceData(
        withLgasOf: attestationStates(
          applicant: r.applicant,
          additional: r.additional,
          mother: r.mother,
          father: r.father,
        ),
      ),
      Err(:final failure) => Err<AttestationReferenceData>(failure),
    };
    if (isClosed) return;
    emit(switch ((record, reference)) {
      (Ok(value: final record), Ok(value: final data)) =>
        AttestationDetailsState(record: record, referenceData: data),
      (Err(:final failure), _) ||
      (_, Err(:final failure)) => AttestationDetailsState(failure: failure),
    });
  }
}

final class AttestationDetailsState extends Equatable {
  const AttestationDetailsState({
    this.record,
    this.referenceData,
    this.failure,
  });

  final AttestationRecord? record;
  final AttestationReferenceData? referenceData;
  final Failure? failure;

  bool get isLoading => record == null && failure == null;

  @override
  List<Object?> get props => [record, referenceData, failure];
}
