import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

// The attestation form, with the registry's fields and rules.

/// The form's steps, in order.
enum AttestationStep {
  applicant,
  additional,
  parents,
  review;

  static const count = 4;
  int get number => index + 1;
}

enum AttestationFieldError {
  required,
  invalidEmail,
  invalidPhone,
  futureDate,

  /// Attestation is for adults (18+).
  underAge,

  /// More than five years from the date of birth on the NIN record.
  farFromNinDate,
}

/// A section's text values (text, option ids, ISO dates), keyed by field.
final class FieldValues<F extends Enum> extends Equatable {
  const FieldValues([this.values = const {}]);

  /// Reads what [toJson] wrote; unknown keys and non-text values are
  /// dropped.
  factory FieldValues.fromJson(Object? json, List<F> fields) => FieldValues({
    if (json is Map<String, Object?>)
      for (final field in fields)
        if (json[field.name] case final String value) field: value,
  });

  final Map<F, String> values;

  String? operator [](F field) => values[field];

  /// Sets [field] (blank clears it) and clears [dependents], whose options
  /// depended on it.
  FieldValues<F> set(F field, String? value, {List<F> dependents = const []}) {
    final next = Map<F, String>.of(values);
    if (value == null || value.trim().isEmpty) {
      next.remove(field);
    } else {
      next[field] = value;
    }
    for (final dependent in dependents) {
      next.remove(dependent);
    }
    return FieldValues(next);
  }

  Map<String, Object?> toJson() => {
    for (final MapEntry(:key, :value) in values.entries) key.name: value,
  };

  @override
  List<Object?> get props => [values];
}

// ---- Step 1: Particulars of Applicant ------------------------------------

enum ApplicantField {
  surname,
  firstName,
  middleName,
  sex,
  dateOfBirth,
  maritalStatus,
  stateOfOrigin,
  lgaOfOrigin,
  townOfOrigin,
  idType,
  idNumber,
  email,
  phone;

  bool get isOptional => this == middleName || this == phone;

  List<ApplicantField> get dependents =>
      this == stateOfOrigin ? const [lgaOfOrigin] : const [];
}

final class ApplicantParticulars extends Equatable {
  const ApplicantParticulars([this.values = const FieldValues()]);

  factory ApplicantParticulars.fromJson(Object? json) =>
      ApplicantParticulars(FieldValues.fromJson(json, ApplicantField.values));

  static const minAgeYears = ApplicantNinRecord.minAgeYears;

  /// How far the date of birth may move from the NIN's.
  static const maxYearsFromNinDate = 5;
  static final _phone = RegExp(r'^0\d{10}$');

  final FieldValues<ApplicantField> values;

  String? operator [](ApplicantField field) => values[field];

  DateTime? get dateOfBirth =>
      DateTime.tryParse(values[ApplicantField.dateOfBirth] ?? '');

  ApplicantParticulars set(ApplicantField field, String? value) =>
      ApplicantParticulars(
        values.set(field, value, dependents: field.dependents),
      );

  AttestationFieldError? errorOf(
    ApplicantField field, {
    required DateTime today,
    ApplicantNinRecord? nin,
  }) {
    final value = values[field];
    if (value == null) {
      return field.isOptional ? null : AttestationFieldError.required;
    }
    switch (field) {
      case ApplicantField.email:
        return Email.dirty(value).isValid
            ? null
            : AttestationFieldError.invalidEmail;
      case ApplicantField.phone:
        return _phone.hasMatch(value)
            ? null
            : AttestationFieldError.invalidPhone;
      case ApplicantField.dateOfBirth:
        final dob = dateOfBirth;
        if (dob == null) return AttestationFieldError.required;
        if (dob.isAfter(today)) return AttestationFieldError.futureDate;
        final adultOn = DateTime(dob.year + minAgeYears, dob.month, dob.day);
        if (today.isBefore(adultOn)) return AttestationFieldError.underAge;
        if (nin != null &&
            dob.difference(nin.dateOfBirth).inDays.abs() >
                maxYearsFromNinDate * 365.25) {
          return AttestationFieldError.farFromNinDate;
        }
        return null;
      case _:
        return null;
    }
  }

  bool isComplete({required DateTime today, ApplicantNinRecord? nin}) =>
      ApplicantField.values.every(
        (field) => errorOf(field, today: today, nin: nin) == null,
      );

  @override
  List<Object?> get props => [values];
}

// ---- Step 2: Additional Information ---------------------------------------

enum AdditionalField {
  placeOfBirth,
  stateOfBirth,
  lgaOfBirth,
  localityOfBirth,
  registrationState,
  registrationLga,
  registrationCenter,
  currentAddress,
  educationLevel,
  occupation,
  workAddress,
  requestReason,
  requiredFor,

  /// Only when [requiredFor] is abroad.
  requiredForCountry,
  requesterAddress;

  List<AdditionalField> get dependents => switch (this) {
    stateOfBirth => const [lgaOfBirth],
    registrationState => const [registrationLga, registrationCenter],
    registrationLga => const [registrationCenter],
    requiredFor => const [requiredForCountry],
    _ => const [],
  };
}

final class AdditionalInformation extends Equatable {
  const AdditionalInformation([this.values = const FieldValues()]);

  factory AdditionalInformation.fromJson(Object? json) =>
      AdditionalInformation(FieldValues.fromJson(json, AdditionalField.values));

  /// "As a Requirement for" choices that ask for the country.
  static const abroadRequirements = {
    'job abroad',
    'school abroad',
    'resident permit abroad',
  };

  final FieldValues<AdditionalField> values;

  String? operator [](AdditionalField field) => values[field];

  AdditionalInformation set(AdditionalField field, String? value) =>
      AdditionalInformation(
        values.set(field, value, dependents: field.dependents),
      );

  /// Where the application is registered (not part of a correction).
  static const registrationFields = {
    AdditionalField.registrationState,
    AdditionalField.registrationLga,
    AdditionalField.registrationCenter,
  };

  bool applies(AdditionalField field, {bool correction = false}) =>
      !(correction && registrationFields.contains(field)) &&
      (field != AdditionalField.requiredForCountry ||
          abroadRequirements.contains(values[AdditionalField.requiredFor]));

  AttestationFieldError? errorOf(
    AdditionalField field, {
    bool correction = false,
  }) => applies(field, correction: correction) && values[field] == null
      ? AttestationFieldError.required
      : null;

  /// The court affidavit is required too; see [AttestationDocuments].
  bool isComplete({bool correction = false}) => AdditionalField.values.every(
    (field) => errorOf(field, correction: correction) == null,
  );

  @override
  List<Object?> get props => [values];
}

// ---- Step 3: Parent's Information -----------------------------------------

enum Parent { mother, father }

enum ParentInfoField {
  surname,
  firstName,

  /// The mother's only.
  maidenName,
  nationality,

  /// These three only for a Nigerian parent; others give a passport.
  stateOfOrigin,
  lgaOfOrigin,
  town;

  List<ParentInfoField> get dependents => switch (this) {
    nationality => const [stateOfOrigin, lgaOfOrigin, town],
    stateOfOrigin => const [lgaOfOrigin],
    _ => const [],
  };
}

final class ParentInformation extends Equatable {
  const ParentInformation([this.values = const FieldValues()]);

  factory ParentInformation.fromJson(Object? json) =>
      ParentInformation(FieldValues.fromJson(json, ParentInfoField.values));

  /// Nigeria's `Country_Code`.
  static const nigeria = ReferenceData.nigeria;

  final FieldValues<ParentInfoField> values;

  String? operator [](ParentInfoField field) => values[field];

  /// Null until the nationality is chosen.
  bool? get isNigerian => switch (values[ParentInfoField.nationality]) {
    null => null,
    final id => id == nigeria,
  };

  /// A parent of another nationality gives their passport instead of a
  /// state and LGA of origin.
  bool get needsPassport => isNigerian == false;

  ParentInformation set(ParentInfoField field, String? value) =>
      ParentInformation(values.set(field, value, dependents: field.dependents));

  bool applies(ParentInfoField field, Parent parent) => switch (field) {
    ParentInfoField.maidenName => parent == Parent.mother,
    ParentInfoField.stateOfOrigin ||
    ParentInfoField.lgaOfOrigin ||
    ParentInfoField.town => isNigerian ?? true,
    _ => true,
  };

  AttestationFieldError? errorOf(ParentInfoField field, Parent parent) =>
      applies(field, parent) && values[field] == null
      ? AttestationFieldError.required
      : null;

  /// A passport, when [needsPassport], is checked with the documents.
  bool isComplete(Parent parent) =>
      ParentInfoField.values.every((field) => errorOf(field, parent) == null);

  @override
  List<Object?> get props => [values];
}

// ---- Documents --------------------------------------------------------------

enum AttestationDocument { affidavit, motherPassport, fatherPassport }

extension AttestationParentPassport on Parent {
  AttestationDocument get passport => switch (this) {
    Parent.mother => AttestationDocument.motherPassport,
    Parent.father => AttestationDocument.fatherPassport,
  };
}

/// The court affidavit (step 2) and any foreign parent's passport (step 3).
/// JPEG/PNG up to 5 MB, as Birth Registration's uploads.
final class AttestationDocuments extends Equatable {
  const AttestationDocuments([this.files = const {}]);

  factory AttestationDocuments.fromJson(Object? json) => AttestationDocuments({
    if (json is Map<String, Object?>)
      for (final document in AttestationDocument.values)
        document: ?AttachedFile.fromJson(json[document.name]),
  });

  final Map<AttestationDocument, AttachedFile> files;

  AttachedFile? operator [](AttestationDocument document) => files[document];

  AttestationDocuments set(AttestationDocument document, AttachedFile? file) {
    final next = Map<AttestationDocument, AttachedFile>.of(files);
    if (file == null) {
      next.remove(document);
    } else {
      next[document] = file;
    }
    return AttestationDocuments(next);
  }

  Map<String, Object?> toJson() => {
    for (final MapEntry(:key, :value) in files.entries)
      key.name: value.toJson(),
  };

  @override
  List<Object?> get props => [files];
}
