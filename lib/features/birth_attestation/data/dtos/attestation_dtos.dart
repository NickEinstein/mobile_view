import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';

/// Storage keys of the files uploaded before sending an application.
typedef AttestationUploads = ({
  String? face,
  Map<AttestationDocument, String> documents,
});

/// The affidavit's document type.
const _affidavitType = 'affidavit';

/// Ids go as numbers; a blank one as null.
int? _number(String? value) => value == null ? null : int.tryParse(value);

/// A date goes as UTC midnight, as the API stores it.
String? _apiDate(String? formDate) {
  final date = DateTime.tryParse(formDate ?? '');
  return date == null
      ? null
      : DateTime.utc(date.year, date.month, date.day).toIso8601String();
}

String _mimeType(String key) =>
    key.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

/// `SupportingDocument`: the affidavit.
List<JsonMap> _supportingDocuments(String? affidavitKey) => [
  if (affidavitKey != null)
    {
      'type': _affidavitType,
      'file': affidavitKey,
      'mimeType': _mimeType(affidavitKey),
    },
];

/// The application for `/birth-attestation/add` (with a NIN) or
/// `/self-attestation/no-nin`, which name some keys differently.
JsonMap attestationToJson(
  AttestationDraft draft, {
  required String paymentReference,
  required AttestationReferenceData places,
  required AttestationUploads uploads,
}) {
  final withNin = draft.ninRecord != null;
  final a = draft.applicant;
  final b = draft.additional;
  final registrationState = b[AdditionalField.registrationState];
  final stateCode = places.stateCode(registrationState);
  final lgaCode = places.lgaCode(
    registrationState,
    b[AdditionalField.registrationLga],
  );
  return {
    'registration_center': _number(b[AdditionalField.registrationCenter]),
    if (withNin) ...{
      'reference': paymentReference,
      'state_code': stateCode,
      'lga_code': lgaCode,
    } else ...{
      'payment_reference': paymentReference,
      'State_Code': stateCode,
      'Lga_Code': lgaCode,
    },
    'surname': a[ApplicantField.surname],
    'firstname': a[ApplicantField.firstName],
    'middlename': a[ApplicantField.middleName],
    'sex': _number(a[ApplicantField.sex]),
    'date_of_birth': _apiDate(a[ApplicantField.dateOfBirth]),
    'place_of_birth': _number(b[AdditionalField.placeOfBirth]),
    'lga_of_birth': _number(b[AdditionalField.lgaOfBirth]),
    'state_of_birth': _number(b[AdditionalField.stateOfBirth]),
    'country_of_birth': int.parse(ReferenceData.nigeria),
    'town_of_origin': a[ApplicantField.townOfOrigin],
    'lga_of_origin': _number(a[ApplicantField.lgaOfOrigin]),
    'town_of_birth': b[AdditionalField.localityOfBirth],
    'state_of_origin': _number(a[ApplicantField.stateOfOrigin]),
    'residence_address': b[AdditionalField.currentAddress],
    'highest_education': _number(b[AdditionalField.educationLevel]),
    'occupation': _number(b[AdditionalField.occupation]),
    'work_address': b[AdditionalField.workAddress],
    ..._parentToJson(draft, Parent.father, uploads),
    ..._parentToJson(draft, Parent.mother, uploads),
    'request_reason': _number(b[AdditionalField.requestReason]),
    'request_required_for': b[AdditionalField.requiredFor],
    // With a NIN the request address is sent as the
    // requester's name and the work address as theirs.
    'requester_name': withNin ? b[AdditionalField.requesterAddress] : null,
    'requester_address': withNin
        ? b[AdditionalField.workAddress]
        : b[AdditionalField.requesterAddress],
    'applicant_phone': a[ApplicantField.phone],
    'applicant_email': a[ApplicantField.email],
    'marital_status': _number(a[ApplicantField.maritalStatus]),
    'id_type': _number(a[ApplicantField.idType]),
    'id_number': a[ApplicantField.idNumber],
    'face': uploads.face,
    if (withNin) 'affidavit': null,
    'nin': draft.ninRecord?.nin,
    'SupportingDocument': _supportingDocuments(
      uploads.documents[AttestationDocument.affidavit],
    ),
  };
}

JsonMap _parentToJson(
  AttestationDraft draft,
  Parent parent,
  AttestationUploads uploads,
) {
  final info = draft.parent(parent);
  final prefix = parent.name;
  return {
    '${prefix}_surname': info[ParentInfoField.surname],
    '${prefix}_firstname': info[ParentInfoField.firstName],
    if (parent == Parent.mother)
      'mother_maiden_name': info[ParentInfoField.maidenName],
    '${prefix}_town': info[ParentInfoField.town],
    '${prefix}_lga': _number(info[ParentInfoField.lgaOfOrigin]),
    '${prefix}_state': _number(info[ParentInfoField.stateOfOrigin]),
    '${prefix}_nationality': _number(info[ParentInfoField.nationality]),
    // Only a parent who isn't Nigerian gives a passport.
    '${prefix}_passport': info.needsPassport
        ? uploads.documents[parent.passport]
        : null,
  };
}

/// A queried record's correction for `PATCH /birth-attestation/update`.
JsonMap attestationUpdateToJson(
  AttestationDraft draft, {
  required AttestationUploads uploads,
}) {
  final queried = draft.queried!;
  final a = draft.applicant;
  final b = draft.additional;
  String? key(AttestationDocument document) =>
      uploads.documents[document] ?? queried.documentKeys[document];
  JsonMap parent(Parent parent) {
    final info = draft.parent(parent);
    final prefix = parent.name;
    return {
      '${prefix}_firstname': info[ParentInfoField.firstName],
      '${prefix}_surname': info[ParentInfoField.surname],
      if (parent == Parent.mother)
        'mother_maiden_name': info[ParentInfoField.maidenName],
      '${prefix}_nationality': _number(info[ParentInfoField.nationality]),
      '${prefix}_state': _number(info[ParentInfoField.stateOfOrigin]),
      '${prefix}_lga': _number(info[ParentInfoField.lgaOfOrigin]),
      '${prefix}_town': info[ParentInfoField.town],
      '${prefix}_passport': info.needsPassport ? key(parent.passport) : null,
    };
  }

  return {
    'id': _number(queried.recordId),
    'surname': a[ApplicantField.surname],
    'firstname': a[ApplicantField.firstName],
    'middlename': a[ApplicantField.middleName],
    'sex': _number(a[ApplicantField.sex]),
    'date_of_birth': _apiDate(a[ApplicantField.dateOfBirth]),
    'nin': queried.nin,
    'reference': queried.certificateNumber,
    'marital_status': _number(a[ApplicantField.maritalStatus]),
    'place_of_birth': _number(b[AdditionalField.placeOfBirth]),
    'state_of_birth': _number(b[AdditionalField.stateOfBirth]),
    'lga_of_birth': _number(b[AdditionalField.lgaOfBirth]),
    'country_of_birth': int.parse(ReferenceData.nigeria),
    'town_of_origin': a[ApplicantField.townOfOrigin],
    'lga_of_origin': _number(a[ApplicantField.lgaOfOrigin]),
    'state_of_origin': _number(a[ApplicantField.stateOfOrigin]),
    'residence_address': b[AdditionalField.currentAddress],
    'highest_education': _number(b[AdditionalField.educationLevel]),
    'occupation': _number(b[AdditionalField.occupation]),
    'request_reason': _number(b[AdditionalField.requestReason]),
    ...parent(Parent.father),
    ...parent(Parent.mother),
    'SupportingDocument': _supportingDocuments(
      key(AttestationDocument.affidavit),
    ),
  };
}

/// The attestation number, from either submit endpoint, if given.
String? attestationNumberFromJson(Object? json) {
  final map = json is Map<String, Object?> ? json : const <String, Object?>{};
  return _text(_mapOrEmpty(map['item'])['attestation_number']) ??
      _text(map['attestationNumber']);
}

/// Ids and numbers come as JSON numbers or numeric strings; the form
/// keeps text.
String? _text(Object? value) => switch (value) {
  final String text when text.trim().isNotEmpty => text.trim(),
  final num number => '$number',
  _ => null,
};

JsonMap _mapOrEmpty(Object? value) =>
    value is Map<String, Object?> ? value : const {};

/// `approval_status` codes, as Birth Registration reads them.
const _approvalStatuses = {
  0: ApplicationStatus.pending,
  1: ApplicationStatus.approved,
  2: ApplicationStatus.queried,
};

/// `GET /birth-attestation/list`. Rows carry no status (the [status] asked
/// for is used) and are keyed by attestation number.
List<BirthApplicationSummary> attestationSummariesFromJson(
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
  JsonMap row, {
  required ApplicationStatus status,
  bool keyedById = false,
}) {
  final id = _text(row['id']);
  final number = _text(row['attestation_number']) ?? id;
  if (id == null || number == null) {
    throw const FormatException('Expected "id" and "attestation_number".');
  }
  final submittedOn = DateTime.tryParse(_text(row['date_created']) ?? '');
  if (submittedOn == null) {
    throw const FormatException('Expected "date_created" to be a date.');
  }
  final person = _mapOrEmpty(row['personData']);
  final name = [
    _text(person['surname']),
    _text(person['firstname']),
    _text(person['middle_name']),
  ].nonNulls.join(' ');
  return BirthApplicationSummary(
    id: keyedById ? id : number,
    childName: name.isEmpty ? number : name,
    trackingId: number,
    submittedOn: submittedOn,
    status: status,
  );
}

/// An API date as the form keeps it.
String? _formDate(Object? value) {
  final date = DateTime.tryParse(_text(value) ?? '');
  return date == null
      ? null
      : DateTime(date.year, date.month, date.day).toIso8601String();
}

FieldValues<F> _values<F extends Enum>(Map<F, String?> values) => FieldValues({
  for (final MapEntry(:key, :value) in values.entries) key: ?value,
});

/// `GET /birth-attestation/cert/{number}`: `{data, reason}`. The summary
/// keeps the record's own id for a correction.
AttestationRecord attestationRecordFromJson(Object? json) {
  final root = json.asJsonMap();
  final data = root.requireMap('data');
  final person = _mapOrEmpty(data['personData']);
  final status =
      _approvalStatuses[int.tryParse(_text(data['approval_status']) ?? '')] ??
      ApplicationStatus.pending;
  return AttestationRecord(
    summary: _summaryFromJson(data, status: status, keyedById: true),
    applicant: ApplicantParticulars(
      _values({
        ApplicantField.surname: _text(person['surname']),
        ApplicantField.firstName: _text(person['firstname']),
        ApplicantField.middleName: _text(person['middle_name']),
        ApplicantField.sex:
            _text(_mapOrEmpty(person['genderData'])['Gender_ID']) ??
            _text(person['gender']),
        ApplicantField.dateOfBirth: _formDate(person['birth_date']),
        ApplicantField.maritalStatus: _text(data['marital_status']),
        ApplicantField.stateOfOrigin: _text(person['origin_state']),
        ApplicantField.lgaOfOrigin: _text(person['origin_lga']),
        ApplicantField.townOfOrigin: _text(person['town_of_origin']),
        ApplicantField.idType: _text(data['id_type']),
        ApplicantField.idNumber: _text(data['id_number']),
        ApplicantField.email: _text(data['applicant_email']),
        ApplicantField.phone: _text(data['applicant_phone']),
      }),
    ),
    additional: AdditionalInformation(
      _values({
        AdditionalField.placeOfBirth: _text(data['place_of_birth']),
        AdditionalField.stateOfBirth: _text(person['birth_state']),
        AdditionalField.lgaOfBirth: _text(person['birth_lga']),
        AdditionalField.localityOfBirth: _text(person['town_of_birth']),
        AdditionalField.currentAddress: _text(person['current_address']),
        AdditionalField.educationLevel: _text(
          person['current_education_level'],
        ),
        AdditionalField.occupation: _text(person['current_occupation']),
        AdditionalField.workAddress: _text(person['work_address']),
        AdditionalField.requestReason: _text(data['request_reason']),
        AdditionalField.requiredFor: _text(data['request_required_for']),
        AdditionalField.requesterAddress: _text(data['requester_address']),
      }),
    ),
    mother: _parentFromJson(data, 'mother'),
    father: _parentFromJson(data, 'father'),
    nin: _text(data['nin']) ?? _text(person['nin']),
    documentKeys: {
      // The `raw…` fields hold the storage keys; the others are viewing
      // URLs.
      AttestationDocument.affidavit: ?_affidavitKey(
        data['rawSupportingDocument'],
      ),
      AttestationDocument.motherPassport: ?_text(data['rawMotherPassport']),
      AttestationDocument.fatherPassport: ?_text(data['rawFatherPassport']),
    },
    hasFace: _text(data['face']) != null,
    queryReason: _text(_mapOrEmpty(root['reason'])['reason']),
  );
}

/// The affidavit's key in a `SupportingDocument` list.
String? _affidavitKey(Object? documents) {
  if (documents is! List<Object?>) return null;
  for (final document in documents) {
    final map = _mapOrEmpty(document);
    if (map['type'] == _affidavitType) return _text(map['file']);
  }
  return null;
}

ParentInformation _parentFromJson(JsonMap data, String prefix) =>
    ParentInformation(
      _values({
        ParentInfoField.surname: _text(data['${prefix}_surname']),
        ParentInfoField.firstName: _text(data['${prefix}_firstname']),
        ParentInfoField.maidenName: _text(data['${prefix}_maiden_name']),
        ParentInfoField.nationality: _text(data['${prefix}_nationality']),
        ParentInfoField.stateOfOrigin: _text(data['${prefix}_state']),
        ParentInfoField.lgaOfOrigin: _text(data['${prefix}_lga']),
        ParentInfoField.town: _text(data['${prefix}_town']),
      }),
    );
