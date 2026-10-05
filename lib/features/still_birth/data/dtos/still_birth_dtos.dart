import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_draft.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_form.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_record.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_summary.dart';

// Shapes of the backend (NPC_ECRVS_API_V2, src/app/stillbirth).

/// `approved_status` codes, as Birth Registration reads them.
const _approvalStatuses = {
  0: ApplicationStatus.pending,
  1: ApplicationStatus.approved,
  2: ApplicationStatus.queried,
};

/// `GET /stillbirth/stats` answers with the total alone.
int countFromJson(Object? json) => switch (json) {
  final num total => total.toInt(),
  {'total': final num total} => total.toInt(),
  _ => throw const FormatException('Expected the total as a number.'),
};

/// `GET /stillbirth/list`; rows without a status are pending.
List<StillBirthSummary> registrationsFromJson(Object? json) {
  final rows = json.asJsonMap()['result'];
  if (rows is! List<Object?>) {
    throw const FormatException('Expected "result" to be a list.');
  }
  return [for (final row in rows) _summaryFromJson(row.asJsonMap())];
}

StillBirthSummary _summaryFromJson(JsonMap map, {String? id}) {
  final registeredOn = DateTime.tryParse(map.requireString('date_created'));
  if (registeredOn == null) {
    throw const FormatException('Expected "date_created" to be a date.');
  }
  final rowId = id ?? '${map['id']}';
  final approval = switch (map['approved_status']) {
    final num code => code.toInt(),
    final String code => int.tryParse(code),
    _ => null,
  };
  return StillBirthSummary(
    id: rowId,
    motherName: map.requireString('mother_fullname'),
    // Still births have no registration number; they go by their id.
    trackingId: map.optionalString('tracking_id') ?? rowId,
    registeredOn: registeredOn,
    status:
        _approvalStatuses[approval] ??
        ApplicationStatus.values.asNameMap()[map.optionalString('status')] ??
        ApplicationStatus.pending,
  );
}

/// The `POST /stillbirth/add` body. [signature] is the uploaded
/// signature's key. Address details are sent only for Nigeria.
JsonMap stillBirthToJson(StillBirthDraft draft, {required String signature}) {
  final d = draft.deceased;
  final m = draft.mother;
  final i = draft.informant;
  Object? number(String? value) =>
      value == null ? null : int.tryParse(value) ?? value;
  Object? mother(MotherField field) =>
      m.applies(field) ? number(m[field]) : null;
  Object? informant(InformantField field) =>
      i.applies(field) ? number(i[field]) : null;
  return {
    'birth_place': number(d[DeceasedField.placeOfOccurrence]),
    'deceased_sex': number(d[DeceasedField.sex]),
    'birth_type': number(d[DeceasedField.typeOfDelivery]),
    'deceased_date_of_delivery': d[DeceasedField.dateOfDelivery],
    'deceased_village': d[DeceasedField.village],
    'mother_fullname': m[MotherField.fullName],
    'mother_age': number(m[MotherField.age]),
    'mother_country': number(m[MotherField.country]),
    'mother_state_residence': mother(MotherField.state),
    'mother_lga': mother(MotherField.lga),
    'mother_settlement': mother(MotherField.settlement),
    'mother_street_name': m.applies(MotherField.address)
        ? m[MotherField.address]
        : null,
    'mother_nationality': number(m[MotherField.nationality]),
    'mother_state_of_origin': mother(MotherField.stateOfOrigin),
    'mother_ethnic_group': mother(MotherField.ethnicGroup),
    'informant_fullname': i[InformantField.fullName],
    'informant_relationship_with_mother': number(
      i[InformantField.relationship],
    ),
    'informant_country': number(i[InformantField.country]),
    'informant_state': informant(InformantField.state),
    'informant_lga': informant(InformantField.lga),
    'informant_street_name': i[InformantField.address],
    'informant_settlement': informant(InformantField.settlement),
    'informant_acknowledgement': signature,
  };
}

/// `POST /stillbirth/add` answers `{"success", "message", "item": {…the
/// record}}`; still births have no number, so the record's id.
String? addedFromJson(Object? json) => switch (json) {
  {'item': {'id': final Object id}} when id is num || id is String => '$id',
  _ => null,
};

/// `{"url": "https://…", "key": "…"}`
({Uri url, String key}) uploadTargetFromJson(Object? json) {
  final map = json.asJsonMap();
  final url = Uri.tryParse(map.requireString('url'));
  if (url == null || url.scheme != 'https') {
    throw const FormatException('Expected an HTTPS upload URL.');
  }
  return (url: url, key: map.requireString('key'));
}

/// `GET /stillbirth/{id}`: `{data}` without the record's own id ([id]).
StillBirthRecord stillBirthRecordFromJson(Object? json, {required String id}) {
  final outer = json.asJsonMap();
  final row = outer['data'] is Map<String, Object?>
      ? outer.requireMap('data')
      : outer;
  String? text(String key) => switch (row[key]) {
    null => null,
    final String value => value,
    final value => '$value',
  };
  final delivery = DateTime.tryParse(text('deceased_date_of_delivery') ?? '');
  var deceased = const DeceasedParticulars();
  for (final (field, key) in [
    (DeceasedField.placeOfOccurrence, 'birth_place'),
    (DeceasedField.village, 'deceased_village'),
    (DeceasedField.sex, 'deceased_sex'),
    (DeceasedField.typeOfDelivery, 'birth_type'),
  ]) {
    deceased = deceased.set(field, text(key));
  }
  if (delivery != null) {
    deceased = deceased.set(
      DeceasedField.dateOfDelivery,
      DateTime(delivery.year, delivery.month, delivery.day).toIso8601String(),
    );
  }
  // Not through `set`, which would clear what depends on each field.
  final mother = MotherParticulars(
    FieldValues({
      for (final (field, key) in [
        (MotherField.fullName, 'mother_fullname'),
        (MotherField.country, 'mother_country'),
        (MotherField.state, 'mother_state_residence'),
        (MotherField.lga, 'mother_lga'),
        (MotherField.address, 'mother_street_name'),
        (MotherField.settlement, 'mother_settlement'),
        (MotherField.age, 'mother_age'),
        (MotherField.nationality, 'mother_nationality'),
        (MotherField.stateOfOrigin, 'mother_state_of_origin'),
        (MotherField.ethnicGroup, 'mother_ethnic_group'),
      ])
        field: ?text(key),
    }),
  );
  final informant = InformantParticulars(
    FieldValues({
      for (final (field, key) in [
        (InformantField.relationship, 'informant_relationship_with_mother'),
        (InformantField.fullName, 'informant_fullname'),
        (InformantField.country, 'informant_country'),
        (InformantField.state, 'informant_state'),
        (InformantField.lga, 'informant_lga'),
        (InformantField.address, 'informant_street_name'),
        (InformantField.settlement, 'informant_settlement'),
        (InformantField.signature, 'informant_acknowledgement'),
      ])
        field: ?text(key),
    }),
  );
  return StillBirthRecord(
    summary: _summaryFromJson(row, id: id),
    deceased: deceased,
    mother: mother,
    informant: informant,
  );
}
