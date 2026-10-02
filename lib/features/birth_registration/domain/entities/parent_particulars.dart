import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/person_fields.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';

enum ParentRole { mother, father }

/// Mother and Father step fields, in form order. Values are text or option
/// ids; [sameResidenceAsMother] is [answerYes] or [answerNo].
enum ParentField {
  nin,
  surname,
  firstName,
  maidenName,
  middleName,
  sameResidenceAsMother,
  country,
  state,
  lga,
  address,
  settlement,
  age,
  maritalStatus,
  nationality,
  stateOfOrigin,
  lgaOfOrigin,
  ethnicGroup,
  literacy,
  educationLevel,
  occupation,
  phone;

  bool get isOptional => this == nin || this == middleName || this == phone;

  List<ParentField> get dependents => switch (this) {
    country => const [state, lga],
    state => const [lga],
    nationality => const [stateOfOrigin, lgaOfOrigin, ethnicGroup],
    literacy => const [educationLevel],
    stateOfOrigin => const [lgaOfOrigin],
    _ => const [],
  };
}

/// "Particulars of Mother" or "Particulars of Father".
final class ParentParticulars extends Equatable {
  const ParentParticulars([this.values = const {}]);

  factory ParentParticulars.fromJson(Object? json) =>
      ParentParticulars(valuesFromJson(json, ParentField.values));

  final Map<ParentField, String> values;

  String? operator [](ParentField field) => values[field];

  bool get hasNin => values[ParentField.nin] != null;

  /// Has a nationality other than Nigerian, so needs a passport.
  bool get isForeign {
    final nationality = values[ParentField.nationality];
    return nationality != null && nationality != ReferenceData.nigeria;
  }

  /// Only the father is asked; a yes skips his residence fields.
  bool livesWithMother(ParentRole role) =>
      role == ParentRole.father &&
      values[ParentField.sameResidenceAsMother] == answerYes;

  /// Whether [field] is asked, given the role and the answers so far.
  /// State and LGA only exist in Nigeria.
  bool applies(ParentField field, ParentRole role) {
    bool inNigeria(ParentField country) {
      final value = values[country];
      return value == null || value == ReferenceData.nigeria;
    }

    return switch (field) {
      ParentField.maidenName => role == ParentRole.mother,
      ParentField.sameResidenceAsMother => role == ParentRole.father,
      ParentField.country ||
      ParentField.address ||
      ParentField.settlement => !livesWithMother(role),
      ParentField.state || ParentField.lga =>
        !livesWithMother(role) && inNigeria(ParentField.country),
      ParentField.stateOfOrigin ||
      ParentField.lgaOfOrigin ||
      // The API keeps ethnic groups for Nigerians only.
      ParentField.ethnicGroup => inNigeria(ParentField.nationality),
      // Only a literate parent is asked.
      ParentField.educationLevel =>
        values[ParentField.literacy] == null ||
            values[ParentField.literacy] == ReferenceData.literate,
      _ => true,
    };
  }

  ParentParticulars set(ParentField field, String? value) =>
      ParentParticulars(withValue(values, field, value, field.dependents));

  PersonFieldError? errorOf(ParentField field, ParentRole role) {
    if (!applies(field, role)) return null;
    final value = values[field];
    if (value == null) {
      return field.isOptional ? null : PersonFieldError.required;
    }
    return switch (field) {
      ParentField.nin when !isValidNin(value) => PersonFieldError.invalidNin,
      ParentField.phone when !isValidPhone(value) =>
        PersonFieldError.invalidPhone,
      ParentField.age when !isValidParentAge(value) =>
        PersonFieldError.invalidAge,
      _ => null,
    };
  }

  bool isComplete(ParentRole role) =>
      ParentField.values.every((field) => errorOf(field, role) == null);

  Map<String, Object?> toJson() => valuesToJson(values);

  @override
  List<Object?> get props => [values];
}
