import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';

/// The surrogacy form's options. A state's LGAs load once it is chosen
/// ([withLgas]).
final class SurrogacyReferenceData extends Equatable {
  const SurrogacyReferenceData({
    required this.sexes,
    required this.birthOrders,
    required this.typesOfBirth,
    required this.placesOfBirth,
    required this.localityTypes,
    required this.arrangementTypes,
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
  final List<Option> birthOrders;
  final List<Option> typesOfBirth;
  final List<Option> placesOfBirth;

  /// Urban or rural.
  final List<Option> localityTypes;

  /// Gestational or traditional surrogacy.
  final List<Option> arrangementTypes;

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
  SurrogacyReferenceData withLgas(Map<String, List<LgaOption>> lgasByState) =>
      SurrogacyReferenceData(
        sexes: sexes,
        birthOrders: birthOrders,
        typesOfBirth: typesOfBirth,
        placesOfBirth: placesOfBirth,
        localityTypes: localityTypes,
        arrangementTypes: arrangementTypes,
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

  List<Option> lgasOf(String? stateId) => [
    for (final state in states)
      if (state.option.id == stateId)
        for (final lga in state.lgas) lga.option,
  ];

  /// The state and LGA of centre [centerId] (a saved application keeps only
  /// the centre); the state only once its LGAs are loaded.
  ({String state, String lga})? locationOfCenter(String? centerId) {
    for (final centre in centres) {
      if (centre.option.id != centerId) continue;
      for (final state in states) {
        for (final lga in state.lgas) {
          if (lga.option.id == centre.lga) {
            return (state: state.option.id, lga: centre.lga);
          }
        }
      }
      return (state: '', lga: centre.lga);
    }
    return null;
  }

  /// The centres in [lgaId], filtered by `LGA_ID`.
  List<Option> centersOf(String? stateId, String? lgaId) => [
    for (final centre in centres)
      if (centre.lga == lgaId) centre.option,
  ];

  @override
  List<Object?> get props => [
    sexes,
    birthOrders,
    typesOfBirth,
    placesOfBirth,
    localityTypes,
    arrangementTypes,
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
