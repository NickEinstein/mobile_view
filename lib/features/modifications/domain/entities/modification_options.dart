// What can be corrected, and why, for each kind of record; each
// `apiValue` is what the API expects for it.

/// The kind of record being corrected.
enum ModificationKind {
  birth('birth-registration', 'birth_modification_payment', 'birth'),
  attestation(
    'birth-attestation',
    'attest_modification_payment',
    'attestation',
  ),
  death('death-registration', 'death_modification_payment', 'death');

  const ModificationKind(this.apiPath, this.paymentType, this._paidFor);

  /// Path segment under `/modification/`.
  final String apiPath;

  /// The backend's transaction type for this kind's fee (a date of birth
  /// change has its own, see `ModificationRequest.paymentType`).
  final String paymentType;
  final String _paidFor;

  /// Shown on the gateway's checkout.
  String get paymentDescription => 'payment for $_paidFor modification';

  List<ModificationType> get types => [
    for (final type in ModificationType.values)
      if (type.kind == this) type,
  ];
}

/// Why a field is being corrected.
enum ModificationReason {
  incorrectAge('incorrect age entered'),
  misspelledName('misspelling of name'),
  switchedNameOrder('switching of name order'),
  changeOfSex('change of sex'),
  incorrectPlaceOfBirth('Incorrect Place of Birth'),
  wrongStateOfBirth('incorrect place of birth'),
  incorrectStateOfOrigin('incorrect state of origin'),
  // Spelled.
  incorrectAgeAtDeath('incorrect age at entered'),
  incorrectDateOfDeath('incorrect date of death');

  const ModificationReason(this.apiValue);

  final String apiValue;
}

const _nameReasons = [
  ModificationReason.misspelledName,
  ModificationReason.switchedNameOrder,
];

/// One field of a "Particulars of …" type.
enum ModificationField {
  childName('child_name', _nameReasons),
  childDateOfBirth('applicant_dob', [ModificationReason.incorrectAge]),
  childSex('child_sex', [ModificationReason.changeOfSex]),
  childPlaceOfBirth('child_place_of_birth', [
    ModificationReason.incorrectPlaceOfBirth,
  ]),
  applicantName('applicant_name', _nameReasons),
  applicantSex('applicant_sex', [ModificationReason.changeOfSex]),
  applicantDateOfBirth('applicant_dob', [ModificationReason.incorrectAge]),
  applicantPlaceOfBirth('applicant_place_of_birth', [
    ModificationReason.wrongStateOfBirth,
  ]),
  applicantStateOfOrigin('applicant_state_of_origin', [
    ModificationReason.incorrectStateOfOrigin,
  ]);

  const ModificationField(this.apiValue, this.reasons);

  final String apiValue;
  final List<ModificationReason> reasons;

  /// A date of birth change needs supporting documents and has its own fee.
  bool get isDateOfBirth =>
      this == childDateOfBirth || this == applicantDateOfBirth;
}

/// "Modification Type". Types with [fields] ask which field to edit next;
/// the others are a single change with their own [reasons].
enum ModificationType {
  childParticulars(
    ModificationKind.birth,
    'child particulars',
    fields: [
      ModificationField.childName,
      ModificationField.childDateOfBirth,
      ModificationField.childSex,
      ModificationField.childPlaceOfBirth,
    ],
  ),
  motherName(ModificationKind.birth, 'mother_name', reasons: _nameReasons),
  fatherName(ModificationKind.birth, 'father_name', reasons: _nameReasons),
  applicantParticulars(
    ModificationKind.attestation,
    'particulars_of_applicant',
    fields: [
      ModificationField.applicantName,
      ModificationField.applicantSex,
      ModificationField.applicantDateOfBirth,
      ModificationField.applicantPlaceOfBirth,
      ModificationField.applicantStateOfOrigin,
    ],
  ),
  applicantMotherName(
    ModificationKind.attestation,
    'mother_name',
    reasons: _nameReasons,
  ),
  applicantFatherName(
    ModificationKind.attestation,
    'father_name',
    reasons: _nameReasons,
  ),
  deceasedName(ModificationKind.death, 'deceased_name', reasons: _nameReasons),
  deceasedSex(
    ModificationKind.death,
    'deceased_sex',
    reasons: [ModificationReason.changeOfSex],
  ),
  deceasedAgeAtDeath(
    ModificationKind.death,
    'deceased_age_at_death',
    reasons: [ModificationReason.incorrectAgeAtDeath],
  ),
  deceasedDateOfDeath(
    ModificationKind.death,
    'deceased_date_of_death',
    reasons: [ModificationReason.incorrectDateOfDeath],
  );

  const ModificationType(
    this.kind,
    this.apiValue, {
    this.fields = const [],
    this.reasons = const [],
  });

  final ModificationKind kind;
  final String apiValue;
  final List<ModificationField> fields;
  final List<ModificationReason> reasons;
}
