import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';

/// The adoption form's options. A state's LGAs load once it is chosen
/// ([withLgas]).
final class AdoptionReferenceData extends Equatable {
  const AdoptionReferenceData({
    required this.sexes,
    required this.birthOrders,
    required this.placesOfBirth,
    required this.localityTypes,
    required this.states,
    required this.countries,
    required this.nationalities,
    required this.maritalStatuses,
    required this.occupations,
    required this.literacyLevels,
    required this.educationLevels,
    required this.relationships,
    this.centres = const [],
  });

  final List<Option> sexes;

  /// "Order of Child".
  final List<Option> birthOrders;
  final List<Option> placesOfBirth;

  /// Urban or rural.
  final List<Option> localityTypes;

  /// Nigeria's states, with their LGAs and registration centres.
  final List<StateOption> states;

  /// Nigeria is `63`.
  final List<Option> countries;
  final List<Option> nationalities;
  final List<Option> maritalStatuses;
  final List<Option> occupations;
  final List<Option> literacyLevels;
  final List<Option> educationLevels;

  /// The informant's relationship to the child.
  final List<Option> relationships;

  /// Every registration centre, with its LGA.
  final List<({Option option, String lga})> centres;

  /// A copy with each listed state's LGAs filled in.
  AdoptionReferenceData withLgas(Map<String, List<LgaOption>> lgasByState) =>
      AdoptionReferenceData(
        sexes: sexes,
        birthOrders: birthOrders,
        placesOfBirth: placesOfBirth,
        localityTypes: localityTypes,
        states: [
          for (final state in states)
            if (lgasByState[state.option.id] case final lgas?)
              StateOption(option: state.option, code: state.code, lgas: lgas)
            else
              state,
        ],
        countries: countries,
        nationalities: nationalities,
        maritalStatuses: maritalStatuses,
        occupations: occupations,
        literacyLevels: literacyLevels,
        educationLevels: educationLevels,
        relationships: relationships,
        centres: centres,
      );

  List<Option> get stateOptions => [for (final s in states) s.option];

  /// The state's name, which the backend also wants as text.
  String? stateName(String? stateId) {
    for (final state in states) {
      if (state.option.id == stateId) return state.option.label;
    }
    return null;
  }

  List<Option> lgasOf(String? stateId) => [
    for (final state in states)
      if (state.option.id == stateId)
        for (final lga in state.lgas) lga.option,
  ];

  /// The centres in [lgaId], filtered by `LGA_ID`.
  List<Option> centersOf(String? stateId, String? lgaId) => [
    for (final centre in centres)
      if (centre.lga == lgaId) centre.option,
  ];

  @override
  List<Object?> get props => [
    sexes,
    birthOrders,
    placesOfBirth,
    localityTypes,
    states,
    countries,
    nationalities,
    maritalStatuses,
    occupations,
    literacyLevels,
    educationLevels,
    relationships,
    centres,
  ];
}
