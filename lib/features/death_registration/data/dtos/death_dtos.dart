import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/birth_registration_dtos.dart'
    show countsFromJson;
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/option_lists.dart'
    as option_lists;
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_draft.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_form.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_record.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_reference_data.dart';

// Shapes of the backend (NPC_ECRVS_API_V2, src/app/death-registration).

/// `GET /death-registration/stats`, shaped like Birth Registration's.
ApplicationCounts deathCountsFromJson(Object? json) => countsFromJson(json);

/// `GET /death-registration/list`, for the [status] asked for.
List<BirthApplicationSummary> deathRegistrationsFromJson(
  Object? json, {
  required ApplicationStatus status,
}) {
  final rows = json.asJsonMap()['result'];
  if (rows is! List<Object?>) {
    throw const FormatException('Expected "result" to be a list.');
  }
  return [
    for (final row in rows) _summaryFromJson(row.asJsonMap(), status: status),
  ];
}

BirthApplicationSummary _summaryFromJson(
  JsonMap map, {
  required ApplicationStatus status,
}) {
  final created = DateTime.tryParse(map.requireString('date_created'));
  if (created == null) {
    throw const FormatException('Expected "date_created" to be a date.');
  }
  return BirthApplicationSummary(
    id: '${map['id']}',
    childName: _deceasedName(map),
    trackingId:
        map.optionalString('death_certificate_number') ?? '${map['id']}',
    submittedOn: created,
    status: status,
  );
}

/// "Surname Firstname Middlename".
String _deceasedName(JsonMap row) {
  final data = row['deceasedData'];
  if (data is! Map<String, Object?>) return '-';
  return [
    data.optionalString('surname'),
    data.optionalString('firstname'),
    data.optionalString('middle_name'),
  ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
}

/// The `POST /death-registration/add` body, with the uploaded files' keys.
JsonMap deathToJson(
  DeathDraft draft, {
  required DeathReferenceData places,
  required Map<DeathDocument, String> documents,
  required String? signature,
}) {
  final d = draft.deceased;
  final i = draft.informant;
  Object? number(String? value) =>
      value == null ? null : int.tryParse(value) ?? value;
  Object? deceased(DeceasedField field) =>
      d.applies(field) ? number(d[field]) : null;
  Object? informant(InformantField field) =>
      i.applies(field) ? number(i[field]) : null;
  return {
    'registration_center': number(d[DeceasedField.registrationCenter]),
    'deceased_state_code': places.stateCode(d[DeceasedField.registrationState]),
    'deceased_lga_code': places.lgaCode(
      d[DeceasedField.registrationState],
      d[DeceasedField.registrationLga],
    ),
    'deceased_nin': d[DeceasedField.nin],
    'deceased_surname': d[DeceasedField.surname],
    'deceased_firstname': d[DeceasedField.firstName],
    'deceased_middlename': d[DeceasedField.middleName],
    'deceased_sex': number(d[DeceasedField.sex]),
    'deceased_country': number(d[DeceasedField.country]),
    'deceased_state': deceased(DeceasedField.state),
    'deceased_lga': deceased(DeceasedField.lga),
    'deceased_street_name': d.applies(DeceasedField.address)
        ? d[DeceasedField.address]
        : null,
    'deceased_settlement': deceased(DeceasedField.settlement),
    'deceased_literacy': number(d[DeceasedField.literacy]),
    'deceased_level_of_education': deceased(DeceasedField.educationLevel),
    'deceased_occupation': number(d[DeceasedField.occupation]),
    'deceased_date_of_death': d[DeceasedField.dateOfDeath],
    'deceased_place_of_death': number(d[DeceasedField.placeOfDeath]),
    'deceased_village': d[DeceasedField.village],
    'deceased_age_at_death': number(d[DeceasedField.ageAtDeath]),
    'deceased_marital_status': number(d[DeceasedField.maritalStatus]),
    'deceased_certified_by_doctor': number(d[DeceasedField.certifiedByDoctor]),
    'deceased_nationality': number(d[DeceasedField.nationality]),
    'deceased_state_of_origin': deceased(DeceasedField.stateOfOrigin),
    'deceased_lga_of_origin': deceased(DeceasedField.lgaOfOrigin),
    'deceased_ethnic_group': deceased(DeceasedField.ethnicGroup),
    'deceased_cause_of_death': number(d[DeceasedField.causeOfDeath]),
    'informant_surname': i[InformantField.surname],
    'informant_firstname': i[InformantField.firstName],
    'informant_middlename': i[InformantField.middleName],
    'informant_country': number(i[InformantField.country]),
    'informant_state': informant(InformantField.state),
    'informant_lga': informant(InformantField.lga),
    'informant_street_name': i.applies(InformantField.address)
        ? i[InformantField.address]
        : null,
    'informant_settlement': informant(InformantField.settlement),
    'informant_relationship_with_deceased': number(
      i[InformantField.relationship],
    ),
    'informant_phone_number': i[InformantField.phone],
    'informant_nin': i[InformantField.nin],
    'informant_signature': signature,
    'SupportingDocument': [
      for (final document in DeathDocument.values)
        {
          'type': document.apiType,
          'file': documents[document],
          'mimeType': switch (draft.documents[document]?.name) {
            null => null,
            final name when name.toLowerCase().endsWith('.png') => 'image/png',
            _ => 'image/jpeg',
          },
        },
    ],
  };
}

/// The registration number, if the answer has one.
String? deathAddedFromJson(Object? json) => switch (json) {
  {'registrationNumber': final String number} => number,
  {'item': {'death_certificate_number': final String number}} => number,
  _ => null,
};

/// `{"url": "https://…", "key": "…"}`
({Uri url, String key}) deathUploadTargetFromJson(Object? json) {
  final map = json.asJsonMap();
  final url = Uri.tryParse(map.requireString('url'));
  if (url == null || url.scheme != 'https') {
    throw const FormatException('Expected an HTTPS upload URL.');
  }
  return (url: url, key: map.requireString('key'));
}

/// `approved_status` codes, as Birth Registration reads them.
const _approvalStatuses = {
  0: ApplicationStatus.pending,
  1: ApplicationStatus.approved,
  2: ApplicationStatus.queried,
};

/// The backend returns only the place of death's description
/// (`{"BirthPlace_Desc"}`); its id is the option with that label.
String? _placeOfDeathId(Object? data) {
  if (data is! Map<String, Object?>) return null;
  final label = data.optionalString('BirthPlace_Desc')?.trim().toLowerCase();
  for (final option in option_lists.placesOfOccurrence) {
    if (option.label.toLowerCase() == label) return option.id;
  }
  return null;
}

/// `GET /death-registration/{id}`: `{data, queried}`, files as URLs with
/// `raw*` keys. Older keys are read as fallbacks.
DeathRecord deathRecordFromJson(Object? json) {
  final outer = json.asJsonMap();
  final data = outer['data'] is Map<String, Object?>
      ? outer.requireMap('data')
      : outer;
  final deceasedData = data['deceasedData'] is Map<String, Object?>
      ? data.requireMap('deceasedData')
      : const <String, Object?>{};
  final informantData = data['informantData'] is Map<String, Object?>
      ? data.requireMap('informantData')
      : const <String, Object?>{};

  /// Text of the first value that is set.
  String? pick(List<Object?> values) {
    for (final value in values) {
      final text = switch (value) {
        null => null,
        final String s => s.trim(),
        final v => '$v',
      };
      if (text != null && text.isNotEmpty && text != '---') return text;
    }
    return null;
  }

  final dateOfDeath = DateTime.tryParse(
    pick([data['deceased_date_of_death']]) ?? '',
  );
  final deceasedNin = pick([deceasedData['nin']]);
  final deceased = DeceasedParticulars(
    FieldValues({
      for (final (field, value) in [
        (DeceasedField.nin, deceasedNin),
        (DeceasedField.noNinReason, deceasedData['no_nin_reason']),
        (DeceasedField.surname, deceasedData['surname']),
        (DeceasedField.firstName, deceasedData['firstname']),
        (DeceasedField.middleName, deceasedData['middle_name']),
        (DeceasedField.sex, deceasedData['gender']),
        (
          DeceasedField.country,
          pick([
            deceasedData['current_residence_country'],
            deceasedData['country_of_birth'],
          ]),
        ),
        (DeceasedField.state, deceasedData['current_residence_state']),
        (DeceasedField.lga, deceasedData['current_residence_lga']),
        (DeceasedField.address, deceasedData['current_address']),
        (DeceasedField.settlement, deceasedData['birth_settlement_type']),
        (DeceasedField.occupation, deceasedData['current_occupation']),
        (
          DeceasedField.dateOfDeath,
          dateOfDeath == null
              ? null
              : DateTime(
                  dateOfDeath.year,
                  dateOfDeath.month,
                  dateOfDeath.day,
                ).toIso8601String(),
        ),
        (
          DeceasedField.placeOfDeath,
          pick([
            data['deceased_place_of_death'],
            _placeOfDeathId(data['deceased_place_of_deathData']),
          ]),
        ),
        (
          DeceasedField.village,
          pick([data['deceased_village'], deceasedData['town_of_birth']]),
        ),
        (
          DeceasedField.ageAtDeath,
          pick([data['deceased_age_at_death'], deceasedData['age_at_death']]),
        ),
        (
          DeceasedField.nationality,
          pick([
            deceasedData['current_nationality'],
            deceasedData['origin_country'],
          ]),
        ),
        (DeceasedField.stateOfOrigin, deceasedData['origin_state']),
        (DeceasedField.lgaOfOrigin, deceasedData['origin_lga']),
        (DeceasedField.ethnicGroup, deceasedData['ethnic_group']),
        (DeceasedField.maritalStatus, deceasedData['current_marital_status']),
        (DeceasedField.literacy, deceasedData['current_literacy_level']),
        (DeceasedField.educationLevel, deceasedData['current_education_level']),
        (
          DeceasedField.certifiedByDoctor,
          pick([
            data['deceased_certified_by_doctor'],
            deceasedData['deceased_certified_by_doctor'],
          ]),
        ),
        (
          DeceasedField.causeOfDeath,
          pick([
            data['deceased_cause_of_death'],
            deceasedData['cause_of_death'],
          ]),
        ),
        (DeceasedField.registrationState, deceasedData['registration_state']),
        (DeceasedField.registrationLga, deceasedData['registration_lga']),
        (DeceasedField.registrationCenter, deceasedData['registration_center']),
      ])
        field: ?pick([value]),
    }),
    // A recorded NIN was verified when it was registered.
    deceasedNin,
  );
  final informantNin = pick([informantData['nin']]);
  final informant = InformantParticulars(
    FieldValues({
      for (final (field, value) in [
        (InformantField.nin, informantNin),
        (InformantField.surname, informantData['surname']),
        (InformantField.firstName, informantData['firstname']),
        (InformantField.middleName, informantData['middle_name']),
        (
          InformantField.relationship,
          pick([
            data['informant_relationship_with_deceased'],
            informantData['relationship_with_deceased'],
          ]),
        ),
        // Not recorded; the address below is the informant's own.
        (InformantField.sameAddress, DeathCodes.no),
        (InformantField.country, informantData['current_residence_country']),
        (InformantField.state, informantData['current_residence_state']),
        (InformantField.lga, informantData['current_residence_lga']),
        (InformantField.address, informantData['current_address']),
        (InformantField.settlement, informantData['birth_settlement_type']),
        (InformantField.phone, informantData['current_phone_number']),
      ])
        field: ?pick([value]),
    }),
    informantNin,
  );
  // The `raw…` fields hold the storage keys; the others are viewing URLs.
  final documents = data['rawSupportingDocument'] ?? data['SupportingDocument'];
  final byType = {for (final d in DeathDocument.values) d.apiType: d};
  final queried = outer['queried'];
  final id = pick([data['id']]);
  if (id == null) throw const FormatException('Expected an "id".');
  // Without `date_created`, the date of death dates the draft.
  final created =
      DateTime.tryParse(pick([data['date_created']]) ?? '') ??
      dateOfDeath ??
      DateTime.now();
  return DeathRecord(
    summary: BirthApplicationSummary(
      id: id,
      childName: _deceasedName(data),
      trackingId: pick([data['death_certificate_number']]) ?? id,
      submittedOn: created,
      status:
          _approvalStatuses[int.tryParse(
            pick([data['approved_status']]) ?? '',
          )] ??
          ApplicationStatus.values.asNameMap()[pick([
            data['status'],
          ])?.toLowerCase()] ??
          ApplicationStatus.pending,
    ),
    deceased: deceased,
    informant: informant,
    documentKeys: {
      if (documents is List<Object?>)
        for (final doc in documents.whereType<Map<String, Object?>>())
          if ((byType[doc['type']], pick([doc['file']])) case (
            final DeathDocument type,
            final String file,
          ))
            type: file,
    },
    signatureKey: pick([
      data['rawInformantSignature'],
      data['informant_signature'],
      informantData['signature'],
    ]),
    queryReason: pick([
      data['query_reason'],
      data['reason'],
      if (queried is Map<String, Object?>) queried['reason'],
    ]),
  );
}

/// The `PATCH /death-registration/update` body: the add body plus the
/// record's id, certificate number and query reason.
JsonMap deathUpdateToJson(
  DeathDraft draft, {
  required DeathReferenceData places,
  required Map<DeathDocument, String> documents,
  required String? signature,
}) {
  final queried = draft.queried;
  if (queried == null) {
    throw ArgumentError('Not a recorded registration.');
  }
  final body = deathToJson(
    draft,
    places: places,
    documents: documents,
    signature: signature,
  );
  final d = draft.deceased;
  int? number(DeceasedField field) => int.tryParse(d[field] ?? '');
  return {
    ...body,
    'id': int.tryParse(queried.recordId) ?? queried.recordId,
    'death_certificate_number': queried.certificateNumber,
    'no_nin_reason': d.applies(DeceasedField.noNinReason)
        ? d[DeceasedField.noNinReason]
        : null,
    'registration_state': number(DeceasedField.registrationState),
    'registration_lga': number(DeceasedField.registrationLga),
    'query_reason': queried.queryReason,
    // Only documents that have a file.
    'SupportingDocument': [
      for (final doc in body['SupportingDocument']! as List<Object?>)
        if (doc case {'file': final String _}) doc,
    ],
  };
}
