import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';

// The still birth form, with the registry's fields and rules.

/// The form's steps, in order.
enum StillBirthStep {
  deceased,
  mother,
  informant,
  review;

  static const count = 4;
  int get number => index + 1;
}

enum StillBirthFieldError {
  required,
  futureDate,

  /// Before the earliest date accepted.
  tooEarly,

  /// The mother's age is outside 10–60.
  invalidAge,
}

/// Ids with a special meaning.
abstract final class StillBirthCodes {
  /// Nigeria: only a Nigerian address has a state, LGA and settlement.
  static const nigeria = '63';

  /// "Mother" among the informant relationships: the informant's details
  /// are then copied from the mother's.
  static const motherRelationship = '2';
}

// ---- Step 1: Particulars of Deceased ---------------------------------------

enum DeceasedField {
  placeOfOccurrence,
  village,
  dateOfDelivery,
  sex,
  typeOfDelivery,
}

final class DeceasedParticulars extends Equatable {
  const DeceasedParticulars([this.values = const FieldValues()]);

  factory DeceasedParticulars.fromJson(Object? json) =>
      DeceasedParticulars(FieldValues.fromJson(json, DeceasedField.values));

  /// The earliest date of delivery accepted.
  static final earliestDelivery = DateTime(1992, 1, 2);

  final FieldValues<DeceasedField> values;

  String? operator [](DeceasedField field) => values[field];

  DateTime? get dateOfDelivery =>
      DateTime.tryParse(values[DeceasedField.dateOfDelivery] ?? '');

  DeceasedParticulars set(DeceasedField field, String? value) =>
      DeceasedParticulars(values.set(field, value));

  StillBirthFieldError? errorOf(
    DeceasedField field, {
    required DateTime today,
  }) {
    if (values[field] == null) return StillBirthFieldError.required;
    if (field != DeceasedField.dateOfDelivery) return null;
    final date = dateOfDelivery;
    if (date == null) return StillBirthFieldError.required;
    if (date.isAfter(today)) return StillBirthFieldError.futureDate;
    if (date.isBefore(earliestDelivery)) return StillBirthFieldError.tooEarly;
    return null;
  }

  bool isComplete({required DateTime today}) => DeceasedField.values.every(
    (field) => errorOf(field, today: today) == null,
  );

  @override
  List<Object?> get props => [values];
}

// ---- Step 2: Particulars of Mother -----------------------------------------

enum MotherField {
  fullName,
  country,

  /// These four only for a residence in Nigeria.
  state,
  lga,
  address,
  settlement,
  age,
  nationality,

  /// These two only for a Nigerian.
  stateOfOrigin,
  ethnicGroup;

  bool get isResidence =>
      this == state || this == lga || this == address || this == settlement;

  List<MotherField> get dependents => switch (this) {
    country => const [state, lga, address, settlement],
    state => const [lga],
    nationality => const [stateOfOrigin, ethnicGroup],
    _ => const [],
  };
}

final class MotherParticulars extends Equatable {
  const MotherParticulars([this.values = const FieldValues()]);

  factory MotherParticulars.fromJson(Object? json) =>
      MotherParticulars(FieldValues.fromJson(json, MotherField.values));

  static const minAge = 10;
  static const maxAge = 60;

  final FieldValues<MotherField> values;

  String? operator [](MotherField field) => values[field];

  MotherParticulars set(MotherField field, String? value) =>
      MotherParticulars(values.set(field, value, dependents: field.dependents));

  bool applies(MotherField field) => switch (field) {
    _ when field.isResidence =>
      values[MotherField.country] == StillBirthCodes.nigeria,
    MotherField.stateOfOrigin || MotherField.ethnicGroup =>
      values[MotherField.nationality] == StillBirthCodes.nigeria,
    _ => true,
  };

  StillBirthFieldError? errorOf(MotherField field) {
    if (!applies(field)) return null;
    final value = values[field];
    if (value == null) return StillBirthFieldError.required;
    if (field == MotherField.age) {
      final age = int.tryParse(value);
      if (age == null || age < minAge || age > maxAge) {
        return StillBirthFieldError.invalidAge;
      }
    }
    return null;
  }

  bool get isComplete =>
      MotherField.values.every((field) => errorOf(field) == null);

  @override
  List<Object?> get props => [values];
}

// ---- Step 3: Particulars of Informant --------------------------------------

enum InformantField {
  relationship,
  fullName,
  country,

  /// These four only for a residence in Nigeria.
  state,
  lga,
  address,
  settlement,

  /// The drawn signature, a private file path.
  signature;

  bool get isResidence =>
      this == state || this == lga || this == address || this == settlement;

  List<InformantField> get dependents => switch (this) {
    country => const [state, lga, address, settlement],
    state => const [lga],
    _ => const [],
  };
}

final class InformantParticulars extends Equatable {
  const InformantParticulars([this.values = const FieldValues()]);

  factory InformantParticulars.fromJson(Object? json) =>
      InformantParticulars(FieldValues.fromJson(json, InformantField.values));

  final FieldValues<InformantField> values;

  String? operator [](InformantField field) => values[field];

  InformantParticulars set(InformantField field, String? value) =>
      InformantParticulars(
        values.set(field, value, dependents: field.dependents),
      );

  /// The mother is the informant: her name and address, copied when
  /// "Mother" is chosen.
  InformantParticulars copyFromMother(MotherParticulars mother) {
    var next = this;
    for (final (field, from) in [
      (InformantField.fullName, MotherField.fullName),
      (InformantField.country, MotherField.country),
      (InformantField.state, MotherField.state),
      (InformantField.lga, MotherField.lga),
      (InformantField.address, MotherField.address),
      (InformantField.settlement, MotherField.settlement),
    ]) {
      // Not through [set]: a country or state would clear what follows.
      next = InformantParticulars(next.values.set(field, mother[from]));
    }
    return next;
  }

  bool applies(InformantField field) =>
      !field.isResidence ||
      values[InformantField.country] == StillBirthCodes.nigeria;

  StillBirthFieldError? errorOf(InformantField field) =>
      applies(field) && values[field] == null
      ? StillBirthFieldError.required
      : null;

  bool get isComplete =>
      InformantField.values.every((field) => errorOf(field) == null);

  @override
  List<Object?> get props => [values];
}
