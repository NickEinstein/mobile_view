import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';

// The foreign birth notification form.

/// The form's steps, in order. The designs number them "of 8" because
/// they were drawn from Surrogacy; the form has these six.
enum ForeignBirthStep {
  child,
  mother,
  father,
  informant,
  documents,
  review;

  static const count = 6;
  int get number => index + 1;
}

enum ForeignBirthFieldError {
  required,
  futureDate,

  /// Not 11 digits.
  invalidNin,

  /// A NIN was typed but not validated.
  ninNotVerified,

  /// Not 11 to 15 digits.
  invalidPhone,

  /// Outside the parent's age range.
  invalidAge,
  invalidEmail,
}

/// Ids the backend gives special meaning.
abstract final class ForeignBirthCodes {
  /// Nigeria. A foreign birth is never
  /// in Nigeria, but at least one parent must be Nigerian.
  static const nigeria = '63';

  /// "Literate" in the literacy list: only then is the level of
  /// education asked.
  static const literate = '1';

  /// The informant's relationship ids for a parent. The backend then
  /// links the parent instead of creating an informant.
  static const father = '1';
  static const mother = '2';
}

/// How the informant consents.
abstract final class ConsentType {
  static const signature = 'signature';
  static const faceCapture = 'face_capture';
}

/// "Yes"/"No" answers, kept as text in the draft.
abstract final class Answer {
  static const yes = 'yes';
  static const no = 'no';
}

// ---- Step 1: Particulars of Child ------------------------------------------

/// Values are text, option ids, an ISO date (`dateOfBirth`) or a private
/// file path (`facePhoto`).
enum ChildField {
  surname,
  firstName,
  middleName,
  dateOfBirth,
  sex,
  typeOfBirth,
  birthOrder,
  placeOfOccurrence,

  /// Any country but Nigeria.
  countryOfBirth,

  /// A state, city or province of [countryOfBirth].
  stateOfBirth,

  /// Optional.
  facePhoto;

  bool get isRequired => switch (this) {
    middleName || facePhoto => false,
    _ => true,
  };

  /// Fields cleared when this one changes, because their options depend
  /// on it.
  List<ChildField> get dependents => switch (this) {
    countryOfBirth => const [stateOfBirth],
    _ => const [],
  };
}

final class ChildParticulars extends Equatable {
  const ChildParticulars([this.values = const FieldValues()]);

  factory ChildParticulars.fromJson(Object? json) =>
      ChildParticulars(FieldValues.fromJson(json, ChildField.values));

  final FieldValues<ChildField> values;

  String? operator [](ChildField field) => values[field];

  DateTime? get dateOfBirth =>
      DateTime.tryParse(values[ChildField.dateOfBirth] ?? '');

  ChildParticulars set(ChildField field, String? value) =>
      ChildParticulars(values.set(field, value, dependents: field.dependents));

  ForeignBirthFieldError? errorOf(ChildField field, {required DateTime today}) {
    if (values[field] == null) {
      return field.isRequired ? ForeignBirthFieldError.required : null;
    }
    if (field == ChildField.dateOfBirth) {
      final date = dateOfBirth;
      if (date == null) return ForeignBirthFieldError.required;
      if (date.isAfter(today)) return ForeignBirthFieldError.futureDate;
    }
    return null;
  }

  bool isComplete({required DateTime today}) =>
      ChildField.values.every((field) => errorOf(field, today: today) == null);

  @override
  List<Object?> get props => [values];
}

// ---- Steps 2–3: Particulars of Mother and Father ---------------------------

/// The child's two parents. Both are always given.
enum Parent {
  mother(minAge: 10, maxAge: 60),
  father(minAge: 10, maxAge: 90);

  const Parent({required this.minAge, required this.maxAge});

  /// The backend rejects an age
  /// under 10 for either parent.
  final int minAge;
  final int maxAge;
}

/// A parent. The design's "Country of Origin" is the nationality.
enum ParentField {
  nin,

  /// The NIN the identity service confirmed.
  verifiedNin,
  surname,
  firstName,
  middleName,

  /// Mother only.
  maidenName,
  maritalStatus,
  age,
  nationality,

  /// A state, city or province of [nationality].
  stateOfOrigin,

  /// These two only for a Nigerian.
  lgaOfOrigin,
  ethnicGroup,

  /// Mother only, and required for her.
  occupation,

  /// Father only: "Is the place of residence the same as that of
  /// Mother?" Yes copies her residence. Not sent.
  sameResidence,
  country,

  /// A state, city or province of [country].
  state,

  /// Only for a residence in Nigeria.
  lga,
  address,
  literacy,

  /// Only when literate.
  educationLevel,
  phone;

  /// Filled from a verified NIN and locked.
  bool get comesFromNin => this == surname || this == firstName;

  List<ParentField> get dependents => switch (this) {
    // A NIN is only asked of a Nigerian.
    nationality => const [
      stateOfOrigin,
      lgaOfOrigin,
      ethnicGroup,
      nin,
      verifiedNin,
    ],
    stateOfOrigin => const [lgaOfOrigin],
    country => const [state, lga],
    state => const [lga],
    literacy => const [educationLevel],
    _ => const [],
  };
}

final _ninPattern = RegExp(r'^\d{11}$');
final _phonePattern = RegExp(r'^\d{11,15}$');

final class ParentParticulars extends Equatable {
  const ParentParticulars([this.values = const FieldValues()]);

  factory ParentParticulars.fromJson(Object? json) =>
      ParentParticulars(FieldValues.fromJson(json, ParentField.values));

  final FieldValues<ParentField> values;

  String? operator [](ParentField field) => values[field];

  bool get isNigerian =>
      values[ParentField.nationality] == ForeignBirthCodes.nigeria;

  bool get livesInNigeria =>
      values[ParentField.country] == ForeignBirthCodes.nigeria;

  bool get isNinVerified =>
      values[ParentField.nin] != null &&
      values[ParentField.nin] == values[ParentField.verifiedNin];

  /// Whether [field] is locked because a verified NIN filled it.
  bool isLocked(ParentField field) => isNinVerified && field.comesFromNin;

  ParentParticulars set(ParentField field, String? value) {
    var next = values.set(field, value, dependents: field.dependents);
    // Editing the NIN undoes its verification and unlocks the name.
    if (field == ParentField.nin && value != values[ParentField.verifiedNin]) {
      next = next.set(ParentField.verifiedNin, null);
    }
    return ParentParticulars(next);
  }

  bool applies(ParentField field, Parent parent) => switch (field) {
    ParentField.maidenName || ParentField.occupation => parent == Parent.mother,
    ParentField.sameResidence => parent == Parent.father,
    ParentField.lgaOfOrigin || ParentField.ethnicGroup => isNigerian,
    ParentField.lga => livesInNigeria,
    ParentField.educationLevel =>
      values[ParentField.literacy] == ForeignBirthCodes.literate,
    ParentField.verifiedNin => false,
    _ => true,
  };

  bool isRequired(ParentField field, Parent parent) => switch (field) {
    ParentField.middleName ||
    ParentField.phone ||
    ParentField.sameResidence => false,
    // Required of a Nigerian; anyone else may give one.
    ParentField.nin => isNigerian,
    _ => applies(field, parent),
  };

  ForeignBirthFieldError? errorOf(ParentField field, Parent parent) {
    if (!applies(field, parent)) return null;
    final value = values[field];
    if (value == null) {
      return isRequired(field, parent) ? ForeignBirthFieldError.required : null;
    }
    return switch (field) {
      ParentField.nin when !_ninPattern.hasMatch(value) =>
        ForeignBirthFieldError.invalidNin,
      ParentField.nin when !isNinVerified =>
        ForeignBirthFieldError.ninNotVerified,
      ParentField.phone when !_phonePattern.hasMatch(value) =>
        ForeignBirthFieldError.invalidPhone,
      ParentField.age
          when !_inRange(int.tryParse(value), parent.minAge, parent.maxAge) =>
        ForeignBirthFieldError.invalidAge,
      _ => null,
    };
  }

  /// "Yes" to the same residence: [other]'s country, state, LGA and
  /// address.
  ParentParticulars copyResidenceFrom(ParentParticulars other) {
    final next = Map<ParentField, String>.of(values.values);
    for (final field in const [
      ParentField.country,
      ParentField.state,
      ParentField.lga,
      ParentField.address,
    ]) {
      // Not through `set`, which would clear the state with the country.
      next.remove(field);
      if (other[field] case final value?) next[field] = value;
    }
    return ParentParticulars(FieldValues(next));
  }

  static bool _inRange(int? value, int min, int max) =>
      value != null && value >= min && value <= max;

  bool isComplete(Parent parent) =>
      ParentField.values.every((field) => errorOf(field, parent) == null);

  @override
  List<Object?> get props => [values];
}

// ---- Step 4: Particulars of Informant --------------------------------------

/// The informant, plus the email the certificate is sent to.
enum InformantField {
  /// Father or mother fills the informant from that parent.
  relationship,
  nin,

  /// The NIN the identity service confirmed.
  verifiedNin,
  surname,
  firstName,
  middleName,

  /// "Is the place of residence the same as that of Mother?" Yes copies
  /// her residence. Not sent.
  sameResidence,
  country,
  state,

  /// Only for a residence in Nigeria.
  lga,
  address,

  /// Required by the backend.
  nationality,
  stateOfOrigin,

  /// Only for a Nigerian.
  lgaOfOrigin,
  phone,
  email,
  consentType,

  /// The drawn signature, when consenting by signature.
  signature,

  /// The captured face, when consenting by face.
  face;

  bool get comesFromNin => this == surname || this == firstName;

  List<InformantField> get dependents => switch (this) {
    nationality => const [stateOfOrigin, lgaOfOrigin, nin, verifiedNin],
    stateOfOrigin => const [lgaOfOrigin],
    country => const [state, lga],
    state => const [lga],
    _ => const [],
  };
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

final class InformantParticulars extends Equatable {
  const InformantParticulars([this.values = const FieldValues()]);

  factory InformantParticulars.fromJson(Object? json) =>
      InformantParticulars(FieldValues.fromJson(json, InformantField.values));

  final FieldValues<InformantField> values;

  String? operator [](InformantField field) => values[field];

  bool get isNigerian =>
      values[InformantField.nationality] == ForeignBirthCodes.nigeria;

  bool get livesInNigeria =>
      values[InformantField.country] == ForeignBirthCodes.nigeria;

  bool get isNinVerified =>
      values[InformantField.nin] != null &&
      values[InformantField.nin] == values[InformantField.verifiedNin];

  bool isLocked(InformantField field) => isNinVerified && field.comesFromNin;

  InformantParticulars set(InformantField field, String? value) {
    var next = values.set(field, value, dependents: field.dependents);
    if (field == InformantField.nin &&
        value != values[InformantField.verifiedNin]) {
      next = next.set(InformantField.verifiedNin, null);
    }
    return InformantParticulars(next);
  }

  /// The parent's particulars, for an informant who is that parent. The
  /// relationship, email and consent are kept.
  InformantParticulars copyFrom(ParentParticulars parent) {
    final next = Map<InformantField, String>.of(values.values);
    for (final (mine, theirs) in const [
      (InformantField.nin, ParentField.nin),
      (InformantField.verifiedNin, ParentField.verifiedNin),
      (InformantField.surname, ParentField.surname),
      (InformantField.firstName, ParentField.firstName),
      (InformantField.middleName, ParentField.middleName),
      (InformantField.country, ParentField.country),
      (InformantField.state, ParentField.state),
      (InformantField.lga, ParentField.lga),
      (InformantField.address, ParentField.address),
      (InformantField.nationality, ParentField.nationality),
      (InformantField.stateOfOrigin, ParentField.stateOfOrigin),
      (InformantField.lgaOfOrigin, ParentField.lgaOfOrigin),
      (InformantField.phone, ParentField.phone),
    ]) {
      // Not through `set`, which would clear dependent fields.
      next.remove(mine);
      if (parent[theirs] case final value?) next[mine] = value;
    }
    next.remove(InformantField.sameResidence);
    return InformantParticulars(FieldValues(next));
  }

  /// "Yes" to the same residence: the mother's country, state, LGA and
  /// address.
  InformantParticulars copyResidenceFrom(ParentParticulars mother) {
    final next = Map<InformantField, String>.of(values.values);
    for (final (mine, theirs) in const [
      (InformantField.country, ParentField.country),
      (InformantField.state, ParentField.state),
      (InformantField.lga, ParentField.lga),
      (InformantField.address, ParentField.address),
    ]) {
      next.remove(mine);
      if (mother[theirs] case final value?) next[mine] = value;
    }
    return InformantParticulars(FieldValues(next));
  }

  bool applies(InformantField field) => switch (field) {
    InformantField.lga => livesInNigeria,
    InformantField.lgaOfOrigin => isNigerian,
    InformantField.signature =>
      values[InformantField.consentType] == ConsentType.signature,
    InformantField.face =>
      values[InformantField.consentType] == ConsentType.faceCapture,
    InformantField.verifiedNin => false,
    _ => true,
  };

  bool isRequired(InformantField field) => switch (field) {
    InformantField.middleName || InformantField.sameResidence => false,
    InformantField.nin || InformantField.stateOfOrigin => isNigerian,
    _ => applies(field),
  };

  ForeignBirthFieldError? errorOf(InformantField field) {
    if (!applies(field)) return null;
    final value = values[field];
    if (value == null) {
      return isRequired(field) ? ForeignBirthFieldError.required : null;
    }
    return switch (field) {
      InformantField.nin when !_ninPattern.hasMatch(value) =>
        ForeignBirthFieldError.invalidNin,
      InformantField.nin when !isNinVerified =>
        ForeignBirthFieldError.ninNotVerified,
      InformantField.phone when !_phonePattern.hasMatch(value) =>
        ForeignBirthFieldError.invalidPhone,
      InformantField.email when !_emailPattern.hasMatch(value) =>
        ForeignBirthFieldError.invalidEmail,
      _ => null,
    };
  }

  bool get isComplete =>
      InformantField.values.every((field) => errorOf(field) == null);

  @override
  List<Object?> get props => [values];
}
