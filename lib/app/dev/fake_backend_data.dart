part of 'fake_backend_interceptor.dart';

// Sample records and reference data for the demo backend.

/// Birth Registration's `Birth_Reg_ID`s: 1000s pending, 2000s approved,
/// 3000s printed, 4000s queried, one per sample person.
const _birthStatuses = ['pending', 'approved', 'printed', 'queried'];

/// `GET /birth-registration/list?type=…&search=…`, in the backend's shape.
Map<String, Object?> _birthRegistrations(Map<String, dynamic> query) {
  final status = query['type'] as String? ?? 'pending';
  final code = _birthStatuses.indexOf(status);
  final count = const [2, 3, 4, 1][code < 0 ? 0 : code];
  final search = '${query['search'] ?? ''}'.toLowerCase();
  final rows = [
    for (final (i, (name, number, date))
        in FakeBackendInterceptor._people.indexed.take(count))
      if (search.isEmpty ||
          name.toLowerCase().contains(search) ||
          number.toLowerCase().contains(search))
        {
          'Birth_Reg_ID': (code + 1) * 1000 + i,
          'Certificate_No': number,
          'Date_Registerred': '${date}T09:30:00.000Z',
          'initiatedAt': '${date}T09:12:00.000Z',
          'childData': {
            'firstname': name.split(' ').first,
            'surname': name.split(' ').last,
            'middle_name': null,
            'gender': 2,
          },
        },
  ];
  return {
    'result': rows,
    'pagination': {'total': rows.length, 'pages': 1, 'page': 1},
  };
}

/// `GET /birth-registration/{id}`, with ids whose labels resolve.
Map<String, Object?>? _birthRegistration(String id) {
  final regId = int.tryParse(id);
  if (regId == null) return null;
  final code = regId ~/ 1000 - 1;
  final index = regId % 1000;
  const people = FakeBackendInterceptor._people;
  if (code < 0 || code >= _birthStatuses.length || index >= people.length) {
    return null;
  }
  final (name, number, date) = people[index];
  final [firstName, surname] = name.split(' ');
  Map<String, Object?> person(String first, {String? maiden}) => {
    'nin': '56738390302',
    'surname': surname,
    'firstname': first,
    'maiden_name': maiden,
    'middle_name': null,
    'current_residence_country': 63,
    'current_residence_state': 1,
    'current_residence_lga': 11,
    'current_address': 'No 2 Agwada Street',
    'birth_settlement_type': 1,
    'current_marital_status': 1,
    'current_nationality': 63,
    'origin_state': 1,
    'origin_lga': 11,
    'ethnic_group': 3,
    'current_literacy_level': 1,
    'current_education_level': 7,
    'current_occupation': 101,
    'current_phone_number': '08130845852',
  };
  final mother = person('Amina', maiden: 'Bello');
  return {
    'data': {
      'Birth_Reg_ID': regId,
      'Certificate_No': number,
      'Reg_Center': 1510,
      'Birth_type': 1,
      'birth_order': 1,
      'birth_place': 1,
      'locality_of_birth': 2,
      'Date_Registerred': '${date}T09:30:00.000Z',
      'initiatedAt': '${date}T09:12:00.000Z',
      'Approval_Status': switch (_birthStatuses[code]) {
        'approved' || 'printed' => 1,
        'queried' => 2,
        _ => 0,
      },
      'Print_Status': _birthStatuses[code] == 'printed' ? 1 : 0,
      'mother_age_at_birth': 23,
      'father_age_at_birth': 30,
      'ChildFace': 'https://files.example/child-face.jpg',
      // The storage keys behind the viewing URLs, as `single` adds them.
      'rawChildFace': 'demo/BR-CHILD-FACE.jpg',
      'rawSupportingDocument': [
        for (final type in [
          'immunization-card',
          'notification-of-birth',
          'lga-birth-certificate',
          'baptisim-card',
        ])
          {'type': type, 'mimeType': 'image/jpeg', 'file': 'demo/$type.jpg'},
      ],
      'reference': null,
      'SupportingDocument': [
        for (final type in [
          'immunization-card',
          'notification-of-birth',
          'valid-id',
        ])
          {
            'type': type,
            'mimeType': 'image/jpeg',
            'file': type == 'valid-id'
                ? null
                : 'https://files.example/$type.jpg?X-Amz-Expires=900',
          },
      ],
      'Reg_CenterData': {
        'Reg_Center_id': 1510,
        'Reg_Center_Name': 'AMAC Registration Centre',
        'LGAs': {
          'LGA_ID': 151,
          'LGA_Name': 'AMAC',
          'states': {'State_ID': 15, 'State_Name': 'FCT'},
        },
      },
      'Informant_RelationshipData': {
        'Relationship_ID': 2,
        'Description': 'Mother',
      },
      'childData': {
        'nin': null,
        'surname': surname,
        'firstname': firstName,
        'middle_name': null,
        'birth_date': '2025-12-12',
        'gender': 2,
        'birth_state': 1,
        'birth_lga': 11,
        'town_of_birth': 'Ovim',
        'origin_state': 1,
        'origin_lga': 11,
        'town_of_origin': 'Ovim',
        'birth_settlement_type': 2,
      },
      'motherData': mother,
      'fatherData': person('Bolaji'),
      // A parent informant is recorded as that parent.
      'informantData': mother,
    },
    'queried': _birthStatuses[code] == 'queried'
        ? {'reason': 'The birth notification is unreadable.'}
        : null,
  };
}

/// The fields `POST /birth-registration/add` can't do without (see the
/// backend's `ChildRegistration`), so the demo catches what the API would.
List<String> _missingRegistrationFields(Map<String, Object?> body) => [
  for (final key in const [
    'State_Code',
    'LGA_Code',
    'StateID',
    'LGA_of_Birth',
    'Reg_Center',
    'Birth_type',
    'gender',
    'dateInitiated',
    'Mother_Marital_Status',
    'Father_Marital_Status',
    'Informant_firstname',
    'Informant_surname',
    'Informant_Relationship_ID',
    'Informant_Country_of_Residence',
    'informant_signature',
  ])
    if (body[key] == null) key,
  if (body['SupportingDocument'] case final List<Object?> documents
      when documents.isEmpty)
    'SupportingDocument',
];

/// `{result, pagination}`, the surrogacy list's shape, filtered by
/// `status` ("pending", "approved", …).
Map<String, Object?> _surrogacyRegistrations(Map<String, dynamic> query) {
  final status = query['status'] as String? ?? 'pending';
  final (code, count) = switch (status) {
    'approved' => (1, 3),
    'queried' => (2, 1),
    'printed' => (1, 4),
    'drafted' => (3, 1),
    _ => (0, 2),
  };
  final search = (query['search'] as String? ?? '').toLowerCase();
  final rows = [
    for (final (i, (name, _, date))
        in FakeBackendInterceptor._people.indexed.take(count))
      if (search.isEmpty || name.toLowerCase().contains(search))
        {
          'id': 'surrogacy-$status-$i',
          'referenceId': 'SBR-2026-000${4821 + i}',
          'status': code,
          'childSurname': name.split(' ').last,
          'childFirstName': name.split(' ').first,
          'childSex': '${i % 2 + 1}',
          'createdAt': date,
        },
  ];
  return {
    'result': rows,
    'pagination': {'page': 1, 'pages': 1, 'total': rows.length},
  };
}

/// `{result, pagination}`, the adoption list's shape, filtered by
/// `status` ("pending", "approved", …).
Map<String, Object?> _adoptions(Map<String, dynamic> query) {
  final status = query['status'] as String? ?? 'pending';
  final (code, count) = switch (status) {
    'approved' => (1, 2),
    'queried' => (2, 1),
    'printed' => (1, 2),
    'drafted' => (3, 1),
    _ => (0, 3),
  };
  final search = (query['search'] as String? ?? '').toLowerCase();
  final rows = [
    for (final (i, (name, _, date))
        in FakeBackendInterceptor._people.indexed.take(count))
      if (search.isEmpty || name.toLowerCase().contains(search))
        {
          'id': 'adoption-$status-$i',
          'referenceId': 'ACR-2026-000${3150 + i}',
          'status': code,
          'childSurname': name.split(' ').last,
          'childFirstName': name.split(' ').first,
          'childSex': '${i % 2 + 1}',
          'createdAt': date,
        },
  ];
  return {
    'result': rows,
    'pagination': {'page': 1, 'pages': 1, 'total': rows.length},
  };
}

/// A surrogacy application for list id `surrogacy-<status>-<index>` (or a
/// resumed draft's reference id).
Map<String, Object?>? _surrogacyRecord(String id) {
  final match = RegExp(r'^surrogacy-(\w+)-(\d+)$').firstMatch(id);
  final status = match?.group(1) ?? (id.startsWith('SBR-') ? 'drafted' : null);
  final index = int.tryParse(match?.group(2) ?? '0') ?? 0;
  const people = FakeBackendInterceptor._people;
  if (status == null || index >= people.length) return null;
  final code = switch (status) {
    'pending' => 0,
    'approved' || 'printed' => 1,
    'queried' => 2,
    'drafted' => 3,
    _ => null,
  };
  if (code == null) return null;
  final (name, _, date) = people[index];
  final [firstName, surname] = name.split(' ');
  final drafted = code == 3;
  return {
    'id': match == null ? 'surrogacy-drafted-0' : id,
    'referenceId': match == null ? id : 'SBR-2026-000${4821 + index}',
    'status': code,
    'createdAt': date,
    'paymentReference': 'PAIDDEMO',
    'childNinVerified': false,
    if (code == 1) 'surrogacyCertificateNo': 'SC-2026-00${index + 31}',
    if (code == 2)
      'remarks':
          'The court order date does not match the uploaded Court '
          'Surrogacy Agreement Order.',
    'childSurname': surname,
    'childFirstName': firstName,
    'dateOfBirth': '2025-09-09',
    'childSex': 2,
    'birthType': 1,
    'placeOfBirth': 1,
    'birthOrder': 1,
    'birthCountry': 63,
    'birthState': 25,
    'birthLga': 501,
    'townOfBirth': 'Wuse 2',
    'localityType': 2,
    'regCenter': 5011,
    'courtNameOrReference': 'Federal High Court / FHC/L/CS/2025/0048',
    'parentalOrderDate': '2025-09-01',
    'surrogacyArrangementType': 'gestational',
    'lp1FullName': 'Ololade Simisola',
    'lp1MaritalStatus': 1,
    'lp1Address': 'No 12 Adeleke road, Lekki',
    'lp1ResidenceCountry': 63,
    'lp1ResidenceState': 25,
    'lp1ResidenceLga': 501,
    'lp1LocalityType': 2,
    'lp1Occupation': 100,
    'lp1Nationality': 63,
    'lp1Nin': '72921010909',
    'lp1LiteracyLevel': 1,
    'lp1EducationLevel': 9,
    'lp1Phone': '09012348349',
    'lp2Present': true,
    'lp2FullName': 'Ololade Adegoke',
    'lp2MaritalStatus': 1,
    'lp2Address': 'No 12 Adeleke road, Lekki',
    'lp2ResidenceCountry': 63,
    'lp2ResidenceState': 25,
    'lp2ResidenceLga': 501,
    'lp2LocalityType': 2,
    'lp2Occupation': 200,
    'lp2Nationality': 63,
    'lp2LiteracyLevel': 1,
    'lp2EducationLevel': 7,
    'lp2Phone': '09129830304',
    'smFullName': 'Bala Michelle',
    'smAgeAtBirth': 28,
    'smBirthOrder': 1,
    'smNationality': 63,
    if (!drafted) ...{
      'infSurname': 'Keith',
      'infFirstName': 'Ryan',
      'infSameResidenceAsLp1': false,
      'infCountry': 31,
      'infResidenceAddress': 'No 12 Adeleke road, Lekki',
      'infNationality': 31,
      'infOriginCountry': 31,
      'infRelationshipToChild': 13,
      'infPhone': '08123212820',
      'infPassportNo': 'X12345678',
      'infConsentType': 'signature_pad',
      'infSignature': 'surrogacy/sign-$index.png',
      'supportingDocument': [
        for (final type in [
          'court_surrogacy_agreement_order',
          'parental_order',
          'legal_mother_identity_document',
          'legal_father_identity_document',
        ])
          {
            'type': type,
            'file': 'surrogacy/$type.jpg',
            'mimeType': 'image/jpeg',
          },
      ],
    },
  };
}

/// An adoption record for list item [id] (`adoption-<status>-<i>`).
Map<String, Object?>? _adoptionRecord(String id, {String? referenceId}) {
  final parts = id.split('-');
  final index = parts.length == 3 ? int.tryParse(parts[2]) : null;
  if (parts.first != 'adoption' ||
      index == null ||
      index >= FakeBackendInterceptor._people.length) {
    return null;
  }
  final status = parts[1];
  final (name, _, date) = FakeBackendInterceptor._people[index];
  final [firstName, surname] = name.split(' ');
  final drafted = status == 'drafted';
  return {
    'id': id,
    'referenceId': referenceId ?? 'ACR-2026-000${3150 + index}',
    'status': switch (status) {
      'approved' || 'printed' => 1,
      'queried' => 2,
      'drafted' => 3,
      _ => 0,
    },
    'createdAt': date,
    if (status == 'approved' || status == 'printed')
      'certificateNo': 'ACR/LA/2026/00${index + 41}',
    if (status == 'queried')
      'remarks': "The child's date of birth does not match the court order.",
    'paymentReference': 'PAIDDEMO',
    'childNinVerified': false,
    'childSurname': surname,
    'childFirstName': firstName,
    'dateOfBirth': '2015-09-09',
    'childSex': 1,
    'placeOfBirth': 1,
    'birthOrder': 1,
    'birthState': 25,
    'birthLga': 501,
    'regState': 25,
    'regLga': 501,
    'regCenter': 5011,
    'localityType': 2,
    'ad1FullName': 'Ololade Semiola',
    'ad1Nin': '72921010909',
    'ad1MaritalStatus': 1,
    'ad1Nationality': 63,
    'ad1Address': 'No 12 Adeleke road, Lekki',
    'ad1Occupation': 100,
    'ad1ResidenceCountry': 63,
    'ad1ResidenceState': 25,
    'ad1ResidenceLga': 501,
    'ad1LocalityType': 2,
    'ad1LiteracyLevel': 1,
    'ad1EducationLevel': 7,
    'ad1Phone': '09012348349',
    'ad2Present': false,
    if (!drafted) ...{
      'courtName': 'Federal High Court',
      'orderReferenceNo': 'FCT/HC/CV/1889/2026',
      'adoptionOrderDate': '2025-09-09',
      'adoptionType': 'domestic',
      'infSurname': 'Keith',
      'infFirstName': 'Ryan',
      'infSameResidenceAsAdopter1': true,
      'infCountry': 63,
      'infResidenceState': 25,
      'infResidenceLga': 501,
      'infResidenceAddress': 'No 12 Adeleke road, Lekki',
      'infNationality': 63,
      'infRelationshipToChild': 13,
      'infPhone': '08123123123',
      'infConsentType': 'signature_pad',
      'infSignature': 'demo/signature.png',
      'supportingDocument': [
        for (final type in [
          'court_adoption_order',
          'adoption_certificate',
          'adoptive_mother_identity_document',
        ])
          {'type': type, 'file': 'demo/$type.jpg', 'mimeType': 'image/jpeg'},
      ],
    },
  };
}

/// `GET /birth-notification` by `type`. Ids: pending 520+, approved 530+,
/// queried 540, printed 550.
Map<String, Object?> _foreignBirths(Map<String, dynamic> query) {
  final type = query['type'] as String? ?? 'pending';
  final (code, count, firstId) = switch (type) {
    'approved' => (1, 3, 530),
    'queried' => (2, 1, 540),
    'printed' => (1, 1, 550),
    _ => (0, 2, 520),
  };
  final search = (query['search'] as String? ?? '').toLowerCase();
  final rows = [
    for (final (i, (name, _, date))
        in FakeBackendInterceptor._people.indexed.take(count))
      if (search.isEmpty || name.toLowerCase().contains(search))
        {
          'id': firstId + i,
          'notification_number': _notificationNumber(firstId + i),
          'reference': 'BN-${7731 + i}',
          'approved_status': code,
          'date_registered': date,
          'childData': {
            'firstname': name.split(' ').first,
            'surname': name.split(' ').last,
            'middle_name': null,
            'gender': '${i % 2 + 1}',
          },
        },
  ];
  return {
    'result': rows,
    'pagination': {'page': 1, 'pages': 1, 'total': rows.length},
  };
}

/// A demo record's notification number: its id after a fixed prefix.
String _notificationNumber(int id) => 'GB2610${'$id'.padLeft(5, '0')}';

/// `GET /birth-notification/{id}` for a list id.
Map<String, Object?>? _foreignBirthRecord(int? id) {
  if (id == null || id < 520 || id > 552) return null;
  final status = switch (id) {
    >= 550 => 1,
    >= 540 => 2,
    >= 530 => 1,
    _ => 0,
  };
  final (name, _, date) = FakeBackendInterceptor
      ._people[id % 10 % FakeBackendInterceptor._people.length];
  Map<String, Object?> person(int personId, Map<String, Object?> fields) => {
    'id': personId,
    'middle_name': null,
    ...fields,
  };
  final mother = person(id * 10 + 2, {
    'surname': 'Ololade',
    'firstname': 'Adegoke',
    'maiden_name': 'Bello',
    'nin': '90289384945',
    'current_marital_status': 1,
    'current_nationality': 63,
    'origin_state': 25,
    'origin_lga': 251,
    'ethnic_group': 7,
    'current_occupation': 100,
    'current_residence_country': 63,
    'current_residence_state': 25,
    'current_residence_lga': 251,
    'current_address': 'No 12 Adeleke road, Lekki',
    'current_literacy_level': 2,
    'current_phone_number': '08123212820',
  });
  return {
    'data': {
      'id': id,
      'notification_number': _notificationNumber(id),
      'reference': 'BN-${7000 + id}',
      'email': 'ololade@example.com',
      'approved_status': status,
      'date_registered': date,
      'mother_age_at_birth': 30,
      'father_age_at_birth': 35,
      'informant_relationship': 2,
      'birth_typeData': {'Birth_Type_ID': 1, 'Birth_Type': 'Single'},
      'birth_orderData': {'Birth_Order_ID': 1, 'Birth_Order': '1'},
      'birth_placeData': {'BirthPlace_ID': 1, 'BirthPlace_Name': 'Hospital'},
      'childData': person(id * 10 + 1, {
        'surname': name.split(' ').last,
        'firstname': name.split(' ').first,
        'gender': 2,
        'birth_date': '2025-12-12',
        'birth_country': 181,
        'birth_state': 951,
        'birth_countryData': {'Alpfa_2_Code': 'GB'},
      }),
      'motherData': mother,
      'fatherData': person(id * 10 + 3, {
        'surname': 'Keith',
        'firstname': 'Ryan',
        'nin': null,
        'current_marital_status': 1,
        'current_nationality': 181,
        'origin_state': 951,
        'current_residence_country': 181,
        'current_residence_state': 951,
        'current_address': '10 Baker Street, London',
        'current_literacy_level': 2,
      }),
      'informantData': null,
      'informant_consent': 'https://demo.test/files/signature.png',
      'supporting_document': 'https://demo.test/files/certificate.jpg',
      'child_face': null,
      'rawInformantConsent': 'foreign-birth/signature-$id.png',
      'rawSupportingDocument': 'foreign-birth/certificate-$id.jpg',
      'rawFace': null,
    },
    'queried': status == 2
        ? {
            'title': 'Supporting document',
            'reason':
                'The foreign birth certificate is unreadable. Upload a '
                'clearer photo.',
          }
        : null,
  };
}
