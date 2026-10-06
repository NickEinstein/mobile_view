import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';

// The attestation reissuance form, with the API's types.

/// The form's steps, in order.
enum AttestationReissuanceStep {
  applicant,
  additional,
  parents,
  documents,
  review;

  static const count = 5;
  int get number => index + 1;
}

/// An attestation is for adults; children's births are reissued as birth
/// certificates.
const minApplicantAge = 18;

// ---- Step 1: Particulars of Applicant ------------------------------------

enum ApplicantDetail {
  surname,
  firstName,
  middleName,
  sex,
  dateOfBirth,
  maritalStatus,
  stateOfOrigin,
  lgaOfOrigin,

  /// "Town/Village of Origin".
  town,

  /// "Mode of Identification" and its number.
  idType,
  idNumber,
  email,
  phone;

  List<ApplicantDetail> get dependents =>
      this == stateOfOrigin ? const [lgaOfOrigin] : const [];
}

final class ApplicantParticulars extends Equatable {
  const ApplicantParticulars([this.values = const FieldValues()]);

  factory ApplicantParticulars.fromJson(Object? json) =>
      ApplicantParticulars(FieldValues.fromJson(json, ApplicantDetail.values));

  static final _phonePattern = RegExp(r'^\d{11,15}$');

  final FieldValues<ApplicantDetail> values;

  String? operator [](ApplicantDetail field) => values[field];

  DateTime? get dateOfBirth =>
      DateTime.tryParse(values[ApplicantDetail.dateOfBirth] ?? '');

  ApplicantParticulars set(ApplicantDetail field, String? value) =>
      ApplicantParticulars(
        values.set(field, value, dependents: field.dependents),
      );

  /// Born by the e-CRVS commission date, and 18 or older
  /// [today].
  ReissuanceFieldError? errorOf(
    ApplicantDetail field, {
    required DateTime today,
  }) {
    final value = values[field];
    if (value == null) {
      return field == ApplicantDetail.middleName
          ? null
          : ReissuanceFieldError.required;
    }
    switch (field) {
      case ApplicantDetail.dateOfBirth:
        final born = dateOfBirth;
        if (born == null) return ReissuanceFieldError.required;
        if (born.isAfter(ReissuanceCodes.latestBirthDate)) {
          return ReissuanceFieldError.tooLate;
        }
        final adultOn = DateTime(
          born.year + minApplicantAge,
          born.month,
          born.day,
        );
        return today.isBefore(adultOn) ? ReissuanceFieldError.underAge : null;
      case ApplicantDetail.email:
        return Email.dirty(value).isValid
            ? null
            : ReissuanceFieldError.invalidEmail;
      case ApplicantDetail.phone:
        return _phonePattern.hasMatch(value)
            ? null
            : ReissuanceFieldError.invalidPhone;
      case _:
        return null;
    }
  }

  bool isComplete({required DateTime today}) => ApplicantDetail.values.every(
    (field) => errorOf(field, today: today) == null,
  );

  @override
  List<Object?> get props => [values];
}

// ---- Step 2: Additional Information ---------------------------------------

enum AdditionalDetail {
  placeOfBirth,
  typeOfBirth,
  stateOfBirth,
  lgaOfBirth,

  /// "Locality of Birth (Town/LGA of Birth)"; optional.
  townOfBirth,
  registrationState,
  registrationLga,
  registrationCenter,
  currentAddress,
  educationLevel,
  occupation,
  workAddress,
  requestReason,

  /// "As a Requirement for", as text values.
  requiredFor,

  /// Only when [requiredFor] is abroad.
  country,

  /// The company, school, embassy… that asked for the document.
  requesterAddress;

  List<AdditionalDetail> get dependents => switch (this) {
    stateOfBirth => const [lgaOfBirth],
    registrationState => const [registrationLga, registrationCenter],
    registrationLga => const [registrationCenter],
    requiredFor => const [country],
    _ => const [],
  };
}

final class AdditionalInformation extends Equatable {
  const AdditionalInformation([this.values = const FieldValues()]);

  factory AdditionalInformation.fromJson(Object? json) => AdditionalInformation(
    FieldValues.fromJson(json, AdditionalDetail.values),
  );

  /// "As a Requirement for" values that ask for the country.
  static const abroad = {
    'job abroad',
    'school abroad',
    'resident permit abroad',
  };

  final FieldValues<AdditionalDetail> values;

  String? operator [](AdditionalDetail field) => values[field];

  AdditionalInformation set(AdditionalDetail field, String? value) =>
      AdditionalInformation(
        values.set(field, value, dependents: field.dependents),
      );

  bool applies(AdditionalDetail field) =>
      field != AdditionalDetail.country ||
      abroad.contains(values[AdditionalDetail.requiredFor]);

  ReissuanceFieldError? errorOf(AdditionalDetail field) =>
      applies(field) &&
          field != AdditionalDetail.townOfBirth &&
          values[field] == null
      ? ReissuanceFieldError.required
      : null;

  bool get isComplete =>
      AdditionalDetail.values.every((field) => errorOf(field) == null);

  @override
  List<Object?> get props => [values];
}

// ---- Step 3: Parent's Information -----------------------------------------

/// Each parent's names and origin; Nigerian states and LGAs only.
enum AttestationParentDetail {
  surname,
  firstName,

  /// The mother's only.
  maidenName,
  state,
  lga,

  /// "Village/Town".
  town;

  List<AttestationParentDetail> get dependents =>
      this == state ? const [lga] : const [];
}

final class AttestationParent extends Equatable {
  const AttestationParent([this.values = const FieldValues()]);

  factory AttestationParent.fromJson(Object? json) => AttestationParent(
    FieldValues.fromJson(json, AttestationParentDetail.values),
  );

  final FieldValues<AttestationParentDetail> values;

  String? operator [](AttestationParentDetail field) => values[field];

  AttestationParent set(AttestationParentDetail field, String? value) =>
      AttestationParent(values.set(field, value, dependents: field.dependents));

  static bool applies(AttestationParentDetail field, ParentRole role) =>
      field != AttestationParentDetail.maidenName || role == ParentRole.mother;

  ReissuanceFieldError? errorOf(
    AttestationParentDetail field,
    ParentRole role,
  ) => applies(field, role) && values[field] == null
      ? ReissuanceFieldError.required
      : null;

  bool isComplete(ParentRole role) => AttestationParentDetail.values.every(
    (field) => errorOf(field, role) == null,
  );

  @override
  List<Object?> get props => [values];
}

// ---- The form ----------------------------------------------------------------

/// The attestation reissuance form in progress. The court affidavit and the
/// applicant's signature are required (step 4).
final class AttestationReissuanceForm extends Equatable {
  const AttestationReissuanceForm({
    this.step = AttestationReissuanceStep.applicant,
    this.applicant = const ApplicantParticulars(),
    this.additional = const AdditionalInformation(),
    this.mother = const AttestationParent(),
    this.father = const AttestationParent(),
    this.affidavit,
    this.signature,
    this.keptAffidavit,
    this.keptSignature,
  });

  factory AttestationReissuanceForm.fromJson(Map<String, Object?> json) {
    final step = json['step'];
    return AttestationReissuanceForm(
      step: step is String
          ? AttestationReissuanceStep.values.asNameMap()[step] ??
                AttestationReissuanceStep.applicant
          : AttestationReissuanceStep.applicant,
      applicant: ApplicantParticulars.fromJson(json['applicant']),
      additional: AdditionalInformation.fromJson(json['additional']),
      mother: AttestationParent.fromJson(json['mother']),
      father: AttestationParent.fromJson(json['father']),
      affidavit: AttachedFile.fromJson(json['affidavit']),
      signature: json['signature'] as String?,
    );
  }

  final AttestationReissuanceStep step;
  final ApplicantParticulars applicant;
  final AdditionalInformation additional;
  final AttestationParent mother;
  final AttestationParent father;

  /// The court affidavit, a photo in private storage.
  final AttachedFile? affidavit;

  /// The applicant's drawn signature (PNG), in private storage.
  final String? signature;

  /// A queried request's affidavit and signature, until replaced. Only in
  /// memory: a correction isn't saved on the device.
  final KeptFile? keptAffidavit;
  final KeptFile? keptSignature;

  AttestationParent parent(ParentRole role) =>
      role == ParentRole.mother ? mother : father;

  bool get hasAffidavit => affidavit != null || keptAffidavit != null;

  bool get hasSignature => signature != null || keptSignature != null;

  /// Every file the form keeps, to delete with it.
  List<String> get files => [?affidavit?.path, ?signature];

  /// The states whose LGAs the answers use (all in Nigeria).
  Set<String> get states => {
    ?applicant[ApplicantDetail.stateOfOrigin],
    ?additional[AdditionalDetail.stateOfBirth],
    ?additional[AdditionalDetail.registrationState],
    ?mother[AttestationParentDetail.state],
    ?father[AttestationParentDetail.state],
  };

  bool isComplete(AttestationReissuanceStep step, {required DateTime today}) =>
      switch (step) {
        AttestationReissuanceStep.applicant => applicant.isComplete(
          today: today,
        ),
        AttestationReissuanceStep.additional => additional.isComplete,
        AttestationReissuanceStep.parents =>
          mother.isComplete(ParentRole.mother) &&
              father.isComplete(ParentRole.father),
        AttestationReissuanceStep.documents => hasAffidavit && hasSignature,
        // Nothing to fill in; complete when everything before it is.
        AttestationReissuanceStep.review =>
          AttestationReissuanceStep.values
              .where((s) => s != AttestationReissuanceStep.review)
              .every((s) => isComplete(s, today: today)),
      };

  AttestationReissuanceForm copyWith({
    AttestationReissuanceStep? step,
    ApplicantParticulars? applicant,
    AdditionalInformation? additional,
    AttestationParent? mother,
    AttestationParent? father,
    AttachedFile? Function()? affidavit,
    String? Function()? signature,
    KeptFile? Function()? keptAffidavit,
    KeptFile? Function()? keptSignature,
  }) => AttestationReissuanceForm(
    step: step ?? this.step,
    applicant: applicant ?? this.applicant,
    additional: additional ?? this.additional,
    mother: mother ?? this.mother,
    father: father ?? this.father,
    affidavit: affidavit != null ? affidavit() : this.affidavit,
    signature: signature != null ? signature() : this.signature,
    keptAffidavit: keptAffidavit != null ? keptAffidavit() : this.keptAffidavit,
    keptSignature: keptSignature != null ? keptSignature() : this.keptSignature,
  );

  Map<String, Object?> toJson() => {
    'step': step.name,
    'applicant': applicant.values.toJson(),
    'additional': additional.values.toJson(),
    'mother': mother.values.toJson(),
    'father': father.values.toJson(),
    'affidavit': affidavit?.toJson(),
    'signature': signature,
  };

  @override
  List<Object?> get props => [
    step,
    applicant,
    additional,
    mother,
    father,
    affidavit,
    signature,
    keptAffidavit,
    keptSignature,
  ];
}
