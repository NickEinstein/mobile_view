import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_draft.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_form.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_record.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_reference_data.dart';

// Shapes of the backend (NPC_ECRVS_API_V2, birth_notification/*).

/// `GET /birth-notification/stats/self`; "Downloaded" counts as printed.
ApplicationCounts countsFromJson(Object? json) {
  final map = json.asJsonMap();
  int count(String key) => switch (map[key]) {
    final num value => value.toInt(),
    final String value => int.tryParse(value) ?? 0,
    _ => 0,
  };
  return ApplicationCounts({
    ApplicationStatus.pending: count('Pending'),
    ApplicationStatus.approved: count('Approved'),
    ApplicationStatus.queried: count('Queried'),
    ApplicationStatus.printed: count('Downloaded'),
  });
}

/// The backend's `approved_status`.
const _statusCodes = {
  0: ApplicationStatus.pending,
  1: ApplicationStatus.approved,
  2: ApplicationStatus.queried,
};

/// `GET /birth-notification`; an unknown status counts as [requested].
List<BirthApplicationSummary> applicationsFromJson(
  Object? json, {
  required ApplicationStatus requested,
}) {
  final rows = json.asJsonMap()['result'];
  if (rows is! List<Object?>) {
    throw const FormatException('Expected "result" to be a list.');
  }
  return [for (final row in rows) _summaryFromJson(row.asJsonMap(), requested)];
}

BirthApplicationSummary _summaryFromJson(
  JsonMap map,
  ApplicationStatus requested,
) {
  final date = DateTime.tryParse(
    map.optionalString('date_registered') ??
        map.optionalString('createdAt') ??
        '',
  );
  if (date == null) {
    throw const FormatException('Expected "date_registered" to be a date.');
  }
  final child = switch (map['childData']) {
    final Map<String, Object?> data => data,
    _ => const <String, Object?>{},
  };
  final name = [
    child.optionalString('surname'),
    child.optionalString('firstname'),
    child.optionalString('middle_name'),
  ].whereType<String>().join(' ').trim();
  final number =
      map.optionalString('notification_number') ??
      map.optionalString('reference') ??
      '${map['id']}';
  final status = map['approved_status'];
  return BirthApplicationSummary(
    // A record is opened by its notification number.
    id: number,
    childName: name.isEmpty ? number : name,
    trackingId: number,
    submittedOn: date,
    status:
        (switch (status) {
          final int code => _statusCodes[code],
          final String code => _statusCodes[int.tryParse(code)],
          _ => null,
        }) ??
        requested,
  );
}

/// `GET /option/country`: `[{"Country_Code", "Country_Name",
/// "Country_Nationality_Name", "Alpfa_2_Code"}]`, sorted by name.
List<ForeignBirthCountry> countriesFromJson(Object? json) {
  if (json is! List<Object?>) {
    throw const FormatException('Expected a list of countries.');
  }
  final countries = [
    for (final item in json)
      if (item.asJsonMap() case final map)
        if ((map['Country_Code'], map.optionalString('Country_Name')) case (
          final Object id?,
          final String name?,
        ))
          ForeignBirthCountry(
            option: Option('$id', name),
            nationality: Option(
              '$id',
              map.optionalString('Country_Nationality_Name') ?? name,
            ),
            isoCode: map.optionalString('Alpfa_2_Code')?.toUpperCase(),
          ),
  ];
  return countries..sort((a, b) => a.option.label.compareTo(b.option.label));
}

/// `GET /file-upload-url/{name}`: `{"url": "https://…", "key": "…"}`
({Uri url, String key}) uploadTargetFromJson(Object? json) {
  final map = json.asJsonMap();
  final url = Uri.tryParse(map.requireString('url'));
  if (url == null || url.scheme != 'https') {
    throw const FormatException('Expected an HTTPS upload URL.');
  }
  return (url: url, key: map.requireString('key'));
}

/// `POST /birth-notification/add`: `{"success", "message",
/// "notification_number"}`.
String? submittedFromJson(Object? json) =>
    json.asJsonMap().optionalString('notification_number');

/// The body of `POST /birth-notification/add`; files as their storage
/// keys.
JsonMap foreignBirthPayloadToJson(
  ForeignBirthDraft draft, {
  required ForeignBirthReferenceData data,
}) {
  final child = draft.child;
  final mother = draft.mother;
  final father = draft.father;
  final informant = draft.informant;
  String? key(String? path) => path == null ? null : draft.uploads[path];
  final email = informant[InformantField.email];

  JsonMap parent(String prefix, ParentParticulars p) => {
    '${prefix}_surname': p[ParentField.surname],
    '${prefix}_firstname': p[ParentField.firstName],
    '${prefix}_middle_name': p[ParentField.middleName],
    '${prefix}_age_at_birth': _number(p[ParentField.age]),
    '${prefix}_marital_status': _number(p[ParentField.maritalStatus]),
    '${prefix}_nationality': _number(p[ParentField.nationality]),
    '${prefix}_state_of_origin': _number(p[ParentField.stateOfOrigin]),
    '${prefix}_lga_of_origin': p.isNigerian
        ? _number(p[ParentField.lgaOfOrigin])
        : null,
    '${prefix}_ethnic_group': p.isNigerian
        ? _number(p[ParentField.ethnicGroup])
        : null,
    // Only a validated NIN is sent.
    '${prefix}_nin': p.isNinVerified ? p[ParentField.nin] : null,
    '${prefix}_residence_country': _number(p[ParentField.country]),
    '${prefix}_residence_state': _number(p[ParentField.state]),
    '${prefix}_lga': p.livesInNigeria ? _number(p[ParentField.lga]) : null,
    '${prefix}_residence_address': p[ParentField.address],
    '${prefix}_literacy_level': _number(p[ParentField.literacy]),
    '${prefix}_education_Level':
        p[ParentField.literacy] == ForeignBirthCodes.literate
        ? _number(p[ParentField.educationLevel])
        : null,
    '${prefix}_phone': p[ParentField.phone],
  };

  return {
    'reference': draft.paymentReference,
    // Where the backend emails the acknowledgement and the certificate.
    'email': email,

    'surname': child[ChildField.surname],
    'firstname': child[ChildField.firstName],
    'middlename': child[ChildField.middleName],
    'date_of_birth': _date(child.dateOfBirth),
    'gender': _number(child[ChildField.sex]),
    'birth_type': _number(child[ChildField.typeOfBirth]),
    'birth_order': _number(child[ChildField.birthOrder]),
    'birth_place': _number(child[ChildField.placeOfOccurrence]),
    'birth_country': _number(child[ChildField.countryOfBirth]),
    'birth_country_code': data.isoCodeOf(child[ChildField.countryOfBirth]),
    'state': _number(child[ChildField.stateOfBirth]),
    'child_face': key(child[ChildField.facePhoto]),

    ...parent('mother', mother),
    'mother_maiden_name': mother[ParentField.maidenName],
    'mother_occupation': _number(mother[ParentField.occupation]),
    ...parent('father', father),

    'informant_relationship': _number(informant[InformantField.relationship]),
    'informant_surname': informant[InformantField.surname],
    'informant_firstname': informant[InformantField.firstName],
    'informant_middle_name': informant[InformantField.middleName],
    'informant_nin': informant.isNinVerified
        ? informant[InformantField.nin]
        : null,
    'informant_phone': informant[InformantField.phone],
    'informant_email': email,
    'informant_residence_country': _number(informant[InformantField.country]),
    'informant_residence_state': _number(informant[InformantField.state]),
    'informant_lga': informant.livesInNigeria
        ? _number(informant[InformantField.lga])
        : null,
    'informant_residence_address': informant[InformantField.address],
    'informant_nationality': _number(informant[InformantField.nationality]),
    'informant_state_of_origin': _number(
      informant[InformantField.stateOfOrigin],
    ),
    'informant_lga_of_origin': informant.isNigerian
        ? _number(informant[InformantField.lgaOfOrigin])
        : null,
    'informant_consent': key(draft.consentPath),

    'supporting_document': key(draft.certificate?.path),
  };
}

int? _number(String? value) => value == null ? null : int.tryParse(value);

/// YYYY-MM-DD.
String? _date(DateTime? value) => value == null
    ? null
    : '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';

/// The body of `PATCH /birth-notification/update`: the submit payload
/// plus the record's and people's ids.
JsonMap foreignBirthAmendToJson(
  ForeignBirthDraft draft, {
  required ForeignBirthRecord record,
  required ForeignBirthReferenceData data,
}) => {
  ...foreignBirthPayloadToJson(draft, data: data),
  'id': record.id,
  'childId': record.partyIds.child,
  'motherId': record.partyIds.mother,
  'fatherId': record.partyIds.father,
  'informantId': record.partyIds.informant,
};

// ---- Reading a notification back -------------------------------------------

/// Text for a JSON value: numbers as digits, blanks as null.
String? _text(Object? value) => switch (value) {
  final String text when text.trim().isNotEmpty => text,
  final num number => '$number',
  _ => null,
};

int _id(Object? value) => switch (value) {
  final int id => id,
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};

JsonMap _map(Object? value) =>
    value is Map<String, Object?> ? value : const <String, Object?>{};

ParentParticulars _parentFromJson(JsonMap person, Object? age) {
  final nin = _text(person['nin']);
  var values = FieldValues<ParentField>({
    for (final (field, key) in const [
      (ParentField.surname, 'surname'),
      (ParentField.firstName, 'firstname'),
      (ParentField.middleName, 'middle_name'),
      (ParentField.maidenName, 'maiden_name'),
      (ParentField.maritalStatus, 'current_marital_status'),
      (ParentField.nationality, 'current_nationality'),
      (ParentField.stateOfOrigin, 'origin_state'),
      (ParentField.lgaOfOrigin, 'origin_lga'),
      (ParentField.ethnicGroup, 'ethnic_group'),
      (ParentField.occupation, 'current_occupation'),
      (ParentField.country, 'current_residence_country'),
      (ParentField.state, 'current_residence_state'),
      (ParentField.lga, 'current_residence_lga'),
      (ParentField.address, 'current_address'),
      (ParentField.literacy, 'current_literacy_level'),
      (ParentField.educationLevel, 'current_education_level'),
      (ParentField.phone, 'current_phone_number'),
    ])
      field: ?_text(person[key]),
  });
  // A NIN on record was verified when it was submitted.
  if (nin != null) {
    values = values.set(ParentField.nin, nin).set(ParentField.verifiedNin, nin);
  }
  if (_text(age) case final age?) values = values.set(ParentField.age, age);
  return ParentParticulars(values);
}

/// `GET /birth-notification/cert/{number}` (no status: [status] comes from
/// the list row), or `/{id}`'s `{data, queried}`.
ForeignBirthRecord foreignBirthRecordFromJson(
  Object? json, {
  ApplicationStatus? status,
}) {
  final root = json.asJsonMap();
  // `/cert/{number}` sends the record bare.
  final data = root['data'] is Map<String, Object?>
      ? root.requireMap('data')
      : root;
  final child = _map(data['childData']);
  final motherJson = _map(data['motherData']);
  final fatherJson = _map(data['fatherData']);
  final relationship = _text(data['informant_relationship']);
  // A parent informant is that parent's person record.
  final informantJson = switch (data['informantData']) {
    final Map<String, Object?> informant => informant,
    _ when relationship == ForeignBirthCodes.father => fatherJson,
    _ when relationship == ForeignBirthCodes.mother => motherJson,
    _ => const <String, Object?>{},
  };

  final face = _text(data['rawFace']);
  final consent = _text(data['rawInformantConsent']);
  final document = _text(data['rawSupportingDocument']);

  var childValues = FieldValues<ChildField>({
    for (final (field, value) in [
      (ChildField.surname, child['surname']),
      (ChildField.firstName, child['firstname']),
      (ChildField.middleName, child['middle_name']),
      (ChildField.sex, child['gender']),
      (ChildField.countryOfBirth, child['birth_country']),
      (ChildField.stateOfBirth, child['birth_state']),
      (ChildField.typeOfBirth, _map(data['birth_typeData'])['Birth_Type_ID']),
      (ChildField.birthOrder, _map(data['birth_orderData'])['Birth_Order_ID']),
      (
        ChildField.placeOfOccurrence,
        _map(data['birth_placeData'])['BirthPlace_ID'],
      ),
      (ChildField.facePhoto, face),
    ])
      field: ?_text(value),
  });
  if (DateTime.tryParse(_text(child['birth_date']) ?? '') case final date?) {
    childValues = childValues.set(
      ChildField.dateOfBirth,
      DateTime(date.year, date.month, date.day).toIso8601String(),
    );
  }

  final informantNin = _text(informantJson['nin']);
  final informant = InformantParticulars(
    FieldValues({
      for (final (field, value) in [
        (InformantField.relationship, relationship),
        (InformantField.nin, informantNin),
        (InformantField.verifiedNin, informantNin),
        (InformantField.surname, informantJson['surname']),
        (InformantField.firstName, informantJson['firstname']),
        (InformantField.middleName, informantJson['middle_name']),
        (InformantField.country, informantJson['current_residence_country']),
        (InformantField.state, informantJson['current_residence_state']),
        (InformantField.lga, informantJson['current_residence_lga']),
        (InformantField.address, informantJson['current_address']),
        (InformantField.nationality, informantJson['current_nationality']),
        (InformantField.stateOfOrigin, informantJson['origin_state']),
        (InformantField.lgaOfOrigin, informantJson['origin_lga']),
        (InformantField.phone, informantJson['current_phone_number']),
        (
          InformantField.email,
          _text(data['email']) ?? _text(informantJson['current_email']),
        ),
        if (consent != null) ...[
          (InformantField.consentType, ConsentType.signature),
          (InformantField.signature, consent),
        ],
      ])
        field: ?_text(value),
    }),
  );

  final draft = ForeignBirthDraft(
    startedOn:
        DateTime.tryParse(_text(data['date_registered']) ?? '') ??
        DateTime.now(),
    paymentReference: _text(data['reference']),
    child: ChildParticulars(childValues),
    mother: _parentFromJson(motherJson, data['mother_age_at_birth']),
    father: _parentFromJson(fatherJson, data['father_age_at_birth']),
    informant: informant,
    certificate: document == null
        ? null
        : AttachedFile(
            path: document,
            name: document.substring(document.lastIndexOf('/') + 1),
            sizeBytes: 0,
          ),
    uploads: {?face: face, ?consent: consent, ?document: document},
  );

  // Absent from `/cert`, where the list row's [status] stands.
  final approval = data['approved_status'] == null
      ? null
      : _id(data['approved_status']);
  return ForeignBirthRecord(
    id: _id(data['id']),
    status: _statusCodes[approval] ?? status ?? ApplicationStatus.pending,
    draft: draft,
    partyIds: (
      child: _id(child['id']),
      mother: _id(motherJson['id']),
      father: _id(fatherJson['id']),
      informant: _id(informantJson['id']),
    ),
    notificationNumber: _text(data['notification_number']),
    queryReason: _text(_map(root['queried'])['reason']),
    fileUrls: {
      for (final (key, url) in [
        (face, data['child_face']),
        (consent, data['informant_consent']),
        (document, data['supporting_document']),
      ])
        if ((key, _text(url)) case (final key?, final url?)) key: url,
    },
  );
}
