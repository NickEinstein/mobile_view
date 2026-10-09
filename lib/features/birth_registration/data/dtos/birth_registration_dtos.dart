import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/application_details.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

// Shapes of the backend (NPC_ECRVS_API_V2, src/app/birth-registration and
// src/app/index).

/// Ids and numbers come as JSON numbers or numeric strings (Postgres
/// `SUM` and `bigint` arrive as strings); the form keeps text.
String? _text(Object? value) => switch (value) {
  final String text when text.trim().isNotEmpty => text.trim(),
  final num number => '$number',
  _ => null,
};

JsonMap? _map(Object? value) => value is Map<String, Object?> ? value : null;

/// `GET /birth-registration/stats/self`: `{"Pending", "Approved",
/// "Queried", "Printed", "total"}`, as numbers or numeric strings.
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
    ApplicationStatus.printed: count('Printed'),
    ApplicationStatus.queried: count('Queried'),
  });
}

/// `Approval_Status` codes, as the other registrations use them.
const _approvalStatuses = {
  0: ApplicationStatus.pending,
  1: ApplicationStatus.approved,
  2: ApplicationStatus.queried,
};
const _printComplete = 1;

ApplicationStatus? _statusOf(JsonMap row) {
  if (int.tryParse(_text(row['Print_Status']) ?? '') == _printComplete) {
    return ApplicationStatus.printed;
  }
  return _approvalStatuses[int.tryParse(_text(row['Approval_Status']) ?? '')];
}

/// `GET /birth-registration/list`. Rows carry no status: the [status]
/// asked for is used.
List<BirthApplicationSummary> applicationsFromJson(
  Object? json, {
  required ApplicationStatus status,
}) {
  final rows = json.asJsonMap()['result'];
  if (rows is! List<Object?>) {
    throw const FormatException('Expected "result" to be a list.');
  }
  return [for (final row in rows) _summaryFromJson(row.asJsonMap(), status)];
}

BirthApplicationSummary _summaryFromJson(
  JsonMap row,
  ApplicationStatus status,
) {
  final id = _text(row['Birth_Reg_ID']);
  if (id == null) {
    throw const FormatException('Expected "Birth_Reg_ID".');
  }
  final submittedOn = DateTime.tryParse(
    row.optionalString('initiatedAt') ??
        row.optionalString('Date_Registerred') ??
        '',
  );
  if (submittedOn == null) {
    throw const FormatException('Expected "Date_Registerred" to be a date.');
  }
  final child = _map(row['childData']) ?? const {};
  final name = [
    _text(child['surname']),
    _text(child['firstname']),
    _text(child['middle_name']),
  ].whereType<String>().join(' ');
  final certificateNo = _text(row['Certificate_No']) ?? id;
  return BirthApplicationSummary(
    id: id,
    childName: name.isEmpty ? certificateNo : name,
    trackingId: certificateNo,
    submittedOn: submittedOn,
    status: status,
  );
}

/// `GET /birth-registration/{id}`: `{data, queried}`. Files come as URLs,
/// with `raw*` storage keys.
ApplicationDetails applicationDetailsFromJson(Object? json) {
  final outer = json.asJsonMap();
  final data = outer.requireMap('data');
  final child = _map(data['childData']) ?? const {};
  final mother = _map(data['motherData']) ?? const {};
  final father = _map(data['fatherData']) ?? const {};
  final informant = _map(data['informantData']) ?? const {};
  final centre = _map(data['Reg_CenterData']) ?? const {};
  final centreLga = _map(centre['LGAs']) ?? const {};
  final centreState = _map(centreLga['states']) ?? const {};
  final relationship =
      _map(data['Informant_RelationshipData']) ??
      _map(data['relationship']) ??
      const {};

  final summary = _summaryFromJson({
    ...data,
    'childData': child,
  }, _statusOf(data) ?? ApplicationStatus.pending);

  return ApplicationDetails(
    summary: summary,
    childNin: _text(child['nin']),
    child: ChildParticulars({
      for (final MapEntry(:key, :value) in {
        ChildField.surname: child['surname'],
        ChildField.firstName: child['firstname'],
        ChildField.middleName: child['middle_name'],
        ChildField.dateOfBirth: _dateOnly(child['birth_date']),
        ChildField.typeOfBirth: data['Birth_type'],
        ChildField.birthOrder: data['birth_order'],
        ChildField.sex: child['gender'],
        ChildField.placeOfOccurrence: data['birth_place'],
        ChildField.stateOfBirth: child['birth_state'],
        ChildField.lgaOfBirth: child['birth_lga'],
        ChildField.localityOfBirth: child['town_of_birth'],
        ChildField.stateOfOrigin: child['origin_state'],
        ChildField.lgaOfOrigin: child['origin_lga'],
        ChildField.townOfOrigin: child['town_of_origin'],
        ChildField.registrationState:
            centreState['State_ID'] ?? centreLga['State_ID'],
        ChildField.registrationLga: centreLga['LGA_ID'] ?? centre['LGA_ID'],
        ChildField.registrationCenter: data['Reg_Center'],
        ChildField.localityType:
            child['birth_settlement_type'] ?? data['locality_of_birth'],
        ChildField.facePhoto: data['ChildFace'],
      }.entries)
        key: ?_text(value),
    }),
    mother: ParentParticulars(
      _parentValues(mother, age: data['mother_age_at_birth']),
    ),
    father: ParentParticulars(
      _parentValues(father, age: data['father_age_at_birth']),
    ),
    // The informant's signature isn't sent back.
    informant: InformantParticulars({
      for (final MapEntry(:key, :value) in {
        InformantField.relationship:
            relationship['Relationship_ID'] ??
            data['Informant_Relationship_ID'],
        InformantField.surname: informant['surname'],
        InformantField.firstName: informant['firstname'],
        InformantField.middleName: informant['middle_name'],
        InformantField.country: informant['current_residence_country'],
        InformantField.state: informant['current_residence_state'],
        InformantField.lga: informant['current_residence_lga'],
        InformantField.address: informant['current_address'],
        InformantField.settlement: informant['birth_settlement_type'],
        InformantField.phone: informant['current_phone_number'],
        InformantField.nin: informant['nin'],
        InformantField.trackingId: informant['tracking_id'],
      }.entries)
        key: ?_text(value),
    }),
    documents: _documentsFromJson(data['SupportingDocument']),
    queryReason: _text(_map(outer['queried'])?['reason']),
    paymentReference: _text(data['reference']),
    // Storage keys, for sending a correction back without re-uploading.
    faceKey: _text(data['rawChildFace']),
    documentKeys: _documentKeysFromJson(data['rawSupportingDocument']),
  );
}

/// `rawSupportingDocument`: `[{"type", "file" (storage key), "mimeType"}]`.
Map<DocumentType, String> _documentKeysFromJson(Object? json) {
  if (json is! List<Object?>) return const {};
  final byApiType = {for (final t in DocumentType.values) t.apiType: t};
  return {
    for (final item in json)
      if (_map(item) case final map?)
        if ((byApiType[map['type']], _text(map['file'])) case (
          final type?,
          final key?,
        ))
          type: key,
  };
}

/// "2025-12-12" from a date or an ISO timestamp, so time zones can't move
/// the day.
String? _dateOnly(Object? value) {
  final text = _text(value);
  if (text == null || text.length < 10) return text;
  return DateTime.tryParse(text.substring(0, 10)) == null
      ? text
      : text.substring(0, 10);
}

Map<ParentField, String> _parentValues(JsonMap person, {Object? age}) => {
  for (final MapEntry(:key, :value) in {
    ParentField.nin: person['nin'],
    ParentField.surname: person['surname'],
    ParentField.firstName: person['firstname'],
    ParentField.maidenName: person['maiden_name'],
    ParentField.middleName: person['middle_name'],
    ParentField.country: person['current_residence_country'],
    ParentField.state: person['current_residence_state'],
    ParentField.lga: person['current_residence_lga'],
    ParentField.address: person['current_address'],
    ParentField.settlement: person['birth_settlement_type'],
    ParentField.age: age,
    ParentField.maritalStatus: person['current_marital_status'],
    ParentField.nationality: person['current_nationality'],
    ParentField.stateOfOrigin: person['origin_state'],
    ParentField.lgaOfOrigin: person['origin_lga'],
    ParentField.ethnicGroup: person['ethnic_group'],
    ParentField.literacy: person['current_literacy_level'],
    ParentField.educationLevel: person['current_education_level'],
    ParentField.occupation: person['current_occupation'],
    ParentField.phone: person['current_phone_number'],
  }.entries)
    key: ?_text(value),
};

/// `[{"type", "mimeType", "file"}]`; entries without a file were not
/// uploaded.
SupportingDocuments _documentsFromJson(Object? json) {
  if (json is! List<Object?>) return const SupportingDocuments();
  final byApiType = {for (final t in DocumentType.values) t.apiType: t};
  return SupportingDocuments({
    for (final item in json)
      if (_map(item) case final map?)
        if ((byApiType[map['type']], _text(map['file'])) case (
          final type?,
          final url?,
        ))
          type: AttachedFile(
            path: url,
            name: Uri.tryParse(url)?.pathSegments.lastOrNull ?? type.apiType,
            sizeBytes: 0,
          ),
  });
}

/// Rows of [id] and the first of [labels] present.
List<Option> optionsFromJson(
  Object? json, {
  required String id,
  required List<String> labels,
}) {
  if (json is! List<Object?>) {
    throw FormatException('Expected a list of "$id" rows.');
  }
  return [
    for (final item in json)
      if (_map(item) case final row?)
        if ((
              _text(row[id]),
              labels.map((key) => _text(row[key])).nonNulls.firstOrNull,
            )
            case (final id?, final label?))
          Option(id, label),
  ];
}

/// `GET /option/country`: `[{"Country_Code", "Country_Name",
/// "Country_Nationality_Name"}]`.
({List<Option> countries, List<Option> nationalities}) countriesFromJson(
  Object? json,
) => (
  countries: _sorted(
    optionsFromJson(json, id: 'Country_Code', labels: const ['Country_Name']),
  ),
  nationalities: _sorted(
    optionsFromJson(
      json,
      id: 'Country_Code',
      labels: const ['Country_Nationality_Name', 'Country_Name'],
    ),
  ),
);

typedef StateRow = ({String id, String name, String? code});
typedef LgaRow = ({String id, String name, String? code, String state});
typedef CentreRow = ({String id, String name, String lga});

List<JsonMap> _rows(Object? json, String what) {
  if (json is! List<Object?>) {
    throw FormatException('Expected a list of $what.');
  }
  return json.map(_map).nonNulls.toList();
}

/// `GET /option/states/63`: `[{"State_ID", "State_Name", "State_Code"}]`.
List<StateRow> stateRowsFromJson(Object? json) => [
  for (final row in _rows(json, 'states'))
    if ((_text(row['State_ID']), _text(row['State_Name'])) case (
      final id?,
      final name?,
    ))
      (id: id, name: name, code: _text(row['State_Code'])),
];

/// `GET /option/lga/:stateId`: `[{"LGA_ID", "LGA_Code", "LGA_Name",
/// "State_ID"}]`.
List<LgaRow> lgaRowsFromJson(Object? json) => [
  for (final row in _rows(json, 'LGAs'))
    if ((
          _text(row['LGA_ID']) ?? _text(row['LGA_Code']),
          _text(row['LGA_Name']),
          _text(row['State_ID']),
        )
        case (final id?, final name?, final state?))
      (id: id, name: name, code: _text(row['LGA_Code']), state: state),
];

/// `GET /option/registration-centres` (every centre): `[{"Reg_Center_id",
/// "Reg_Center_Name", "LGA_ID"}]`.
List<CentreRow> centreRowsFromJson(Object? json) => [
  for (final row in _rows(json, 'registration centres'))
    if ((
          _text(row['Reg_Center_id']),
          _text(row['Reg_Center_Name']),
          _text(row['LGA_ID']),
        )
        case (final id?, final name?, final lga?))
      (id: id, name: name, lga: lga),
];

/// The states, alphabetical. Their LGAs are added once each is chosen
/// (see [lgasWithCentres]).
List<StateOption> statesFromRows(List<StateRow> states) => [
  for (final state in states)
    StateOption(
      option: Option(state.id, state.name),
      code: state.code,
      lgas: const [],
    ),
]..sort((a, b) => a.option.label.compareTo(b.option.label));

/// One state's LGAs, alphabetical, each with its registration centres
/// (the full centre list, filtered by `LGA_ID`).
List<LgaOption> lgasWithCentres(List<LgaRow> lgas, List<CentreRow> centres) {
  final centresByLga = <String, List<Option>>{};
  for (final centre in centres) {
    (centresByLga[centre.lga] ??= []).add(Option(centre.id, centre.name));
  }
  return [
    for (final lga in lgas)
      LgaOption(
        option: Option(lga.id, lga.name),
        code: lga.code,
        registrationCenters: _sorted(centresByLga[lga.id] ?? const []),
      ),
  ]..sort((a, b) => a.option.label.compareTo(b.option.label));
}

/// Alphabetical.
List<Option> _sorted(List<Option> options) =>
    [...options]..sort((a, b) => a.label.compareTo(b.label));
