import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/application_details.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';

enum DetailsStatus { loading, ready, failure }

final class ApplicationDetailsState extends Equatable {
  const ApplicationDetailsState({
    this.status = DetailsStatus.loading,
    this.details,
    this.referenceData,
    this.failure,
  });

  final DetailsStatus status;
  final ApplicationDetails? details;

  /// Turns the record's option ids into labels.
  final ReferenceData? referenceData;
  final Failure? failure;

  @override
  List<Object?> get props => [status, details, referenceData, failure];
}

/// Loads one submitted application for "Certificate Details".
class ApplicationDetailsCubit extends Cubit<ApplicationDetailsState> {
  ApplicationDetailsCubit(this._repository, {required this.id})
    : super(const ApplicationDetailsState());

  final BirthRegistrationRepository _repository;
  final String id;

  Future<void> load() async {
    if (state.status != DetailsStatus.ready) {
      emit(const ApplicationDetailsState());
    }
    final details = await _repository.details(id);
    final reference = switch (details) {
      Ok(value: final d) => await _repository.referenceData(
        withLgasOf: statesChosenIn(
          child: d.child,
          mother: d.mother,
          father: d.father,
          informant: d.informant,
        ),
      ),
      Err(:final failure) => Err<ReferenceData>(failure),
    };
    if (isClosed) return;
    switch ((details, reference)) {
      case (Ok(value: final details), Ok(value: final referenceData)):
        emit(
          ApplicationDetailsState(
            status: DetailsStatus.ready,
            details: details,
            referenceData: referenceData,
          ),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(
          ApplicationDetailsState(
            status: DetailsStatus.failure,
            details: state.details,
            referenceData: state.referenceData,
            failure: failure,
          ),
        );
    }
  }
}
