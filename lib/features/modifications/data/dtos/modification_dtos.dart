import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_documents.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_submission.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_summary.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/queried_modification.dart';

// The backend's shapes (NPC_ECRVS_API_V2, src/app/modification). Rows
// differ per kind.

/// `GET /modification/<kind>/stats`: `{"total": "12", …}`, an SQL sum,
/// which arrives as a string.
int countFromJson(Object? json) => switch (json.asJsonMap()['total']) {
  final num total => total.toInt(),
  final String total => int.tryParse(total) ?? 0,
  _ => 0,
};

/// `GET /modification/<kind>/list`: `{"result": [row], "pagination": {}}`.
/// Rows don't carry their status; it is the one that was asked for.
List<ModificationSummary> requestsFromJson(
  Object? json, {
  required ModificationKind kind,
  required ModificationStatus status,
}) {
  final rows = json.asJsonMap()['result'];
  if (rows is! List<Object?>) {
    throw const FormatException('Expected "result" to be a list.');
  }
  return [
    for (final row in rows) _summaryFromJson(row.asJsonMap(), kind, status),
  ];
}

/// A list row, dated by `Modification[0].datetime_modified`.
ModificationSummary _summaryFromJson(
  JsonMap row,
  ModificationKind kind,
  ModificationStatus status,
) {
  final modifications = row['Modification'];
  final latest = modifications is List && modifications.isNotEmpty
      ? modifications.first
      : null;
  final date = latest is Map
      ? latest['datetime_modified'] ?? latest['date_created']
      : row['date_created'];

  final id = row['id'] ?? row['_id'];
  if (id is! int && id is! String) {
    throw const FormatException('Expected "id" to be a string or integer.');
  }
  return ModificationSummary(
    id: '$id',
    name: _personName(row, kind),
    certificateNumber: row.optionalString(_numberKeys(kind).last) ?? '',
    status: status,
    modifiedOn: date is String ? DateTime.tryParse(date) : null,
  );
}

/// `GET /modification/<kind>/cert/<number>`; null when there's no record.
ModificationRecord? recordFromJson(
  Object? json, {
  required ModificationKind kind,
  required String certificateNumber,
}) {
  final data = json.asJsonMap()['data'];
  if (data is! Map<String, Object?> || data.isEmpty) return null;
  final number = [
    for (final key in _numberKeys(kind)) ?data.optionalString(key),
  ].firstOrNull;
  return ModificationRecord(
    kind: kind,
    recordId: _recordId(data, kind),
    certificateNumber: number ?? certificateNumber,
    name: _personName(data, kind),
    values: switch (kind) {
      ModificationKind.birth => _birthValues(data),
      ModificationKind.attestation => _attestationValues(data),
      ModificationKind.death => _deathValues(data),
    },
  );
}

String _recordId(JsonMap data, ModificationKind kind) {
  final id = switch (kind) {
    ModificationKind.birth => data['Birth_Reg_ID'] ?? data['id'],
    _ => data['id'],
  };
  if (id is! int && id is! String) {
    throw const FormatException('Expected the record to have an id.');
  }
  return '$id';
}

JsonMap _part(JsonMap data, String key) =>
    data[key] is Map ? data.requireMap(key) : const <String, Object?>{};

Map<RecordField, String> _birthValues(JsonMap data) {
  final child = _part(data, 'childData');
  final mother = _part(data, 'motherData');
  final father = _part(data, 'fatherData');
  return {
    RecordField.surname: ?_text(child['surname']),
    RecordField.firstName: ?_text(child['firstname']),
    RecordField.middleName: ?_text(child['middle_name']),
    RecordField.dateOfBirth: ?_date(child['birth_date']),
    RecordField.sex: ?_text(child['gender']),
    RecordField.birthState: ?_text(child['birth_state']),
    RecordField.birthLga: ?_text(child['birth_lga']),
    RecordField.birthTown: ?_text(child['town_of_birth']),
    RecordField.motherSurname: ?_text(mother['surname']),
    RecordField.motherFirstName: ?_text(mother['firstname']),
    RecordField.motherMiddleName: ?_text(mother['middle_name']),
    RecordField.fatherSurname: ?_text(father['surname']),
    RecordField.fatherFirstName: ?_text(father['firstname']),
    RecordField.fatherMiddleName: ?_text(father['middle_name']),
  };
}

Map<RecordField, String> _attestationValues(JsonMap data) {
  final person = _part(data, 'personData');
  return {
    RecordField.surname: ?_text(person['surname']),
    RecordField.firstName: ?_text(person['firstname']),
    RecordField.middleName: ?_text(person['middle_name']),
    RecordField.dateOfBirth: ?_date(person['birth_date']),
    RecordField.sex: ?_text(person['gender']),
    RecordField.birthState: ?_text(person['birth_state']),
    RecordField.birthLga: ?_text(person['birth_lga']),
    RecordField.birthTown: ?_text(person['town_of_birth']),
    RecordField.originState: ?_text(person['origin_state']),
    RecordField.originLga: ?_text(person['origin_lga']),
    RecordField.originTown: ?_text(person['town_of_origin']),
    RecordField.motherSurname: ?_text(data['mother_surname']),
    RecordField.motherFirstName: ?_text(data['mother_firstname']),
    // The maiden name is shown as the mother's middle name.
    RecordField.motherMiddleName: ?_text(data['mother_maiden_name']),
    RecordField.fatherSurname: ?_text(data['father_surname']),
    RecordField.fatherFirstName: ?_text(data['father_firstname']),
  };
}

Map<RecordField, String> _deathValues(JsonMap data) {
  final deceased = _part(data, 'deceasedData');
  return {
    RecordField.surname: ?_text(deceased['surname']),
    RecordField.firstName: ?_text(deceased['firstname']),
    RecordField.middleName: ?_text(deceased['middle_name']),
    RecordField.sex: ?_text(deceased['gender']),
    RecordField.ageAtDeath: ?_text(data['deceased_age_at_death']),
    RecordField.dateOfDeath: ?_date(data['deceased_date_of_death']),
  };
}

/// A date, even when sent as a timestamp.
String? _date(Object? value) {
  final text = _text(value);
  return text == null || text.length < 10 ? null : text.substring(0, 10);
}

/// Text or an id, trimmed; null when blank.
String? _text(Object? value) {
  final text = switch (value) {
    final String text => text.trim(),
    final num number => '$number',
    _ => '',
  };
  return text.isEmpty ? null : text;
}

/// `GET /option/states/<country>`: `[{"State_ID", "State_Name"}]`.
List<Option> statesFromJson(Object? json) =>
    _optionsFromJson(json, id: 'State_ID', label: 'State_Name');

/// `GET /option/lga/<state>`: `[{"LGA_Code", "LGA_Name"}]`.
List<Option> lgasFromJson(Object? json) =>
    _optionsFromJson(json, id: 'LGA_Code', label: 'LGA_Name');

List<Option> _optionsFromJson(
  Object? json, {
  required String id,
  required String label,
}) {
  if (json is! List<Object?>) {
    throw const FormatException('Expected a list of options.');
  }
  return [
    for (final item in json)
      if (item.asJsonMap() case final map)
        if ((_text(map[id]), _text(map[label])) case (final id?, final label?))
          Option(id, label),
  ];
}

/// What each kind calls its values in requests. Attestation names and
/// sex go under both names the API uses.
Map<RecordField, List<String>> _apiNames(ModificationKind kind) =>
    switch (kind) {
      ModificationKind.birth => const {
        RecordField.surname: ['child_surname'],
        RecordField.firstName: ['child_firstname'],
        RecordField.middleName: ['child_middlename'],
        RecordField.dateOfBirth: ['child_age'],
        RecordField.sex: ['child_sex'],
        RecordField.birthState: ['child_state_of_birth'],
        RecordField.birthLga: ['child_lga_of_birth'],
        RecordField.birthTown: ['child_town_of_birth'],
        RecordField.motherSurname: ['mother_surname'],
        RecordField.motherFirstName: ['mother_firstname'],
        RecordField.motherMiddleName: ['mother_middlename'],
        RecordField.fatherSurname: ['father_surname'],
        RecordField.fatherFirstName: ['father_firstname'],
        RecordField.fatherMiddleName: ['father_middlename'],
      },
      ModificationKind.attestation => const {
        RecordField.surname: ['attestation_surname', 'applicant_surname'],
        RecordField.firstName: ['attestation_firstname', 'applicant_firstname'],
        RecordField.middleName: [
          'attestation_middlename',
          'applicant_middlename',
        ],
        RecordField.dateOfBirth: ['applicant_age'],
        RecordField.sex: ['attestation_sex', 'applicant_sex'],
        RecordField.birthState: ['applicant_state_of_birth'],
        RecordField.birthLga: ['applicant_lga_of_birth'],
        RecordField.birthTown: ['applicant_town_of_birth'],
        RecordField.originState: ['applicant_state_of_origin'],
        RecordField.originLga: ['applicant_lga_of_origin'],
        RecordField.originTown: ['applicant_town_of_origin'],
        RecordField.motherSurname: ['mother_surname'],
        RecordField.motherFirstName: ['mother_firstname'],
        RecordField.motherMiddleName: ['mother_middlename'],
        RecordField.fatherSurname: ['father_surname'],
        RecordField.fatherFirstName: ['father_firstname'],
      },
      ModificationKind.death => const {
        RecordField.surname: ['deceased_surname'],
        RecordField.firstName: ['deceased_firstname'],
        RecordField.middleName: ['deceased_middlename'],
        RecordField.sex: ['deceased_sex'],
        RecordField.ageAtDeath: ['deceased_age_at_death'],
        RecordField.dateOfDeath: ['deceased_date_of_death'],
      },
    };

/// Sent as numbers.
const _numberFields = {
  RecordField.sex,
  RecordField.birthState,
  RecordField.birthLga,
  RecordField.originState,
  RecordField.originLga,
  RecordField.ageAtDeath,
};

/// What the record's id is called in requests.
String _recordIdName(ModificationKind kind) => switch (kind) {
  ModificationKind.birth => 'Birth_Reg_ID',
  ModificationKind.attestation => 'attestation_id',
  ModificationKind.death => 'death_id',
};

/// A document uploaded to storage, as the request refers to it.
typedef UploadedDocument = ({String type, String key, String mimeType});

/// `POST /modification/<kind>` body: only the changed values, plus
/// documents for a date of birth. A resend (`PATCH`) adds its `id`.
// A resend's `id` is the request's own for every kind.
JsonMap submissionToJson(
  ModificationSubmission submission, {
  List<UploadedDocument> documents = const [],
}) {
  final request = submission.request;
  final edit = submission.edit;
  final kind = request.kind;
  Object? number(String value) => int.tryParse(value) ?? value;

  final comment = request.comment.trim();
  final modificationId = submission.modificationId;
  final kept = [
    for (final MapEntry(key: type, value: file)
        in submission.documents.uploaded.entries)
      (type: type.apiValue, key: file.key, mimeType: file.mimeType),
  ];
  final allDocuments = [...kept, ...documents];
  final apiNames = _apiNames(kind);
  return {
    if (modificationId != null) 'id': number(modificationId),
    _recordIdName(kind): number(edit.record.recordId),
    'mod_type': request.type?.apiValue,
    'mod_field': request.apiField,
    'mod_reason': request.reason?.apiValue,
    if (comment.isNotEmpty) 'comment': comment,
    'reference': submission.paymentReference,
    for (final field in RecordField.values)
      if (edit.editable.contains(field))
        if (edit[field] case final value?)
          for (final name in apiNames[field] ?? const <String>[])
            name: _numberFields.contains(field) ? number(value) : value,
    if (allDocuments.isNotEmpty)
      'supportingDocument': [
        for (final document in allDocuments)
          {
            'type': document.type,
            'file': document.key,
            'mimeType': document.mimeType,
          },
      ],
  };
}

/// `GET /modification/<kind>/single/<id>`: the request in
/// `Modification[0]`. Null when it isn't one this app offers.
// A place sent isn't returned (only `*_prev_*`), so it is asked again.
QueriedModification? queriedFromJson(
  Object? json, {
  required ModificationKind kind,
}) {
  final map = json.asJsonMap();
  final data = map.requireMap('data');
  final queried = _part(map, 'queried');
  final modifications = data['Modification'];
  if (modifications is! List<Object?> || modifications.isEmpty) {
    throw const FormatException('Expected "Modification" to be a list.');
  }
  final modification = modifications.first.asJsonMap();
  final request = ModificationRequest.fromApi(
    kind,
    type: modification.optionalString('mod_type'),
    field: modification.optionalString('mod_field'),
    reason: modification.optionalString('mod_reason'),
    comment: modification.optionalString('comment'),
  );
  if (request == null) return null;

  final id = modification['id'];
  if (id is! int && id is! String) {
    throw const FormatException('Expected the request to have an id.');
  }
  // The first value found under any of the field's names.
  String? sent(RecordField field, List<String> names) => [
    for (final name in names) ...[modification[name], data[name]],
  ].map(field.isDate ? _date : _text).nonNulls.firstOrNull;
  final values = <RecordField, String>{
    for (final MapEntry(key: field, value: names) in _apiNames(kind).entries)
      field: ?sent(field, names),
  };
  final number = [
    for (final key in _numberKeys(kind)) ?data.optionalString(key),
  ].firstOrNull;
  return QueriedModification(
    id: '$id',
    request: request,
    record: ModificationRecord(
      kind: kind,
      recordId: _recordId(data, kind),
      certificateNumber: number ?? '',
      name: [
        values[RecordField.surname],
        values[RecordField.firstName],
      ].nonNulls.join(' '),
      values: values,
    ),
    paymentReference: modification.optionalString('reference') ?? '',
    queryReason: queried.optionalString('reason') ?? '',
    documents: _uploadedFromJson(
      modification['supportingDocument'] ?? data['SupportingDocument'],
    ),
  );
}

/// `[{"type", "file", "mimeType"}]`, skipping types this app doesn't know.
Map<ModificationDocument, UploadedFile> _uploadedFromJson(Object? json) {
  final documents = <ModificationDocument, UploadedFile>{};
  if (json is! List<Object?>) return documents;
  for (final item in json) {
    if (item case {'type': final String type, 'file': final String file}) {
      final documentType = ModificationDocument.values
          .where((option) => option.apiValue == type)
          .firstOrNull;
      if (documentType == null) continue;
      documents[documentType] = UploadedFile(
        key: storageKey(file),
        mimeType: switch (item) {
          {'mimeType': final String mimeType} => mimeType,
          _ => 'image/jpeg',
        },
      );
    }
  }
  return documents;
}

/// A stored file's key, also from its full storage URL (as it sometimes
/// comes back).
String storageKey(String file) {
  final path = file.split('?').first;
  const host = 'amazonaws.com/';
  final at = path.indexOf(host);
  return at < 0 ? path : path.substring(at + host.length);
}

/// `GET /file-upload-url/<name>`: `{"url", "key"}`.
({Uri url, String key}) uploadUrlFromJson(Object? json) {
  final map = json.asJsonMap();
  final url = Uri.tryParse(map.requireString('url'));
  if (url == null || url.scheme != 'https') {
    throw const FormatException('Expected an HTTPS upload URL.');
  }
  return (url: url, key: map.requireString('key'));
}

/// The server's `{"message": "..."}`, if any.
String? messageFromJson(Object? json) =>
    json is Map<String, Object?> ? json.optionalString('message') : null;

String _personName(JsonMap row, ModificationKind kind) {
  final key = switch (kind) {
    ModificationKind.birth => 'childData',
    ModificationKind.attestation => 'personData',
    ModificationKind.death => 'deceasedData',
  };
  final person = row[key] is Map
      ? row.requireMap(key)
      : const <String, Object?>{};
  return [
    for (final part in const ['surname', 'firstname', 'middle_name'])
      if (person[part] case final String text when text.trim().isNotEmpty)
        text.trim(),
  ].join(' ');
}

/// Where each kind keeps its certificate number, preferred first.
List<String> _numberKeys(ModificationKind kind) => switch (kind) {
  ModificationKind.birth => const ['Certificate_No', 'birth_number'],
  ModificationKind.attestation => const ['attestation_number'],
  ModificationKind.death => const ['death_certificate_number'],
};
