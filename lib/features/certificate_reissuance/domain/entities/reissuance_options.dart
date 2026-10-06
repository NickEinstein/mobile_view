import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';

/// A registration centre and the LGA it's in.
final class RegistrationCentre extends Equatable {
  const RegistrationCentre({required this.option, required this.lgaId});

  final Option option;
  final String lgaId;

  @override
  List<Object?> get props => [option, lgaId];
}

/// What the reissuance form's dropdowns offer, with the API's ids. States
/// and LGAs are loaded as they are needed, per country and per state.
final class ReissuanceOptions extends Equatable {
  const ReissuanceOptions({
    required this.typesOfBirth,
    required this.birthOrders,
    required this.sexes,
    required this.placesOfOccurrence,
    required this.localityTypes,
    required this.maritalStatuses,
    required this.ethnicGroups,
    required this.literacyLevels,
    required this.educationLevels,
    required this.occupations,
    required this.identityTypes,
    required this.requestReasons,
    required this.requirements,
    required this.countries,
    required this.nationalities,
    required this.centres,
  });

  final List<Option> typesOfBirth;
  final List<Option> birthOrders;
  final List<Option> sexes;
  final List<Option> placesOfOccurrence;

  /// Urban or rural.
  final List<Option> localityTypes;
  final List<Option> maritalStatuses;
  final List<Option> ethnicGroups;
  final List<Option> literacyLevels;
  final List<Option> educationLevels;
  final List<Option> occupations;

  /// Attestation only: "Mode of Identification", "Reason for Request" and
  /// "As a Requirement for" (text ids, e.g. `job abroad`).
  final List<Option> identityTypes;
  final List<Option> requestReasons;
  final List<Option> requirements;

  /// Of residence, by country code.
  final List<Option> countries;

  /// The same codes, named as nationalities ("Nigerian").
  final List<Option> nationalities;
  final List<RegistrationCentre> centres;

  List<Option> centresIn(String? lgaId) => [
    for (final centre in centres)
      if (centre.lgaId == lgaId) centre.option,
  ];

  @override
  List<Object?> get props => [
    typesOfBirth,
    birthOrders,
    sexes,
    placesOfOccurrence,
    localityTypes,
    maritalStatuses,
    ethnicGroups,
    literacyLevels,
    educationLevels,
    occupations,
    identityTypes,
    requestReasons,
    requirements,
    countries,
    nationalities,
    centres,
  ];
}
