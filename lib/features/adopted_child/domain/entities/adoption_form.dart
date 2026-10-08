import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';

// The adopted child form, with the registry's fields and rules. The
// designs split "Particulars of Adopter(s)" into one step per adopter.

/// The form's steps, in order.
enum AdoptionStep {
  child,
  adopter1,
  adopter2,
  adoptionDetails,
  informant,
  documents,
  review;

  static const count = 7;
  int get number => index + 1;

  /// The API's section, saved with `PATCH …/section` when this step
  /// is done. The review has none.
  AdoptionSection? get section => switch (this) {
    child => AdoptionSection.child,
    adopter1 || adopter2 => AdoptionSection.parents,
    adoptionDetails => AdoptionSection.adoptionDetails,
    informant => AdoptionSection.informant,
    documents => AdoptionSection.documents,
    review => null,
  };
}

/// The API's section numbers.
enum AdoptionSection {
  child(1),
  parents(2),
  adoptionDetails(3),
  informant(4),
  documents(5);

  const AdoptionSection(this.number);

  final int number;
}

enum AdoptionFieldError {
  required,
  futureDate,

  /// Not 11 digits.
  invalidNin,

  /// A NIN was typed but not validated.
  ninNotVerified,
  invalidPhone,
}

/// Ids with a special meaning.
abstract final class AdoptionCodes {
  /// Nigeria. The child's birth is
  /// always in Nigeria.
  static const nigeria = '63';

  /// The sex ids, which the NIN's gender prefills.
  static const male = '1';
  static const female = '2';

  /// "Literate" in the literacy list: only then is the level of
  /// education asked.
  static const literate = '1';

  /// The backend's `adoptionType` values.
  static const domestic = 'domestic';
  static const interCountry = 'inter_country';
}

// ---- Step 1: Particulars of Child ------------------------------------------

/// Values are text, option ids, an ISO date (`dateOfBirth`) or a private
/// file path (`facePhoto`).
enum ChildField {
  // Legally required fields: from the adoption order.
  surname,
  firstName,
  middleName,
  dateOfBirth,
  sex,

  // Additional fields, all optional.
  previousFullName,
  placeOfBirth,
  birthOrder,
  stateOfBirth,
  lgaOfBirth,
  townOfBirth,
  registrationState,
  registrationLga,
  registrationCenter,
  localityOfBirth,
  facePhoto;

  bool get isRequired => switch (this) {
    surname || firstName || dateOfBirth || sex => true,
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

  AdoptionFieldError? errorOf(ChildField field, {required DateTime today}) {
    if (values[field] == null) {
      return field.isRequired ? AdoptionFieldError.required : null;
    }
    if (field == ChildField.dateOfBirth) {
      final date = dateOfBirth;
      if (date == null) return AdoptionFieldError.required;
      if (date.isAfter(today)) return AdoptionFieldError.futureDate;
    }
    return null;
  }

  bool isComplete({required DateTime today}) =>
      ChildField.values.every((field) => errorOf(field, today: today) == null);

  @override
  List<Object?> get props => [values];
}

// ---- Steps 2–3: Particulars of Adopter 1 and Adopter 2 (Optional) ---------

/// The two adopters the adoption order may name.
enum Adopter { first, second }

/// An adopter. The names are joined into the backend's single full name.
enum AdopterField {
  nin,

  /// The NIN the identity service confirmed.
  verifiedNin,
  surname,
  firstName,
  middleName,
  maritalStatus,
  nationality,
  address,
  occupation,
  country,

  /// These two only for a residence in Nigeria.
  state,
  lga,
  localityType,
  literacy,

  /// Only when literate.
  educationLevel,
  phone;

  /// The required fields; the residence is an
  /// additional field there.
  bool get isRequired => switch (this) {
    nin ||
    surname ||
    firstName ||
    maritalStatus ||
    nationality ||
    address ||
    occupation => true,
    _ => false,
  };

  List<AdopterField> get dependents => switch (this) {
    country => const [state, lga],
    state => const [lga],
    literacy => const [educationLevel],
    _ => const [],
  };
}

final _ninPattern = RegExp(r'^\d{11}$');
final _phonePattern = RegExp(r'^\d{11}$');

final class AdopterParticulars extends Equatable {
  const AdopterParticulars([this.values = const FieldValues()]);

  factory AdopterParticulars.fromJson(Object? json) =>
      AdopterParticulars(FieldValues.fromJson(json, AdopterField.values));

  final FieldValues<AdopterField> values;

  String? operator [](AdopterField field) => values[field];

  /// Nothing entered. The second adopter is then left out, as when its
  /// name is empty.
  bool get isEmpty => values.values.isEmpty;

  bool get isNinVerified =>
      values[AdopterField.nin] != null &&
      values[AdopterField.nin] == values[AdopterField.verifiedNin];

  /// "Surname First Middle", as the backend's single full name.
  String? get fullName {
    final name = [
      ?values[AdopterField.surname],
      ?values[AdopterField.firstName],
      ?values[AdopterField.middleName],
    ].join(' ');
    return name.isEmpty ? null : name;
  }

  AdopterParticulars set(AdopterField field, String? value) =>
      AdopterParticulars(
        values.set(field, value, dependents: field.dependents),
      );

  bool applies(AdopterField field) => switch (field) {
    AdopterField.state ||
    AdopterField.lga => values[AdopterField.country] == AdoptionCodes.nigeria,
    AdopterField.educationLevel =>
      values[AdopterField.literacy] == AdoptionCodes.literate,
    AdopterField.verifiedNin => false,
    _ => true,
  };

  /// [optional]: the second adopter, whose fields are only required once
  /// any of them is given.
  AdoptionFieldError? errorOf(AdopterField field, {bool optional = false}) {
    if (!applies(field) || (optional && isEmpty)) return null;
    final value = values[field];
    if (value == null) {
      return field.isRequired ? AdoptionFieldError.required : null;
    }
    return switch (field) {
      // The NIN is required and must be the one the identity service
      // confirmed (editing it undoes that).
      AdopterField.nin when !_ninPattern.hasMatch(value) =>
        AdoptionFieldError.invalidNin,
      AdopterField.nin when !isNinVerified => AdoptionFieldError.ninNotVerified,
      AdopterField.phone when !_phonePattern.hasMatch(value) =>
        AdoptionFieldError.invalidPhone,
      _ => null,
    };
  }

  bool isComplete({bool optional = false}) => AdopterField.values.every(
    (field) => errorOf(field, optional: optional) == null,
  );

  @override
  List<Object?> get props => [values];
}

// ---- Step 4: Adoption Details ----------------------------------------------

enum AdoptionDetailsField { adoptionType, courtName, orderReference, orderDate }

/// The adoption order. Every field is required.
final class AdoptionDetails extends Equatable {
  const AdoptionDetails([this.values = const FieldValues()]);

  factory AdoptionDetails.fromJson(Object? json) =>
      AdoptionDetails(FieldValues.fromJson(json, AdoptionDetailsField.values));

  final FieldValues<AdoptionDetailsField> values;

  String? operator [](AdoptionDetailsField field) => values[field];

  DateTime? get orderDate =>
      DateTime.tryParse(values[AdoptionDetailsField.orderDate] ?? '');

  AdoptionDetails set(AdoptionDetailsField field, String? value) =>
      AdoptionDetails(values.set(field, value));

  AdoptionFieldError? errorOf(
    AdoptionDetailsField field, {
    required DateTime today,
  }) {
    if (values[field] == null) return AdoptionFieldError.required;
    if (field == AdoptionDetailsField.orderDate) {
      final date = orderDate;
      if (date == null) return AdoptionFieldError.required;
      if (date.isAfter(today)) return AdoptionFieldError.futureDate;
    }
    return null;
  }

  bool isComplete({required DateTime today}) => AdoptionDetailsField.values
      .every((field) => errorOf(field, today: today) == null);

  @override
  List<Object?> get props => [values];
}

// ---- Step 5: Particulars of Informant --------------------------------------

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

/// The informant's details, plus the design's NIN.
enum InformantField {
  /// Optional, as the design draws it; once typed it must be validated.
  nin,

  /// The NIN the identity service confirmed.
  verifiedNin,
  surname,
  firstName,
  middleName,

  /// "Is the place of residence the same as that of Adopter 1?" Yes
  /// copies Adopter 1's residence.
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

  /// "Yes" to the same residence: Adopter 1's country, state, LGA and
  /// address.
  InformantParticulars copyResidenceFrom(AdopterParticulars adopter) {
    final next = Map<InformantField, String>.of(values.values);
    for (final (mine, theirs) in [
      (InformantField.country, AdopterField.country),
      (InformantField.state, AdopterField.state),
      (InformantField.lga, AdopterField.lga),
      (InformantField.address, AdopterField.address),
    ]) {
      // Not through `set`, which would clear the state with the country.
      next.remove(mine);
      if (adopter[theirs] case final value?) next[mine] = value;
    }
    return InformantParticulars(FieldValues(next));
  }

  bool applies(InformantField field) => switch (field) {
    InformantField.state || InformantField.lga =>
      values[InformantField.country] == AdoptionCodes.nigeria,
    InformantField.stateOfOrigin || InformantField.lgaOfOrigin =>
      values[InformantField.countryOfOrigin] == AdoptionCodes.nigeria,
    InformantField.signature =>
      values[InformantField.consentType] == ConsentType.signature,
    InformantField.face =>
      values[InformantField.consentType] == ConsentType.faceCapture,
    InformantField.verifiedNin => false,
    _ => true,
  };

  AdoptionFieldError? errorOf(InformantField field) {
    if (!applies(field)) return null;
    final value = values[field];
    if (value == null) {
      return field.isRequired ? AdoptionFieldError.required : null;
    }
    return switch (field) {
      InformantField.nin when !_ninPattern.hasMatch(value) =>
        AdoptionFieldError.invalidNin,
      InformantField.nin when !isNinVerified =>
        AdoptionFieldError.ninNotVerified,
      InformantField.phone when !_phonePattern.hasMatch(value) =>
        AdoptionFieldError.invalidPhone,
      _ => null,
    };
  }

  bool get isComplete =>
      InformantField.values.every((field) => errorOf(field) == null);

  @override
  List<Object?> get props => [values];
}

// ---- Step 6: Upload Documents ----------------------------------------------

/// The supporting documents, with the API's `type` keys.
enum AdoptionDocument {
  courtOrder('court_adoption_order'),
  adoptionCertificate('adoption_certificate'),
  adopter1Identity('adoptive_mother_identity_document'),

  /// Only when a second adopter is given.
  adopter2Identity('adoptive_father_identity_document');

  const AdoptionDocument(this.apiType);

  final String apiType;

  /// The API's `type` for the informant's passport, sent with these.
  static const passportType = 'international-passport';
}
