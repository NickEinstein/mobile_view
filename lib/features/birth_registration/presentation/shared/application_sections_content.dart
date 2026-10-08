part of 'application_sections.dart';

/// What each review card lists, in the order the steps asked for it.
/// Option ids are shown as their labels; hidden answers are left out.
class _ReviewContent {
  const _ReviewContent({
    required this.l10n,
    required this.data,
    required this.locale,
  });

  final AppLocalizations l10n;
  final ReferenceData data;
  final String locale;

  static String _show(String? value) => value ?? '–';

  static String _labelOf(List<Option> options, String? id) {
    if (id == null) return '–';
    for (final option in options) {
      if (option.id == id) return option.label;
    }
    return id;
  }

  List<Widget> child(ChildParticulars c, String? childNin) {
    final dob = c.dateOfBirth;
    return [
      if (childNin != null) _Entry(l10n.brChildNin, childNin),
      _Entry(l10n.brSurname, _show(c[ChildField.surname])),
      _Entry(l10n.brFirstName, _show(c[ChildField.firstName])),
      _Entry(l10n.brMiddleName, _show(c[ChildField.middleName])),
      _Entry(
        l10n.brDateOfBirth,
        dob == null ? '–' : DateFormat.yMMMMd(locale).format(dob),
      ),
      const _Group(),
      _Entry(
        l10n.brTypeOfBirth,
        _labelOf(data.typesOfBirth, c[ChildField.typeOfBirth]),
      ),
      _Entry(
        l10n.brBirthOrder,
        _labelOf(data.birthOrders, c[ChildField.birthOrder]),
      ),
      _Entry(l10n.brSex, _labelOf(data.sexes, c[ChildField.sex])),
      _Entry(
        l10n.brPlaceOfOccurrence,
        _labelOf(data.placesOfOccurrence, c[ChildField.placeOfOccurrence]),
      ),
      const _Group(),
      _Entry(
        l10n.brStateOfBirth,
        _labelOf(data.stateOptions, c[ChildField.stateOfBirth]),
      ),
      _Entry(
        l10n.brLgaOfBirth,
        _labelOf(
          data.lgasOf(c[ChildField.stateOfBirth]),
          c[ChildField.lgaOfBirth],
        ),
      ),
      _Entry(l10n.brLocalityOfBirth, _show(c[ChildField.localityOfBirth])),
      _Entry(
        l10n.brStateOfOrigin,
        _labelOf(data.stateOptions, c[ChildField.stateOfOrigin]),
      ),
      _Entry(
        l10n.brLgaOfOrigin,
        _labelOf(
          data.lgasOf(c[ChildField.stateOfOrigin]),
          c[ChildField.lgaOfOrigin],
        ),
      ),
      _Entry(l10n.brTownOfOrigin, _show(c[ChildField.townOfOrigin])),
      const _Group(),
      _Entry(
        l10n.brRegistrationState,
        _labelOf(data.stateOptions, c[ChildField.registrationState]),
      ),
      _Entry(
        l10n.brRegistrationLga,
        _labelOf(
          data.lgasOf(c[ChildField.registrationState]),
          c[ChildField.registrationLga],
        ),
      ),
      _Entry(
        l10n.brRegistrationCenter,
        _labelOf(
          data.centersOf(
            c[ChildField.registrationState],
            c[ChildField.registrationLga],
          ),
          c[ChildField.registrationCenter],
        ),
      ),
      _Entry(
        l10n.brLocalityType,
        _labelOf(data.localityTypes, c[ChildField.localityType]),
      ),
      _Status(l10n.brCaptureFace, provided: c[ChildField.facePhoto] != null),
    ];
  }

  List<Widget> parent(ParentParticulars p, ParentRole role) {
    bool shown(ParentField field) => p.applies(field, role);
    final isMother = role == ParentRole.mother;
    return [
      _Entry(l10n.brNin, _show(p[ParentField.nin])),
      _Entry(l10n.brSurname, _show(p[ParentField.surname])),
      _Entry(l10n.brFirstName, _show(p[ParentField.firstName])),
      if (shown(ParentField.maidenName))
        _Entry(l10n.brMaidenName, _show(p[ParentField.maidenName])),
      _Entry(l10n.brMiddleName, _show(p[ParentField.middleName])),
      _Entry(l10n.brPhoneNumber, _show(p[ParentField.phone])),
      _Subheading(l10n.brResidenceHeading),
      if (p.livesWithMother(role))
        _Entry(l10n.brPlaceOfResidence, l10n.brSameAsMothers)
      else ...[
        _Entry(
          l10n.brCountry,
          _labelOf(data.countries, p[ParentField.country]),
        ),
        if (shown(ParentField.state))
          _Entry(
            l10n.brState,
            _labelOf(data.stateOptions, p[ParentField.state]),
          ),
        if (shown(ParentField.lga))
          _Entry(
            l10n.brLga,
            _labelOf(data.lgasOf(p[ParentField.state]), p[ParentField.lga]),
          ),
        _Entry(l10n.brAddress, _show(p[ParentField.address])),
        _Entry(
          isMother ? l10n.brLocalityType : l10n.brPlaceOfSettlement,
          _labelOf(data.localityTypes, p[ParentField.settlement]),
        ),
      ],
      const _Group(),
      _Entry(
        isMother ? l10n.brAgeOfMother : l10n.brAgeOfFather,
        _show(p[ParentField.age]),
      ),
      _Entry(
        l10n.brMaritalStatus,
        _labelOf(data.maritalStatuses, p[ParentField.maritalStatus]),
      ),
      _Entry(
        l10n.brNationality,
        _labelOf(data.nationalityOptions, p[ParentField.nationality]),
      ),
      if (shown(ParentField.stateOfOrigin))
        _Entry(
          l10n.brStateOfOrigin,
          _labelOf(data.stateOptions, p[ParentField.stateOfOrigin]),
        ),
      if (shown(ParentField.lgaOfOrigin))
        _Entry(
          l10n.brLgaOfOrigin,
          _labelOf(
            data.lgasOf(p[ParentField.stateOfOrigin]),
            p[ParentField.lgaOfOrigin],
          ),
        ),
      if (shown(ParentField.ethnicGroup))
        _Entry(
          l10n.brEthnicGroup,
          _labelOf(data.ethnicGroups, p[ParentField.ethnicGroup]),
        ),
      _Entry(
        l10n.brLiteracy,
        _labelOf(data.literacyLevels, p[ParentField.literacy]),
      ),
      if (shown(ParentField.educationLevel))
        _Entry(
          l10n.brEducationLevel,
          _labelOf(data.educationLevels, p[ParentField.educationLevel]),
        ),
      _Entry(
        l10n.brOccupation,
        _labelOf(data.occupations, p[ParentField.occupation]),
      ),
    ];
  }

  List<Widget> informant(InformantParticulars i) => [
    _Entry(
      l10n.brRelationship,
      _labelOf(data.relationships, i[InformantField.relationship]),
    ),
    _Entry(l10n.brSurname, _show(i[InformantField.surname])),
    _Entry(l10n.brFirstName, _show(i[InformantField.firstName])),
    _Entry(l10n.brMiddleName, _show(i[InformantField.middleName])),
    _Subheading(l10n.brResidenceHeading),
    if (i.livesWithMother)
      _Entry(l10n.brPlaceOfResidence, l10n.brSameAsMothers)
    else ...[
      _Entry(
        l10n.brCountry,
        _labelOf(data.countries, i[InformantField.country]),
      ),
      if (i.applies(InformantField.state))
        _Entry(
          l10n.brState,
          _labelOf(data.stateOptions, i[InformantField.state]),
        ),
      if (i.applies(InformantField.lga))
        _Entry(
          l10n.brLga,
          _labelOf(data.lgasOf(i[InformantField.state]), i[InformantField.lga]),
        ),
      _Entry(l10n.brAddress, _show(i[InformantField.address])),
      _Entry(
        l10n.brSettlement,
        _labelOf(data.localityTypes, i[InformantField.settlement]),
      ),
    ],
    const _Group(),
    _Entry(l10n.brPhoneNumber, _show(i[InformantField.phone])),
    _Entry(l10n.brNin, _show(i[InformantField.nin])),
    _Entry(l10n.brTrackingId, _show(i[InformantField.trackingId])),
    switch (i.identityMode) {
      IdentityMode.signature => _Status(
        l10n.brInformantSignature,
        provided: i[InformantField.signature] != null,
      ),
      IdentityMode.face => _Status(
        l10n.brInformantFace,
        provided: i[InformantField.facePhoto] != null,
      ),
    },
  ];

  List<Widget> documents(SupportingDocuments documents) => [
    for (final type in DocumentType.values)
      // Passports are asked of foreign parents only.
      if (!type.isPassport || documents[type] != null)
        _Status(
          type.label(l10n),
          provided: documents[type] != null,
          detail: documents[type]?.name,
        ),
  ];
}
