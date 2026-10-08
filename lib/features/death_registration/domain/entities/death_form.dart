import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

// The death registration form, with the registry's fields and rules.

/// The form's steps, in order.
enum DeathStep {
  deceased,
  informant,
  documents,
  review;

  static const count = 4;
  int get number => index + 1;
}

enum DeathFieldError {
  required,
  futureDate,

  /// Before the earliest date accepted.
  tooEarly,

  /// Age at death above 150.
  invalidAge,
  invalidNin,

  /// A NIN was typed but not verified yet.
  ninNotVerified,
  invalidPhone,
}

/// Ids with a special meaning.
abstract final class DeathCodes {
  /// Nigeria.
  static const nigeria = '63';

  /// "Literate": only then is the level of education asked.
  static const literate = '1';

  /// Place of death "Hospital": medical proof of death replaces the
  /// police report.
  static const hospital = '1';

  /// "Is it the same as Deceased?"
  static const yes = 'yes';
  static const no = 'no';
}

const _ninLength = 11;
final _digits = RegExp(r'^\d+$');

/// A NIN field's error: 11 digits, verified with the identity service.
DeathFieldError? _ninError(String? nin, {required bool verified}) {
  if (nin == null) return null;
  if (nin.length != _ninLength || !_digits.hasMatch(nin)) {
    return DeathFieldError.invalidNin;
  }
  return verified ? null : DeathFieldError.ninNotVerified;
}

// ---- Step 1: Particulars of Deceased ---------------------------------------

enum DeceasedField {
  nin,

  /// Only without a NIN.
  noNinReason,

  /// Taken from the NIN record when one is verified.
  surname,
  firstName,
  middleName,
  sex,
  country,

  /// These four only for a residence in Nigeria.
  state,
  lga,
  address,
  settlement,
  occupation,
  dateOfDeath,
  placeOfDeath,
  village,
  ageAtDeath,
  nationality,

  /// These three only for a Nigerian.
  stateOfOrigin,
  lgaOfOrigin,
  ethnicGroup,
  maritalStatus,
  literacy,

  /// Only when literate.
  educationLevel,
  certifiedByDoctor,
  causeOfDeath,
  registrationState,
  registrationLga,
  registrationCenter;

  bool get isOptional => this == middleName || this == literacy;

  bool get isResidence =>
      this == state || this == lga || this == address || this == settlement;

  bool get isOrigin =>
      this == stateOfOrigin || this == lgaOfOrigin || this == ethnicGroup;

  /// Names come from the NIN record once it is verified.
  bool get isFromNin => this == surname || this == firstName;

  List<DeceasedField> get dependents => switch (this) {
    nin => const [noNinReason, surname, firstName],
    country => const [state, lga, address, settlement],
    state => const [lga],
    nationality => const [stateOfOrigin, lgaOfOrigin, ethnicGroup],
    stateOfOrigin => const [lgaOfOrigin],
    literacy => const [educationLevel],
    registrationState => const [registrationLga, registrationCenter],
    registrationLga => const [registrationCenter],
    _ => const [],
  };
}

final class DeceasedParticulars extends Equatable {
  const DeceasedParticulars([
    this.values = const FieldValues(),
    this.verifiedNin,
  ]);

  factory DeceasedParticulars.fromJson(Object? json) => DeceasedParticulars(
    FieldValues.fromJson(json, DeceasedField.values),
    json is Map<String, Object?> ? json['verifiedNin'] as String? : null,
  );

  /// The earliest date of death accepted.
  static final earliestDeath = DateTime(1992, 1, 2);
  static const maxAge = 150;

  final FieldValues<DeceasedField> values;

  /// The NIN the identity service confirmed, if any.
  final String? verifiedNin;

  String? operator [](DeceasedField field) => values[field];

  bool get hasNin => values[DeceasedField.nin] != null;

  bool get ninVerified => hasNin && verifiedNin == values[DeceasedField.nin];

  DateTime? get dateOfDeath =>
      DateTime.tryParse(values[DeceasedField.dateOfDeath] ?? '');

  /// Any change to the NIN drops its verification and the names it gave.
  DeceasedParticulars set(DeceasedField field, String? value) =>
      DeceasedParticulars(
        values.set(field, value, dependents: field.dependents),
        field == DeceasedField.nin ? null : verifiedNin,
      );

  /// The identity service confirmed the NIN: its names fill the form.
  DeceasedParticulars verified({
    required String nin,
    required String surname,
    required String firstName,
  }) => DeceasedParticulars(
    values
        .set(DeceasedField.surname, surname)
        .set(DeceasedField.firstName, firstName),
    nin,
  );

  bool applies(DeceasedField field) => switch (field) {
    DeceasedField.noNinReason => !hasNin,
    _ when field.isResidence =>
      values[DeceasedField.country] == DeathCodes.nigeria,
    _ when field.isOrigin =>
      values[DeceasedField.nationality] == DeathCodes.nigeria,
    DeceasedField.educationLevel =>
      values[DeceasedField.literacy] == DeathCodes.literate,
    _ => true,
  };

  DeathFieldError? errorOf(DeceasedField field, {required DateTime today}) {
    if (!applies(field)) return null;
    final value = values[field];
    if (field == DeceasedField.nin) {
      return _ninError(value, verified: ninVerified);
    }
    if (value == null) {
      return field.isOptional ? null : DeathFieldError.required;
    }
    switch (field) {
      case DeceasedField.ageAtDeath:
        final age = int.tryParse(value);
        return age == null || age > maxAge ? DeathFieldError.invalidAge : null;
      case DeceasedField.dateOfDeath:
        final date = dateOfDeath;
        if (date == null) return DeathFieldError.required;
        if (date.isAfter(today)) return DeathFieldError.futureDate;
        if (date.isBefore(earliestDeath)) return DeathFieldError.tooEarly;
        return null;
      case _:
        return null;
    }
  }

  bool isComplete({required DateTime today}) => DeceasedField.values.every(
    (field) => errorOf(field, today: today) == null,
  );

  Map<String, Object?> toJson() => {
    ...values.toJson(),
    'verifiedNin': verifiedNin,
  };

  @override
  List<Object?> get props => [values, verifiedNin];
}

// ---- Step 2: Particulars of Informant --------------------------------------

enum InformantField {
  /// Taken from the NIN record when it is verified.
  surname,
  firstName,
  middleName,
  relationship,

  /// "Is it the same as Deceased?" — yes copies the deceased's residence.
  sameAddress,
  country,

  /// These four only for a residence in Nigeria.
  state,
  lga,
  address,
  settlement,
  phone,
  nin;

  bool get isResidence =>
      this == state || this == lga || this == address || this == settlement;

  bool get isFromNin => this == surname || this == firstName;

  List<InformantField> get dependents => switch (this) {
    nin => const [surname, firstName],
    country => const [state, lga, address, settlement],
    state => const [lga],
    _ => const [],
  };
}

final class InformantParticulars extends Equatable {
  const InformantParticulars([
    this.values = const FieldValues(),
    this.verifiedNin,
  ]);

  factory InformantParticulars.fromJson(Object? json) => InformantParticulars(
    FieldValues.fromJson(json, InformantField.values),
    json is Map<String, Object?> ? json['verifiedNin'] as String? : null,
  );

  static final _phone = RegExp(r'^\d{11}$');

  final FieldValues<InformantField> values;
  final String? verifiedNin;

  String? operator [](InformantField field) => values[field];

  bool get ninVerified =>
      values[InformantField.nin] != null &&
      verifiedNin == values[InformantField.nin];

  InformantParticulars set(InformantField field, String? value) =>
      InformantParticulars(
        values.set(field, value, dependents: field.dependents),
        field == InformantField.nin ? null : verifiedNin,
      );

  InformantParticulars verified({
    required String nin,
    required String surname,
    required String firstName,
  }) => InformantParticulars(
    values
        .set(InformantField.surname, surname)
        .set(InformantField.firstName, firstName),
    nin,
  );

  /// "Yes" to "Is it the same as Deceased?": the deceased's residence.
  InformantParticulars withAddressOf(DeceasedParticulars deceased) {
    var next = values;
    for (final (field, from) in [
      (InformantField.country, DeceasedField.country),
      (InformantField.state, DeceasedField.state),
      (InformantField.lga, DeceasedField.lga),
      (InformantField.address, DeceasedField.address),
      (InformantField.settlement, DeceasedField.settlement),
    ]) {
      // Not through [set]: a country or state would clear what follows.
      next = next.set(field, deceased[from]);
    }
    return InformantParticulars(next, verifiedNin);
  }

  bool applies(InformantField field) =>
      !field.isResidence ||
      values[InformantField.country] == DeathCodes.nigeria;

  // The informant's NIN is required (and verified).
  DeathFieldError? errorOf(InformantField field) {
    if (!applies(field)) return null;
    final value = values[field];
    if (value == null) {
      return field == InformantField.middleName
          ? null
          : DeathFieldError.required;
    }
    return switch (field) {
      InformantField.nin => _ninError(value, verified: ninVerified),
      InformantField.phone =>
        _phone.hasMatch(value) ? null : DeathFieldError.invalidPhone,
      _ => null,
    };
  }

  bool get isComplete =>
      InformantField.values.every((field) => errorOf(field) == null);

  Map<String, Object?> toJson() => {
    ...values.toJson(),
    'verifiedNin': verifiedNin,
  };

  @override
  List<Object?> get props => [values, verifiedNin];
}

// ---- Step 3: Upload Documents ----------------------------------------------

/// In the design's order, with the API's document types.
enum DeathDocument {
  policeReport('police-report'),
  nextOfKinLetter('next-of-kin'),
  employersReport('employer-report'),
  affidavit('affidavit'),
  medicalProofOfDeath('medical-proof-of-death');

  const DeathDocument(this.apiType);

  /// `SupportingDocument[].type`.
  final String apiType;

  /// Next-of-kin letter and affidavit always; police report unless in
  /// hospital, medical proof only then; employer's report optional.
  bool isRequired({required String? placeOfDeath}) => switch (this) {
    nextOfKinLetter || affidavit => true,
    policeReport => placeOfDeath != DeathCodes.hospital,
    medicalProofOfDeath => placeOfDeath == DeathCodes.hospital,
    employersReport => false,
  };
}

/// JPEG/PNG up to 5 MB, as the other modules' uploads.
final class DeathDocuments extends Equatable {
  const DeathDocuments([this.files = const {}]);

  factory DeathDocuments.fromJson(Object? json) => DeathDocuments({
    if (json is Map<String, Object?>)
      for (final document in DeathDocument.values)
        document: ?AttachedFile.fromJson(json[document.name]),
  });

  final Map<DeathDocument, AttachedFile> files;

  AttachedFile? operator [](DeathDocument document) => files[document];

  DeathDocuments set(DeathDocument document, AttachedFile? file) {
    final next = Map<DeathDocument, AttachedFile>.of(files);
    if (file == null) {
      next.remove(document);
    } else {
      next[document] = file;
    }
    return DeathDocuments(next);
  }

  bool isComplete({required String? placeOfDeath}) => DeathDocument.values
      .where((d) => d.isRequired(placeOfDeath: placeOfDeath))
      .every((d) => files[d] != null);

  Map<String, Object?> toJson() => {
    for (final MapEntry(:key, :value) in files.entries)
      key.name: value.toJson(),
  };

  @override
  List<Object?> get props => [files];
}
