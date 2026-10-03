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
