import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';

/// The attestation form's options. A state's LGAs load once it is chosen
/// ([withLgas]).
final class AttestationReferenceData extends Equatable {
  const AttestationReferenceData({
    required this.sexes,
    required this.maritalStatuses,
    required this.identityTypes,
    required this.states,
    required this.placesOfBirth,
    required this.educationLevels,
    required this.occupations,
    required this.requestReasons,
    required this.requirements,
    required this.countries,
    this.nationalities = const [],
  });

  /// Ids for the NIN record's sex.
  static const maleId = '1';
  static const femaleId = '2';

  final List<Option> sexes;
  final List<Option> maritalStatuses;

  /// "Mode of Identification".
  final List<Option> identityTypes;

  /// With their LGAs and registration centres.
  final List<StateOption> states;
  final List<Option> placesOfBirth;
  final List<Option> educationLevels;
  final List<Option> occupations;

  /// "Reason for Request".
  final List<Option> requestReasons;

  /// "As a Requirement for".
  final List<Option> requirements;

  final List<Option> countries;

  /// The same ids as [countries], labelled "Nigerian" and so on.
  final List<Option> nationalities;

  /// A parent's nationality; falls back to [countries] when not loaded.
  List<Option> get nationalityOptions =>
      nationalities.isEmpty ? countries : nationalities;

  /// A copy with each listed state's LGAs filled in.
  AttestationReferenceData withLgas(Map<String, List<LgaOption>> lgasByState) =>
      AttestationReferenceData(
        sexes: sexes,
        maritalStatuses: maritalStatuses,
        identityTypes: identityTypes,
        states: [
          for (final state in states)
            if (lgasByState[state.option.id] case final lgas?)
              StateOption(option: state.option, code: state.code, lgas: lgas)
            else
              state,
        ],
        placesOfBirth: placesOfBirth,
        educationLevels: educationLevels,
        occupations: occupations,
        requestReasons: requestReasons,
        requirements: requirements,
        countries: countries,
        nationalities: nationalities,
      );

  List<Option> get stateOptions => [for (final s in states) s.option];

  StateOption? _state(String? id) {
    for (final state in states) {
      if (state.option.id == id) return state;
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

  LgaOption? _lga(String? stateId, String? lgaId) {
    for (final lga in _state(stateId)?.lgas ?? const <LgaOption>[]) {
      if (lga.option.id == lgaId) return lga;
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
    final lga = _lga(stateId, lgaId);
    return lga == null ? null : lga.code ?? lga.option.id;
  }

  /// The id of the state called [name] (as the NIN service names it).
  String? stateIdNamed(String? name) => _idNamed(stateOptions, name);

  String? lgaIdNamed(String? stateId, String? name) =>
      _idNamed(lgasOf(stateId), name);

  static String? _idNamed(List<Option> options, String? name) {
    if (name == null) return null;
    final wanted = name.trim().toLowerCase();
    for (final option in options) {
      if (option.label.toLowerCase() == wanted) return option.id;
    }
    return null;
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
    maritalStatuses,
    identityTypes,
    states,
    placesOfBirth,
    educationLevels,
    occupations,
    requestReasons,
    requirements,
    countries,
    nationalities,
  ];
}
