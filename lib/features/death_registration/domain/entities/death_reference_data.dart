import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';

/// The death form's options. A state's LGAs load once it is chosen
/// ([withLgas]).
final class DeathReferenceData extends Equatable {
  const DeathReferenceData({
    required this.sexes,
    required this.countries,
    required this.nationalities,
    required this.states,
    required this.settlements,
    required this.occupations,
    required this.placesOfDeath,
    required this.ethnicGroups,
    required this.maritalStatuses,
    required this.literacy,
    required this.educationLevels,
    required this.yesNo,
    required this.causesOfDeath,
    required this.relationships,
  });

  final List<Option> sexes;

  /// Of residence.
  final List<Option> countries;
  final List<Option> nationalities;

  /// Nigeria's states, with their LGAs and registration centres.
  final List<StateOption> states;

  /// Urban or rural.
  final List<Option> settlements;
  final List<Option> occupations;
  final List<Option> placesOfDeath;
  final List<Option> ethnicGroups;
  final List<Option> maritalStatuses;
  final List<Option> literacy;
  final List<Option> educationLevels;

  /// "Is death certified by a Doctor?"
  final List<Option> yesNo;
  final List<Option> causesOfDeath;

  /// The informant's relationship with the deceased.
  final List<Option> relationships;

  /// A copy with each listed state's LGAs filled in.
  DeathReferenceData withLgas(Map<String, List<LgaOption>> lgasByState) =>
      DeathReferenceData(
        sexes: sexes,
        countries: countries,
        nationalities: nationalities,
        states: [
          for (final state in states)
            if (lgasByState[state.option.id] case final lgas?)
              StateOption(option: state.option, code: state.code, lgas: lgas)
            else
              state,
        ],
        settlements: settlements,
        occupations: occupations,
        placesOfDeath: placesOfDeath,
        ethnicGroups: ethnicGroups,
        maritalStatuses: maritalStatuses,
        literacy: literacy,
        educationLevels: educationLevels,
        yesNo: yesNo,
        causesOfDeath: causesOfDeath,
        relationships: relationships,
      );

  List<Option> get stateOptions => [for (final s in states) s.option];

  StateOption? _state(String? id) {
    for (final state in states) {
      if (state.option.id == id) return state;
    }
    return null;
  }

  /// The state's `State_Code`, falling back to its id.
  String? stateCode(String? stateId) {
    final state = _state(stateId);
    return state == null ? null : state.code ?? state.option.id;
  }

  /// The LGA's `LGA_Code`, falling back to its id.
  String? lgaCode(String? stateId, String? lgaId) {
    for (final lga in _state(stateId)?.lgas ?? const <LgaOption>[]) {
      if (lga.option.id == lgaId) return lga.code ?? lga.option.id;
    }
    return null;
  }

  List<Option> lgasOf(String? stateId) => [
    for (final lga in _state(stateId)?.lgas ?? const <LgaOption>[]) lga.option,
  ];

  List<Option> centersOf(String? stateId, String? lgaId) {
    for (final lga in _state(stateId)?.lgas ?? const <LgaOption>[]) {
      if (lga.option.id == lgaId) return lga.registrationCenters;
    }
    return const [];
  }

  /// The label for [id] in [options], or null.
  static String? labelOf(List<Option> options, String? id) {
    for (final option in options) {
      if (option.id == id) return option.label;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    sexes,
    countries,
    nationalities,
    states,
    settlements,
    occupations,
    placesOfDeath,
    ethnicGroups,
    maritalStatuses,
    literacy,
    educationLevels,
    yesNo,
    causesOfDeath,
    relationships,
  ];
}
