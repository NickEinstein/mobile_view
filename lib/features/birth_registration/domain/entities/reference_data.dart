import 'package:equatable/equatable.dart';

/// One choice in a dropdown. [id] is what the API stores; [label] is shown.
final class Option extends Equatable {
  const Option(this.id, this.label);

  final String id;
  final String label;

  @override
  List<Object?> get props => [id, label];
}

/// A state with its local government areas.
final class StateOption extends Equatable {
  const StateOption({required this.option, required this.lgas, this.code});

  final Option option;
  final List<LgaOption> lgas;

  /// The API's `State_Code`, e.g. "LA"; it starts certificate numbers.
  final String? code;

  @override
  List<Object?> get props => [option, lgas, code];
}

/// An LGA with its towns and registration centres.
final class LgaOption extends Equatable {
  const LgaOption({
    required this.option,
    required this.registrationCenters,
    this.towns = const [],
    this.code,
  });

  final Option option;
  final List<Option> towns;
  final List<Option> registrationCenters;

  /// The API's `LGA_Code`; it follows the state code in certificate
  /// numbers.
  final String? code;

  @override
  List<Object?> get props => [option, towns, registrationCenters, code];
}

/// The registration form's options. A state's LGAs load once it is chosen
/// ([withLgas]).
final class ReferenceData extends Equatable {
  const ReferenceData({
    required this.typesOfBirth,
    required this.birthOrders,
    required this.sexes,
    required this.placesOfOccurrence,
    required this.localityTypes,
    required this.states,
    this.countries = const [],
    this.nationalities = const [],
    this.maritalStatuses = const [],
    this.ethnicGroups = const [],
    this.literacyLevels = const [],
    this.educationLevels = const [],
    this.occupations = const [],
    this.relationships = const [],
  });

  /// Country id whose [states] the form offers (`Country_Code` 63).
  static const nigeria = '63';

  /// The literacy level after which education is asked ("Literate").
  static const literate = '1';

  final List<Option> typesOfBirth;
  final List<Option> birthOrders;
  final List<Option> sexes;
  final List<Option> placesOfOccurrence;
  final List<Option> localityTypes;
  final List<StateOption> states;

  final List<Option> countries;

  /// The same ids as [countries], labelled "Nigerian" and so on. Falls back
  /// to [countries] when not loaded.
  final List<Option> nationalities;
  final List<Option> maritalStatuses;
  final List<Option> ethnicGroups;
  final List<Option> literacyLevels;
  final List<Option> educationLevels;
  final List<Option> occupations;

  /// The informant's relationship with the child.
  final List<Option> relationships;

  /// A copy with each listed state's LGAs filled in.
  ReferenceData withLgas(Map<String, List<LgaOption>> lgasByState) =>
      ReferenceData(
        typesOfBirth: typesOfBirth,
        birthOrders: birthOrders,
        sexes: sexes,
        placesOfOccurrence: placesOfOccurrence,
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
        ethnicGroups: ethnicGroups,
        literacyLevels: literacyLevels,
        educationLevels: educationLevels,
        occupations: occupations,
        relationships: relationships,
      );

  List<Option> get nationalityOptions =>
      nationalities.isEmpty ? countries : nationalities;

  List<Option> get stateOptions => [for (final s in states) s.option];

  StateOption? _state(String? id) {
    for (final state in states) {
      if (state.option.id == id) return state;
    }
    return null;
  }

  LgaOption? _lga(String? stateId, String? lgaId) {
    for (final lga in _state(stateId)?.lgas ?? const <LgaOption>[]) {
      if (lga.option.id == lgaId) return lga;
    }
    return null;
  }

  List<Option> lgasOf(String? stateId) => [
    for (final lga in _state(stateId)?.lgas ?? const <LgaOption>[]) lga.option,
  ];

  List<Option> townsOf(String? stateId, String? lgaId) =>
      _lga(stateId, lgaId)?.towns ?? const [];

  /// The state's `State_Code`, falling back to its id.
  String? stateCode(String? stateId) {
    final state = _state(stateId);
    return state == null ? null : state.code ?? state.option.id;
  }

  /// The LGA's `LGA_Code`, falling back to its id.
  String? lgaCode(String? stateId, String? lgaId) {
    final lga = _lga(stateId, lgaId);
    return lga == null ? null : lga.code ?? lga.option.id;
  }

  List<Option> centersOf(String? stateId, String? lgaId) =>
      _lga(stateId, lgaId)?.registrationCenters ?? const [];

  @override
  List<Object?> get props => [
    typesOfBirth,
    birthOrders,
    sexes,
    placesOfOccurrence,
    localityTypes,
    states,
    countries,
    nationalities,
    maritalStatuses,
    ethnicGroups,
    literacyLevels,
    educationLevels,
    occupations,
    relationships,
  ];
}
