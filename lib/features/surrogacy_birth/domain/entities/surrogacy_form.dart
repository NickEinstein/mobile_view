import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';

// The surrogacy birth form: the child is steps 1–2, the parents 3–5.

/// The form's steps, in order.
enum SurrogacyStep {
  child,
  surrogacy,
  legalMother,
  legalFather,
  surrogateMother,
  informant,
  documents,
  review;

  static const count = 8;
  int get number => index + 1;

  /// The API's section, saved with `PATCH …/section` when this step
  /// is done. The review has none.
  SurrogacySection? get section => switch (this) {
    child || surrogacy => SurrogacySection.child,
    legalMother || legalFather || surrogateMother => SurrogacySection.parents,
    informant => SurrogacySection.informant,
    documents => SurrogacySection.documents,
    review => null,
  };
}

/// The API's section numbers.
enum SurrogacySection {
  child(1),
  parents(2),
  informant(3),
  documents(4);

  const SurrogacySection(this.number);

  final int number;
}

enum SurrogacyFieldError {
  required,
  futureDate,

  /// Not 11 digits.
  invalidNin,

  /// A NIN was typed but not validated.
  ninNotVerified,

  /// The surrogate mother's age is implausible for the birth order.
  invalidAge,
  invalidPhone,
}

/// Ids with a special meaning.
abstract final class SurrogacyCodes {
  /// Nigeria. The child's birth is
  /// always in Nigeria.
  static const nigeria = '63';

  /// The sex ids, which the NIN's gender prefills.
  static const male = '1';
  static const female = '2';

  /// "Literate" in the literacy list: only then is the level of
  /// education asked.
  static const literate = '1';
}

/// The three people of steps 3–5.
enum SurrogacyPerson { legalMother, legalFather, surrogateMother, informant }

final _ninPattern = RegExp(r'^\d{11}$');
final _phonePattern = RegExp(r'^\d{11}$');

/// Optional, but once typed a NIN must be 11 digits and [verified].
SurrogacyFieldError? _ninError(String? nin, String? verified) {
  if (nin == null) return null;
  if (!_ninPattern.hasMatch(nin)) return SurrogacyFieldError.invalidNin;
  if (nin != verified) return SurrogacyFieldError.ninNotVerified;
  return null;
}

SurrogacyFieldError? _phoneError(String? phone) =>
    phone == null || _phonePattern.hasMatch(phone)
    ? null
    : SurrogacyFieldError.invalidPhone;

// ---- Step 1: Particulars of Child ------------------------------------------

/// Values are text, option ids, an ISO date (`dateOfBirth`) or a private
/// file path (`facePhoto`).
enum ChildField {
  // Legally required fields: from the court surrogacy agreement.
  surname,
  firstName,
  middleName,
  dateOfBirth,
  birthOrder,
  sex,
  typeOfBirth,

  // Additional fields, all optional.
  placeOfBirth,
  stateOfBirth,
  lgaOfBirth,
  townOfBirth,
  registrationState,
  registrationLga,
  registrationCenter,
  localityOfBirth,
  facePhoto;

  bool get isRequired => switch (this) {
    surname ||
    firstName ||
    dateOfBirth ||
    birthOrder ||
    sex ||
    typeOfBirth => true,
    _ => false,
  };

  /// Filled from the child's NIN and locked once it's verified.
  bool get comesFromNin => this == surname || this == firstName || this == sex;

  /// Fields cleared when this one changes, because their options depend
  /// on it.
  List<ChildField> get dependents => switch (this) {
    stateOfBirth => const [lgaOfBirth],
    registrationState => const [registrationLga, registrationCenter],
    registrationLga => const [registrationCenter],
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

  SurrogacyFieldError? errorOf(ChildField field, {required DateTime today}) {
    if (values[field] == null) {
      return field.isRequired ? SurrogacyFieldError.required : null;
    }
    if (field == ChildField.dateOfBirth) {
      final date = dateOfBirth;
      if (date == null) return SurrogacyFieldError.required;
      if (date.isAfter(today)) return SurrogacyFieldError.futureDate;
    }
    return null;
  }

  bool isComplete({required DateTime today}) =>
      ChildField.values.every((field) => errorOf(field, today: today) == null);

  @override
  List<Object?> get props => [values];
}

// ---- Step 2: Surrogacy Details ---------------------------------------------

enum SurrogacyDetailsField {
  arrangementType,
  courtName,
  orderReference,
  orderDate,
}

/// The court order behind the surrogacy. Every field is required.
final class SurrogacyDetails extends Equatable {
  const SurrogacyDetails([this.values = const FieldValues()]);

  factory SurrogacyDetails.fromJson(Object? json) => SurrogacyDetails(
    FieldValues.fromJson(json, SurrogacyDetailsField.values),
  );

  final FieldValues<SurrogacyDetailsField> values;

  String? operator [](SurrogacyDetailsField field) => values[field];

  DateTime? get orderDate =>
      DateTime.tryParse(values[SurrogacyDetailsField.orderDate] ?? '');

  SurrogacyDetails set(SurrogacyDetailsField field, String? value) =>
      SurrogacyDetails(values.set(field, value));

  SurrogacyFieldError? errorOf(
    SurrogacyDetailsField field, {
    required DateTime today,
  }) {
    if (values[field] == null) return SurrogacyFieldError.required;
    if (field == SurrogacyDetailsField.orderDate) {
      final date = orderDate;
      if (date == null) return SurrogacyFieldError.required;
      if (date.isAfter(today)) return SurrogacyFieldError.futureDate;
    }
    return null;
  }

  bool isComplete({required DateTime today}) => SurrogacyDetailsField.values
      .every((field) => errorOf(field, today: today) == null);

  @override
  List<Object?> get props => [values];
}

// ---- Steps 3–4: Legal Parent (Mother) and (Father) -------------------------

/// A legal parent, as the designs lay it out. Origin,
/// locality and passport number are optional there and not in the designs.
enum ParentField {
  nin,

  /// The NIN the identity service confirmed.
  verifiedNin,
  surname,
  firstName,
  middleName,
  maritalStatus,
  address,
  occupation,
  nationality,
  country,

  /// These two only for a residence in Nigeria.
  state,
  lga,
  localityType,
  literacy,

  /// Only when literate.
  educationLevel,
  phone;

  bool get isRequired => switch (this) {
    surname ||
    firstName ||
    maritalStatus ||
    address ||
    occupation ||
    nationality ||
    country ||
    state ||
    lga ||
    localityType => true,
    _ => false,
  };

  List<ParentField> get dependents => switch (this) {
    country => const [state, lga],
    state => const [lga],
    literacy => const [educationLevel],
    _ => const [],
  };
}

final class ParentParticulars extends Equatable {
  const ParentParticulars([this.values = const FieldValues()]);

  factory ParentParticulars.fromJson(Object? json) =>
      ParentParticulars(FieldValues.fromJson(json, ParentField.values));

  final FieldValues<ParentField> values;

  String? operator [](ParentField field) => values[field];

  bool get isNinVerified =>
      values[ParentField.nin] != null &&
      values[ParentField.nin] == values[ParentField.verifiedNin];

  /// "Surname First Middle", as the backend's single full name.
  String? get fullName => _fullName(
    values[ParentField.surname],
    values[ParentField.firstName],
    values[ParentField.middleName],
  );

  ParentParticulars set(ParentField field, String? value) =>
      ParentParticulars(values.set(field, value, dependents: field.dependents));

  bool applies(ParentField field) => switch (field) {
    ParentField.state ||
    ParentField.lga => values[ParentField.country] == SurrogacyCodes.nigeria,
    ParentField.educationLevel =>
      values[ParentField.literacy] == SurrogacyCodes.literate,
    ParentField.verifiedNin => false,
    _ => true,
  };

  SurrogacyFieldError? errorOf(ParentField field) {
    if (!applies(field)) return null;
    final value = values[field];
    return switch (field) {
      ParentField.nin => _ninError(value, values[ParentField.verifiedNin]),
      ParentField.phone => _phoneError(value),
      _ when value == null && field.isRequired => SurrogacyFieldError.required,
      _ => null,
    };
  }

  bool get isComplete =>
      ParentField.values.every((field) => errorOf(field) == null);

  @override
  List<Object?> get props => [values];
}

// ---- Step 5: Surrogate Mother (optional) -----------------------------------

enum SurrogateField {
  nin,

  /// The NIN the identity service confirmed.
  verifiedNin,

  // Legally required, once any detail is given.
  surname,
  firstName,
  middleName,
  ageAtBirth,
  birthOrder,

  // Additional fields.
  address,
  nationality,
  countryOfOrigin,

  /// These two only for a Nigerian.
  stateOfOrigin,
  lgaOfOrigin,
  town,
  localityType,
  literacy,

  /// Only when literate.
  educationLevel,
  occupation,
  phone;

  bool get isRequired =>
      this == surname ||
      this == firstName ||
      this == ageAtBirth ||
      this == birthOrder;

  List<SurrogateField> get dependents => switch (this) {
    nationality => const [stateOfOrigin, lgaOfOrigin],
    stateOfOrigin => const [lgaOfOrigin],
    literacy => const [educationLevel],
    _ => const [],
  };
}

final class SurrogateMotherParticulars extends Equatable {
  const SurrogateMotherParticulars([this.values = const FieldValues()]);

  factory SurrogateMotherParticulars.fromJson(Object? json) =>
      SurrogateMotherParticulars(
        FieldValues.fromJson(json, SurrogateField.values),
      );

  /// The registry's age limits for a mother.
  static const minAge = 9;
  static const maxAge = 60;

  final FieldValues<SurrogateField> values;

  String? operator [](SurrogateField field) => values[field];

  /// Nothing entered: the section is skipped.
  bool get isEmpty => values.values.isEmpty;

  bool get isNinVerified =>
      values[SurrogateField.nin] != null &&
      values[SurrogateField.nin] == values[SurrogateField.verifiedNin];

  String? get fullName => _fullName(
    values[SurrogateField.surname],
    values[SurrogateField.firstName],
    values[SurrogateField.middleName],
  );

  /// One more year for each birth before this one.
  int get minAgeForBirthOrder {
    final order = int.tryParse(values[SurrogateField.birthOrder] ?? '') ?? 1;
    return order > 1 ? minAge + order - 1 : minAge;
  }

  SurrogateMotherParticulars set(SurrogateField field, String? value) =>
      SurrogateMotherParticulars(
        values.set(field, value, dependents: field.dependents),
      );

  bool applies(SurrogateField field) => switch (field) {
    SurrogateField.stateOfOrigin || SurrogateField.lgaOfOrigin =>
      values[SurrogateField.nationality] == SurrogacyCodes.nigeria,
    SurrogateField.educationLevel =>
      values[SurrogateField.literacy] == SurrogacyCodes.literate,
    SurrogateField.verifiedNin => false,
    _ => true,
  };

  SurrogacyFieldError? errorOf(SurrogateField field) {
    if (!applies(field)) return null;
    final value = values[field];
    switch (field) {
      case SurrogateField.nin:
        return _ninError(value, values[SurrogateField.verifiedNin]);
      case SurrogateField.phone:
        return _phoneError(value);
      case _ when value == null:
        return field.isRequired && !isEmpty
            ? SurrogacyFieldError.required
            : null;
      case SurrogateField.ageAtBirth:
        final age = int.tryParse(value);
        return age == null || age < minAgeForBirthOrder || age > maxAge
            ? SurrogacyFieldError.invalidAge
            : null;
      case _:
        return null;
    }
  }

  bool get isComplete =>
      SurrogateField.values.every((field) => errorOf(field) == null);

  @override
  List<Object?> get props => [values];
}

String? _fullName(String? surname, String? firstName, String? middleName) {
  final name = [?surname, ?firstName, ?middleName].join(' ');
  return name.isEmpty ? null : name;
}

// ---- Step 6: Particulars of Informant --------------------------------------

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

/// Values are text, option ids, `Answer`/`ConsentType` values, or private
/// file paths (`signature`, `face`).
enum InformantField {
  nin,

  /// The NIN the identity service confirmed.
  verifiedNin,
  surname,
  firstName,
  middleName,

  /// "Is the place of residence the same as that of Legal Parent
  /// (Mother)?" Yes copies her residence.
  sameResidence,
  country,

  /// These two only for a residence in Nigeria.
  state,
  lga,
  address,
  nationality,
  countryOfOrigin,

  /// These two only for an origin in Nigeria.
  stateOfOrigin,
  lgaOfOrigin,
  relationship,
  phone,
  passportNumber,
  consentType,

  /// The drawn signature, when consenting by signature.
  signature,

  /// The captured face, when consenting by face.
  face;

  bool get isRequired => switch (this) {
    surname ||
    firstName ||
    country ||
    state ||
    lga ||
    address ||
    relationship ||
    phone ||
    consentType ||
    signature ||
    face => true,
    _ => false,
  };

  List<InformantField> get dependents => switch (this) {
    country => const [state, lga],
    state => const [lga],
    countryOfOrigin => const [stateOfOrigin, lgaOfOrigin],
    stateOfOrigin => const [lgaOfOrigin],
    _ => const [],
  };
}

final class InformantParticulars extends Equatable {
  const InformantParticulars([this.values = const FieldValues()]);

  factory InformantParticulars.fromJson(Object? json) =>
      InformantParticulars(FieldValues.fromJson(json, InformantField.values));

  final FieldValues<InformantField> values;

  String? operator [](InformantField field) => values[field];

  bool get isNinVerified =>
      values[InformantField.nin] != null &&
      values[InformantField.nin] == values[InformantField.verifiedNin];

  InformantParticulars set(InformantField field, String? value) =>
      InformantParticulars(
        values.set(field, value, dependents: field.dependents),
      );

  /// "Yes" to the same residence: her country, state, LGA and address.
  InformantParticulars copyResidenceFrom(ParentParticulars mother) {
    var next = values;
    for (final (mine, hers) in [
      (InformantField.country, ParentField.country),
      (InformantField.state, ParentField.state),
      (InformantField.lga, ParentField.lga),
      (InformantField.address, ParentField.address),
    ]) {
      // Not through `set`, which would clear the state with the country.
      next = FieldValues({...next.values}..remove(mine));
      if (mother[hers] case final value?) {
        next = FieldValues({...next.values, mine: value});
      }
    }
    return InformantParticulars(next);
  }

  bool applies(InformantField field) => switch (field) {
    InformantField.state || InformantField.lga =>
      values[InformantField.country] == SurrogacyCodes.nigeria,
    InformantField.stateOfOrigin || InformantField.lgaOfOrigin =>
      values[InformantField.countryOfOrigin] == SurrogacyCodes.nigeria,
    InformantField.signature =>
      values[InformantField.consentType] == ConsentType.signature,
    InformantField.face =>
      values[InformantField.consentType] == ConsentType.faceCapture,
    InformantField.verifiedNin => false,
    _ => true,
  };

  SurrogacyFieldError? errorOf(InformantField field) {
    if (!applies(field)) return null;
    final value = values[field];
    return switch (field) {
      InformantField.nin => _ninError(
        value,
        values[InformantField.verifiedNin],
      ),
      InformantField.phone when value != null => _phoneError(value),
      _ when value == null && field.isRequired => SurrogacyFieldError.required,
      _ => null,
    };
  }

  bool get isComplete =>
      InformantField.values.every((field) => errorOf(field) == null);

  @override
  List<Object?> get props => [values];
}

// ---- Step 7: Upload Documents ----------------------------------------------

/// The supporting documents, with the API's `type` keys.
enum SurrogacyDocument {
  courtOrder('court_surrogacy_agreement_order'),
  parentalOrder('parental_order'),
  motherIdentity('legal_mother_identity_document'),

  /// Only when a second legal parent is named.
  fatherIdentity('legal_father_identity_document');

  const SurrogacyDocument(this.apiType);

  final String apiType;

  /// The API's `type` for the informant's passport, sent with these.
  static const passportType = 'international-passport';
}
