import 'dart:convert';
import 'dart:typed_data';

import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/attestation_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_options.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';

/// `GET /certificate-reissuance-assisted/<kind>-stats`:
/// `{"Total", "Pending", "Approved", "Queried"}`. A missing count is 0.
ReissuanceCounts countsFromJson(Object? json) {
  final map = json.asJsonMap();
  int count(String key) => switch (map[key]) {
    final int value => value,
    final String value => int.tryParse(value) ?? 0,
    _ => 0,
  };
  return ReissuanceCounts(
    total: count('Total'),
    pending: count('Pending'),
    approved: count('Approved'),
    queried: count('Queried'),
  );
}

/// `GET /certificate-reissuance-assisted/<kind>-list`.
List<ReissuanceSummary> requestsFromJson(Object? json) {
  final rows = json.asJsonMap()['result'];
  if (rows is! List<Object?>) {
    throw const FormatException('Expected "result" to be a list.');
  }
  return [for (final row in rows) _summaryFromJson(row.asJsonMap())];
}

ReissuanceSummary _summaryFromJson(JsonMap row) {
  final name = [
    row.optionalString('surname'),
    row.optionalString('firstName'),
    row.optionalString('middleName'),
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
  // The API sends `dateCreated`; older rows have `date_created`.
  final created = row['dateCreated'] ?? row['date_created'];
  return ReissuanceSummary(
    id: '${row['id']}',
    name: name,
    reference: row.optionalString('reference') ?? '',
    status: switch (row['approvedStatus']) {
      1 || '1' => ReissuanceStatus.approved,
      2 || '2' => ReissuanceStatus.queried,
      _ => ReissuanceStatus.pending,
    },
    createdOn: created is String ? DateTime.tryParse(created) : null,
  );
}

/// `GET /option/country`: `[{"Country_Code", "Country_Name",
/// "Country_Nationality_Name"}]`, as countries and as nationalities.
({List<Option> countries, List<Option> nationalities}) countriesFromJson(
  Object? json,
) => (
  countries: _sorted(
    _options(
      json,
      id: 'Country_Code',
      label: 'Country_Name',
      what: 'countries',
    ),
  ),
  nationalities: _sorted(
    _options(
      json,
      id: 'Country_Code',
      label: 'Country_Nationality_Name',
      what: 'countries',
    ),
  ),
);

/// `GET /option/states/{country}`: `[{"State_ID", "State_Name"}]`.
List<Option> statesFromJson(Object? json) => _sorted(
  _options(json, id: 'State_ID', label: 'State_Name', what: 'states'),
);

/// `GET /option/lga/{state}`: `[{"LGA_Code", "LGA_Name"}]`.
List<Option> lgasFromJson(Object? json) =>
    _sorted(_options(json, id: 'LGA_Code', label: 'LGA_Name', what: 'LGAs'));

/// `GET /option/registration-centres`: `[{"Reg_Center_id",
/// "Reg_Center_Name", "LGA_ID"}]`; `LGA_ID` is an LGA's `LGA_Code`.
List<RegistrationCentre> centresFromJson(Object? json) {
  if (json is! List<Object?>) {
    throw const FormatException('Expected a list of centres.');
  }
  return [
    for (final item in json)
      if (item.asJsonMap() case final map)
        if ((
              _text(map['Reg_Center_id']),
              _text(map['Reg_Center_Name']),
              _text(map['LGA_ID']),
            )
            case (final id?, final label?, final lgaId?))
          RegistrationCentre(option: Option(id, label), lgaId: lgaId),
  ];
}

List<Option> _options(
  Object? json, {
  required String id,
  required String label,
  required String what,
}) {
  if (json is! List<Object?>) {
    throw FormatException('Expected "$what" to be a list.');
  }
  return [
    for (final item in json)
      if (item.asJsonMap() case final map)
        if ((_text(map[id]), _text(map[label])) case (final id?, final label?))
          Option(id, label),
  ];
}

/// Alphabetical.
List<Option> _sorted(List<Option> options) =>
    [...options]..sort((a, b) => a.label.compareTo(b.label));

/// The API's ids are numbers; the form keeps text.
String? _text(Object? value) {
  final text = switch (value) {
    final String text => text.trim(),
    final num number => '$number',
    _ => '',
  };
  return text.isEmpty ? null : text;
}

/// Storage keys of the files sent with a birth reissuance.
typedef UploadedFiles = ({
  String certificate,
  String face,
  String signature,
  ({String key, String mimeType})? document,
});

/// `POST …/add-birth-reg` (with the request's `id`, `PATCH
/// …/update-birth-reg`).
Map<String, Object?> birthReissuanceToJson(
  CertificateFacts certificate,
  BirthReissuanceForm form, {
  required UploadedFiles files,
  required String paymentReference,
  required String email,
  required DateTime today,
}) {
  final child = form.child;
  final dateOfBirth = child.dateOfBirth!;
  int? id(String? value) => value == null ? null : int.tryParse(value);
  Map<String, Object?> parent(String prefix, ParentParticulars p) => {
    '${prefix}FirstName': p[ParentDetail.firstName],
    '${prefix}Surname': p[ParentDetail.surname],
    if (prefix == 'mother') 'motherMaidenName': p[ParentDetail.maidenName],
    '${prefix}CountryOfResidence': id(p[ParentDetail.country]),
    '${prefix}StateOfResidence': id(p[ParentDetail.state]),
    '${prefix}LgaOfResidence': id(p[ParentDetail.lga]),
    '${prefix}ResidenceAddress': p[ParentDetail.address],
    '${prefix}AgeAtBirth': id(p[ParentDetail.age]),
    '${prefix}MaritalStatus': id(p[ParentDetail.maritalStatus]),
    '${prefix}Nationality': id(p[ParentDetail.nationality]),
    '${prefix}OriginState': id(p[ParentDetail.stateOfOrigin]),
    '${prefix}OriginLga': id(p[ParentDetail.lgaOfOrigin]),
    '${prefix}EthnicGroup': id(p[ParentDetail.ethnicGroup]),
    '${prefix}LiteracyLevel': id(p[ParentDetail.literacy]),
    '${prefix}EducationLevel': id(p[ParentDetail.educationLevel]),
    '${prefix}Occupation': id(p[ParentDetail.occupation]),
    '${prefix}PhoneNumber': p[ParentDetail.phone],
  };

  return {
    'certType': certificate.kind.certType,
    'nin': certificate.nin,
    'paymentReference': paymentReference,
    'legacyCertNumber': certificate.number,
    'legacyCertLink': files.certificate,
    'legacyCertIssuedDate': _ymd(certificate.issuedOn),
    'childFirstName': child[ChildField.firstName],
    'childMiddleName': child[ChildField.middleName],
    'childSurname': child[ChildField.surname],
    'childSex': id(child[ChildField.sex]),
    'childAge': _yearsBetween(dateOfBirth, today),
    'childFace': files.face,
    'dateOfBirth': _ymd(dateOfBirth),
    'placeOfBirth': id(child[ChildField.placeOfOccurrence]),
    'birthType': id(child[ChildField.typeOfBirth]),
    'birthOrder': id(child[ChildField.birthOrder]),
    'localityOfBirth': id(child[ChildField.locality]),
    'stateOfBirth': id(child[ChildField.stateOfBirth]),
    'lgaOfBirth': id(child[ChildField.lgaOfBirth]),
    'townOfBirth': child[ChildField.townOfBirth],
    'townOfOrigin': child[ChildField.townOfOrigin],
    ...parent('mother', form.mother),
    ...parent('father', form.father),
    // The API needs at least one entry; without a document an empty one
    // is sent.
    'supportingDocument': [
      switch (files.document) {
        final document? => {
          'type': 'support-document',
          'file': document.key,
          'mimeType': document.mimeType,
        },
        null => <String, Object?>{},
      },
    ],
    'signature': files.signature,
    'regCenter': id(child[ChildField.registrationCenter]),
    'email': email,
  };
}

/// `2016-03-12`.
String _ymd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Whole years.
int _yearsBetween(DateTime from, DateTime to) {
  var years = to.year - from.year;
  if (to.month < from.month || (to.month == from.month && to.day < from.day)) {
    years--;
  }
  return years;
}

/// `GET /file-upload-url/{name}`: `{"url", "key"}`. The URL must be HTTPS.
({Uri url, String key}) uploadTargetFromJson(Object? json) {
  final map = json.asJsonMap();
  final url = Uri.tryParse(map.requireString('url'));
  if (url == null || url.scheme != 'https') {
    throw const FormatException('Expected an HTTPS upload URL.');
  }
  return (url: url, key: map.requireString('key'));
}

/// The server's confirmation, if any.
String? submittedFromJson(Object? json) =>
    json is Map ? json.asJsonMap().optionalString('message') : null;

/// `GET …/single-birth-reg/:id`: `{data, queried}`, with `raw*` file keys.
BirthReissuanceRecord birthRecordFromJson(Object? json) {
  final root = json.asJsonMap();
  final data = root.requireMap('data');
  String? text(Object? value) => _text(value);
  String? raw(String rawKey, String key) =>
      text(data[rawKey]) ?? text(data[key]);
  DateTime? date(String key) => switch (text(data[key])) {
    final value? => DateTime.tryParse(value),
    null => null,
  };
  final centre = data['regCenterData'];
  final centreLga = centre is Map ? centre['LGAs'] : null;

  var child = const ChildParticulars();
  for (final (field, key) in [
    (ChildField.surname, 'childSurname'),
    (ChildField.firstName, 'childFirstName'),
    (ChildField.middleName, 'childMiddleName'),
    (ChildField.typeOfBirth, 'birthType'),
    (ChildField.birthOrder, 'birthOrder'),
    (ChildField.sex, 'childSex'),
    (ChildField.placeOfOccurrence, 'placeOfBirth'),
    (ChildField.stateOfBirth, 'stateOfBirth'),
    (ChildField.lgaOfBirth, 'lgaOfBirth'),
    (ChildField.townOfBirth, 'townOfBirth'),
    (ChildField.townOfOrigin, 'townOfOrigin'),
    (ChildField.locality, 'localityOfBirth'),
    (ChildField.registrationCenter, 'regCenter'),
  ]) {
    // Not through [ChildParticulars.set]: a state would clear its LGA.
    child = ChildParticulars(child.values.set(field, text(data[key])));
  }
  if (date('dateOfBirth') case final born?) {
    child = ChildParticulars(
      child.values.set(
        ChildField.dateOfBirth,
        DateTime(born.year, born.month, born.day).toIso8601String(),
      ),
    );
  }
  if (centreLga is Map) {
    child = ChildParticulars(
      child.values
          .set(ChildField.registrationState, text(centreLga['State_ID']))
          .set(ChildField.registrationLga, text(centreLga['LGA_ID'])),
    );
  }

  ParentParticulars parent(String prefix) {
    var values = const ParentParticulars().values;
    for (final (field, key) in [
      (ParentDetail.surname, 'Surname'),
      (ParentDetail.firstName, 'FirstName'),
      (ParentDetail.maidenName, 'MaidenName'),
      (ParentDetail.country, 'CountryOfResidence'),
      (ParentDetail.state, 'StateOfResidence'),
      (ParentDetail.lga, 'LgaOfResidence'),
      (ParentDetail.address, 'ResidenceAddress'),
      (ParentDetail.age, 'AgeAtBirth'),
      (ParentDetail.maritalStatus, 'MaritalStatus'),
      (ParentDetail.nationality, 'Nationality'),
      (ParentDetail.stateOfOrigin, 'OriginState'),
      (ParentDetail.lgaOfOrigin, 'OriginLga'),
      (ParentDetail.ethnicGroup, 'EthnicGroup'),
      (ParentDetail.literacy, 'LiteracyLevel'),
      (ParentDetail.educationLevel, 'EducationLevel'),
      (ParentDetail.occupation, 'Occupation'),
      (ParentDetail.phone, 'PhoneNumber'),
    ]) {
      values = values.set(field, text(data['$prefix$key']));
    }
    return ParentParticulars(values);
  }

  KeptFile? document;
  final documents = data['rawSupportingDocument'];
  if (documents is List) {
    for (final item in documents) {
      if (item is! Map) continue;
      final map = item.asJsonMap();
      if (text(map['file']) case final key?) {
        document = KeptFile(
          key: key,
          mimeType: text(map['mimeType']) ?? 'image/jpeg',
        );
        break;
      }
    }
  }
  final signature = raw('rawSignature', 'signature');
  final queried = root['queried'];
  final face = Uri.tryParse(text(data['face']) ?? '');

  return BirthReissuanceRecord(
    id: '${data['id']}',
    status: switch (text(data['approvedStatus'])) {
      '1' => ReissuanceStatus.approved,
      '2' => ReissuanceStatus.queried,
      _ => ReissuanceStatus.pending,
    },
    reference: text(data['reference']) ?? '',
    nin: text(data['nin']) ?? '',
    certificateNumber: text(data['legacyCertNumber']) ?? '',
    issuedOn: date('legacyCertIssuedDate') ?? DateTime(1900),
    certificateKey: raw('rawLegacyCertLink', 'legacyCertLink') ?? '',
    form: BirthReissuanceForm(
      step: BirthReissuanceStep.review,
      child: child,
      mother: parent('mother'),
      father: parent('father'),
      keptDocument: document,
      keptSignature: signature == null
          ? null
          : KeptFile(key: signature, mimeType: 'image/png'),
    ),
    faceKey: raw('rawChildFace', 'childFace'),
    faceUrl: face != null && face.scheme == 'https' ? face : null,
    query: queried is Map
        ? ReissuanceQuery(
            title: text(queried['title']),
            reason: text(queried['reason']),
          )
        : null,
    createdOn: date('dateCreated'),
  );
}

/// A printed certificate: base64 JPEG, as text or as `{"data": "…"}`.
Uint8List certificateImageFromJson(Object? json) {
  final encoded = switch (json) {
    final String text => text,
    final Map<Object?, Object?> map when map['data'] is String =>
      map['data']! as String,
    _ => throw const FormatException('Expected a base64 image.'),
  };
  final comma = encoded.indexOf(',');
  return base64Decode(
    comma < 0 ? encoded.trim() : encoded.substring(comma + 1),
  );
}

/// Storage keys of the files sent with an attestation reissuance.
typedef AttestationFiles = ({
  String certificate,
  String face,
  String signature,
  ({String key, String mimeType}) affidavit,
});

/// `POST …/add-birth-attest` (with the request's `id`, `PATCH
/// …/update-birth-attest`). The town of origin goes as `applicantTown`,
/// the locality of birth as `townOfBirth`.
Map<String, Object?> attestationReissuanceToJson(
  CertificateFacts certificate,
  AttestationReissuanceForm form, {
  required AttestationFiles files,
  required String paymentReference,
}) {
  final applicant = form.applicant;
  final additional = form.additional;
  int? id(String? value) => value == null ? null : int.tryParse(value);
  String name(AttestationParent parent, {required bool mother}) => [
    parent[AttestationParentDetail.surname],
    parent[AttestationParentDetail.firstName],
    if (mother) parent[AttestationParentDetail.maidenName],
  ].whereType<String>().join(' ');

  return {
    'certType': certificate.kind.certType,
    'nin': certificate.nin,
    'paymentReference': paymentReference,
    'legacyCertNumber': certificate.number,
    'legacyCertLink': files.certificate,
    'legacyCertIssuedDate': _ymd(certificate.issuedOn),
    'applicantFirstName': applicant[ApplicantDetail.firstName],
    'applicantMiddleName': applicant[ApplicantDetail.middleName],
    'applicantSurname': applicant[ApplicantDetail.surname],
    'applicantSex': id(applicant[ApplicantDetail.sex]),
    'applicantDateOfBirth': switch (applicant.dateOfBirth) {
      final born? => _ymd(born),
      null => null,
    },
    'applicantMaritalStatus': id(applicant[ApplicantDetail.maritalStatus]),
    'applicantOriginState': id(applicant[ApplicantDetail.stateOfOrigin]),
    'applicantOriginLga': id(applicant[ApplicantDetail.lgaOfOrigin]),
    'applicantRegCenter': id(additional[AdditionalDetail.registrationCenter]),
    'applicantTown': applicant[ApplicantDetail.town],
    'applicantPhone': applicant[ApplicantDetail.phone],
    'applicantEmail': applicant[ApplicantDetail.email],
    'idType': id(applicant[ApplicantDetail.idType]),
    'idNumber': applicant[ApplicantDetail.idNumber],
    'placeOfBirth': id(additional[AdditionalDetail.placeOfBirth]),
    'birthType': id(additional[AdditionalDetail.typeOfBirth]),
    'stateOfBirth': id(additional[AdditionalDetail.stateOfBirth]),
    'lgaOfBirth': id(additional[AdditionalDetail.lgaOfBirth]),
    'townOfBirth': additional[AdditionalDetail.townOfBirth],
    'currentAddress': additional[AdditionalDetail.currentAddress],
    'educationLevel': id(additional[AdditionalDetail.educationLevel]),
    'occupation': id(additional[AdditionalDetail.occupation]),
    'requestReason': id(additional[AdditionalDetail.requestReason]),
    'requestRequiredFor': additional[AdditionalDetail.requiredFor],
    'workAddress': additional[AdditionalDetail.workAddress],
    'requesterAddress': additional[AdditionalDetail.requesterAddress],
    'fatherName': name(form.father, mother: false),
    'fatherState': id(form.father[AttestationParentDetail.state]),
    'fatherLga': id(form.father[AttestationParentDetail.lga]),
    'fatherTown': form.father[AttestationParentDetail.town],
    'motherName': name(form.mother, mother: true),
    'motherState': id(form.mother[AttestationParentDetail.state]),
    'motherLga': id(form.mother[AttestationParentDetail.lga]),
    'motherTown': form.mother[AttestationParentDetail.town],
    'supportingDocument': [
      {
        'type': 'court-affidavit',
        'file': files.affidavit.key,
        'mimeType': files.affidavit.mimeType,
      },
    ],
    'signature': files.signature,
    'face': files.face,
  };
}

/// `GET …/single-birth-attest/:id`. Parents' names come back joined
/// ("Surname First [Maiden]").
AttestationReissuanceRecord attestationRecordFromJson(Object? json) {
  final root = json.asJsonMap();
  final data = root.requireMap('data');
  String? text(Object? value) => _text(value);
  DateTime? date(String key) => switch (text(data[key])) {
    final value? => DateTime.tryParse(value),
    null => null,
  };
  final centre = data['applicantRegCenterData'];
  final centreLga = centre is Map ? centre['LGAs'] : null;

  var applicant = const ApplicantParticulars().values;
  for (final (field, key) in [
    (ApplicantDetail.surname, 'applicantSurname'),
    (ApplicantDetail.firstName, 'applicantFirstName'),
    (ApplicantDetail.middleName, 'applicantMiddleName'),
    (ApplicantDetail.sex, 'applicantSex'),
    (ApplicantDetail.maritalStatus, 'applicantMaritalStatus'),
    (ApplicantDetail.stateOfOrigin, 'applicantOriginState'),
    (ApplicantDetail.lgaOfOrigin, 'applicantOriginLga'),
    (ApplicantDetail.town, 'applicantTown'),
    (ApplicantDetail.idType, 'idType'),
    (ApplicantDetail.idNumber, 'idNumber'),
    (ApplicantDetail.email, 'applicantEmail'),
    (ApplicantDetail.phone, 'applicantPhone'),
  ]) {
    applicant = applicant.set(field, text(data[key]));
  }
  if (date('applicantDateOfBirth') case final born?) {
    applicant = applicant.set(
      ApplicantDetail.dateOfBirth,
      DateTime(born.year, born.month, born.day).toIso8601String(),
    );
  }

  var additional = const AdditionalInformation().values;
  for (final (field, key) in [
    (AdditionalDetail.placeOfBirth, 'placeOfBirth'),
    (AdditionalDetail.typeOfBirth, 'birthType'),
    (AdditionalDetail.stateOfBirth, 'stateOfBirth'),
    (AdditionalDetail.lgaOfBirth, 'lgaOfBirth'),
    (AdditionalDetail.townOfBirth, 'townOfBirth'),
    (AdditionalDetail.registrationCenter, 'applicantRegCenter'),
    (AdditionalDetail.currentAddress, 'currentAddress'),
    (AdditionalDetail.educationLevel, 'educationLevel'),
    (AdditionalDetail.occupation, 'occupation'),
    (AdditionalDetail.workAddress, 'workAddress'),
    (AdditionalDetail.requestReason, 'requestReason'),
    (AdditionalDetail.requiredFor, 'requestRequiredFor'),
    (AdditionalDetail.requesterAddress, 'requesterAddress'),
  ]) {
    additional = additional.set(field, text(data[key]));
  }
  if (centreLga is Map) {
    additional = additional
        .set(AdditionalDetail.registrationState, text(centreLga['State_ID']))
        .set(AdditionalDetail.registrationLga, text(centreLga['LGA_ID']));
  }

  // Names are stored joined, surname first.
  AttestationParent parent(String prefix, {required bool mother}) {
    final parts = (text(data['${prefix}Name']) ?? '')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty && part != 'undefined')
        .toList();
    String? at(int i) => i < parts.length ? parts[i] : null;
    var values = const AttestationParent().values
        .set(AttestationParentDetail.surname, at(0))
        .set(
          AttestationParentDetail.firstName,
          mother
              ? at(1)
              : (parts.length > 1 ? parts.sublist(1).join(' ') : null),
        );
    if (mother) {
      values = values.set(
        AttestationParentDetail.maidenName,
        parts.length > 2 ? parts.sublist(2).join(' ') : null,
      );
    }
    return AttestationParent(
      values
          .set(AttestationParentDetail.state, text(data['${prefix}State']))
          .set(AttestationParentDetail.lga, text(data['${prefix}Lga']))
          .set(AttestationParentDetail.town, text(data['${prefix}Town'])),
    );
  }

  KeptFile? affidavit;
  final documents = data['rawSupportingDocument'];
  if (documents is List) {
    for (final item in documents) {
      if (item is! Map) continue;
      final map = item.asJsonMap();
      if (text(map['file']) case final key?) {
        affidavit = KeptFile(
          key: key,
          mimeType: text(map['mimeType']) ?? 'image/jpeg',
        );
        break;
      }
    }
  }
  final signature = text(data['rawSignature']) ?? text(data['signature']);
  final queried = root['queried'];
  final face = Uri.tryParse(text(data['face']) ?? '');

  return AttestationReissuanceRecord(
    id: '${data['id']}',
    status: switch (text(data['approvedStatus'])) {
      '1' => ReissuanceStatus.approved,
      '2' => ReissuanceStatus.queried,
      _ => ReissuanceStatus.pending,
    },
    reference: text(data['reference']) ?? '',
    nin: text(data['applicantNin']) ?? '',
    certificateNumber: text(data['legacyCertNumber']) ?? '',
    issuedOn: date('legacyCertIssuedDate') ?? DateTime(1900),
    certificateKey:
        text(data['rawLegacyCertLink']) ?? text(data['legacyCertLink']) ?? '',
    form: AttestationReissuanceForm(
      step: AttestationReissuanceStep.review,
      applicant: ApplicantParticulars(applicant),
      additional: AdditionalInformation(additional),
      mother: parent('mother', mother: true),
      father: parent('father', mother: false),
      keptAffidavit: affidavit,
      keptSignature: signature == null
          ? null
          : KeptFile(key: signature, mimeType: 'image/png'),
    ),
    faceKey: text(data['rawFace']),
    faceUrl: face != null && face.scheme == 'https' ? face : null,
    query: queried is Map
        ? ReissuanceQuery(
            title: text(queried['title']),
            reason: text(queried['reason']),
          )
        : null,
    createdOn: date('dateCreated'),
  );
}
