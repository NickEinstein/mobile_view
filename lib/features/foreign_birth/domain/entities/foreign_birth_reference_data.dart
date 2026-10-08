import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';

const _nigeria = '63';

/// A country, with the ISO alpha-2 code the backend builds the
/// notification number from (`birth_country_code`).
final class ForeignBirthCountry extends Equatable {
  const ForeignBirthCountry({
    required this.option,
    required this.nationality,
    this.isoCode,
  });

  final Option option;

  /// The same id, labelled as a nationality ("Ghanaian").
  final Option nationality;
  final String? isoCode;

  @override
  List<Object?> get props => [option, nationality, isoCode];
}

/// The foreign birth form's options; states and LGAs load as needed.
final class ForeignBirthReferenceData extends Equatable {
  const ForeignBirthReferenceData({
    required this.sexes,
    required this.typesOfBirth,
    required this.birthOrders,
    required this.placesOfOccurrence,
    required this.maritalStatuses,
    required this.occupations,
    required this.literacyLevels,
    required this.educationLevels,
    required this.ethnicGroups,
    required this.relationships,
    required this.countries,
  });

  final List<Option> sexes;
  final List<Option> typesOfBirth;

  /// "Order of Child".
  final List<Option> birthOrders;
  final List<Option> placesOfOccurrence;
  final List<Option> maritalStatuses;
  final List<Option> occupations;
  final List<Option> literacyLevels;
  final List<Option> educationLevels;
  final List<Option> ethnicGroups;

  /// The informant's relationship to the child.
  final List<Option> relationships;

  /// Nigeria is `63`.
  final List<ForeignBirthCountry> countries;

  List<Option> get countryOptions => [for (final c in countries) c.option];

  List<Option> get nationalities => [for (final c in countries) c.nationality];

  /// Where a foreign birth can be: anywhere but Nigeria.
  List<Option> get birthCountries => [
    for (final c in countries)
      if (c.option.id != _nigeria) c.option,
  ];

  ForeignBirthReferenceData withCountries(List<ForeignBirthCountry> list) =>
      ForeignBirthReferenceData(
        sexes: sexes,
        typesOfBirth: typesOfBirth,
        birthOrders: birthOrders,
        placesOfOccurrence: placesOfOccurrence,
        maritalStatuses: maritalStatuses,
        occupations: occupations,
        literacyLevels: literacyLevels,
        educationLevels: educationLevels,
        ethnicGroups: ethnicGroups,
        relationships: relationships,
        countries: list,
      );

  String? isoCodeOf(String? countryId) {
    for (final country in countries) {
      if (country.option.id == countryId) return country.isoCode;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    sexes,
    typesOfBirth,
    birthOrders,
    placesOfOccurrence,
    maritalStatuses,
    occupations,
    literacyLevels,
    educationLevels,
    ethnicGroups,
    relationships,
    countries,
  ];
}
