import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';

/// The still birth form's options. A state's LGAs load once it is chosen
/// ([withLgas]).
final class StillBirthReferenceData extends Equatable {
  const StillBirthReferenceData({
    required this.placesOfOccurrence,
    required this.sexes,
    required this.typesOfDelivery,
    required this.countries,
    required this.nationalities,
    required this.states,
    required this.settlements,
    required this.ethnicGroups,
    required this.relationships,
  });

  final List<Option> placesOfOccurrence;
  final List<Option> sexes;
  final List<Option> typesOfDelivery;

  /// Of residence.
  final List<Option> countries;
  final List<Option> nationalities;

  /// Nigeria's states, with their LGAs.
  final List<StateOption> states;

  /// Urban or rural.
  final List<Option> settlements;
  final List<Option> ethnicGroups;

  /// The informant's relationship with the deceased.
  final List<Option> relationships;

  /// A copy with each listed state's LGAs filled in.
  StillBirthReferenceData withLgas(Map<String, List<LgaOption>> lgasByState) =>
      StillBirthReferenceData(
        placesOfOccurrence: placesOfOccurrence,
        sexes: sexes,
        typesOfDelivery: typesOfDelivery,
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
        ethnicGroups: ethnicGroups,
        relationships: relationships,
      );

  List<Option> get stateOptions => [for (final s in states) s.option];

  List<Option> lgasOf(String? stateId) {
    for (final state in states) {
      if (state.option.id == stateId) {
        return [for (final lga in state.lgas) lga.option];
      }
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
    placesOfOccurrence,
    sexes,
    typesOfDelivery,
    countries,
    nationalities,
    states,
    settlements,
    ethnicGroups,
    relationships,
  ];
}
