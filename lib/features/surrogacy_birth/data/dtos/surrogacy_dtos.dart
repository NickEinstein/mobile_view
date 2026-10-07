import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_form.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_record.dart';

// The surrogacy API's shapes.

/// `GET /surrogacy-birth-registration/stats`:
/// `{"Pending", "Approved", "Queried", "Printed"}`.
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
    ApplicationStatus.printed: count('Printed'),
  });
}

/// The backend's `RegistrationStatus` (3 is a draft).
const _statusCodes = {
  0: ApplicationStatus.pending,
  1: ApplicationStatus.approved,
  2: ApplicationStatus.queried,
};

/// `GET /surrogacy-birth-registration`; an unknown status counts as
/// [requested].
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
  final createdAt = DateTime.tryParse(map.requireString('createdAt'));
  if (createdAt == null) {
    throw const FormatException('Expected "createdAt" to be a date.');
  }
  final reference = map.requireString('referenceId');
  final name = [
    map.optionalString('childSurname'),
    map.optionalString('childFirstName'),
  ].whereType<String>().join(' ').trim();
  final status = map['status'];
  return BirthApplicationSummary(
    id: '${map['id']}',
    // A draft may have no name yet.
    childName: name.isEmpty ? reference : name,
    trackingId: reference,
    submittedOn: createdAt,
    status: (status is int ? _statusCodes[status] : null) ?? requested,
  );
}

/// `POST /surrogacy-birth-registration/initiate`: `{"referenceId"}`.
String referenceIdFromJson(Object? json) =>
    json.asJsonMap().requireString('referenceId');

/// The body of `PATCH …/section` (or, with no [section], `…/update`).
/// Missing values go as `null`: the backend rejects empty strings.
JsonMap surrogacySectionToJson(
  SurrogacyDraft draft, {
  required SurrogacySection? section,
}) {
  final child = draft.child;
  final details = draft.surrogacy;
  Object? number(String? value) =>
      value == null ? null : int.tryParse(value) ?? value;
  String? date(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';
  final face = child[ChildField.facePhoto];
  final court = details[SurrogacyDetailsField.courtName];
  final order = details[SurrogacyDetailsField.orderReference];

  return {
    if (section != null) 'section': section.number,
    'paymentReference': draft.paymentReference,

    // Child
    'childSurname': child[ChildField.surname],
    'childFirstName': child[ChildField.firstName],
    'childMiddleName': child[ChildField.middleName],
    'childPreviousFullName': null,
    'dateOfBirth': date(child.dateOfBirth),
    'childSex': number(child[ChildField.sex]),
    'birthType': number(child[ChildField.typeOfBirth]),
    'placeOfBirth': number(child[ChildField.placeOfBirth]),
    'birthOrder': number(child[ChildField.birthOrder]),
    // The state of birth is always in Nigeria.
    'birthCountry': number(SurrogacyCodes.nigeria),
    'birthState': number(child[ChildField.stateOfBirth]),
    'birthLga': number(child[ChildField.lgaOfBirth]),
    'townOfBirth': child[ChildField.townOfBirth],
    'stateProvinceOfBirth': null,
    // No form field sets it, so it goes as null; the designs ask for
    // the "Locality of Birth" (urban or rural).
    'localityType': number(child[ChildField.localityOfBirth]),
    'childFace': face == null ? null : draft.uploads[face],
    // The backend keeps only the centre, not its state or LGA.
    'regCenter': number(child[ChildField.registrationCenter]),

    // Court and order reference share one field.
    'courtNameOrReference': court == null && order == null
        ? null
        : [?court, ?order].join(' / '),
    'parentalOrderDate': date(details.orderDate),
    'surrogacyArrangementType': details[SurrogacyDetailsField.arrangementType],

    // Legal Parent (Mother) / Legal Parent (Father)
    ..._legalParentToJson(draft.legalMother, 'lp1'),
    'lp2Present': draft.hasLegalFather ?? false,
    ..._legalParentToJson(
      (draft.hasLegalFather ?? false)
          ? draft.legalFather
          : const ParentParticulars(),
      'lp2',
    ),

    // Surrogate Mother (optional: all null when not given)
    ..._surrogateMotherToJson(draft.surrogateMother),

    // Informant
    ..._informantToJson(draft),

    'supportingDocument': [
      for (final document in draft.documentsAsked)
        if (draft.documents[document] case final file?)
          if (draft.uploads[file.path] case final key?)
            _document(document.apiType, file.path, key),
      if (draft.informantPassport case final passport?)
        if (draft.uploads[passport.path] case final key?)
          _document(SurrogacyDocument.passportType, passport.path, key),
    ],
  };
}

JsonMap _document(String type, String path, String key) => {
  'type': type,
  'file': key,
  'mimeType': path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
};

/// The API's `inf*` fields. There is no LGA of residence, town of
/// origin or face.
JsonMap _informantToJson(SurrogacyDraft draft) {
  final informant = draft.informant;
  final uploads = draft.uploads;
  String? value(InformantField field) =>
      informant.applies(field) ? informant[field] : null;
  final consent = value(InformantField.consentType);
  final signature = value(InformantField.signature);
  return {
    'infSurname': value(InformantField.surname),
    'infFirstName': value(InformantField.firstName),
    'infMiddleName': value(InformantField.middleName),
    'infSameResidenceAsLp1':
        informant[InformantField.sameResidence] == Answer.yes,
    'infCountry': _number(value(InformantField.country)),
    // The state's id, as text.
    'infStateProvince': value(InformantField.state),
    'infResidenceAddress': value(InformantField.address),
    'infNationality': _number(value(InformantField.nationality)),
    'infOriginCountry': _number(value(InformantField.countryOfOrigin)),
    'infOriginState': _number(value(InformantField.stateOfOrigin)),
    'infOriginLga': _number(value(InformantField.lgaOfOrigin)),
    'infTownOfOrigin': null,
    'infRelationshipToChild': _number(value(InformantField.relationship)),
    'infPhone': value(InformantField.phone),
    'infNin': _verifiedNin(
      informant[InformantField.nin],
      informant[InformantField.verifiedNin],
    ),
    'infPassportNo': value(InformantField.passportNumber),
    'infConsentType': consent == ConsentType.signature
        ? 'signature_pad'
        : consent,
    'infSignature': signature == null ? null : uploads[signature],
  };
}

Object? _number(String? value) =>
    value == null ? null : int.tryParse(value) ?? value;

/// A NIN is sent only once validated.
String? _verifiedNin(String? nin, String? verified) =>
    nin != null && nin == verified ? nin : null;

/// The API's legal parent fields. Origin, locality and passport have no
/// field in the designs and go as null.
JsonMap _legalParentToJson(ParentParticulars parent, String prefix) {
  String? value(ParentField field) =>
      parent.applies(field) ? parent[field] : null;
  return {
    '${prefix}FullName': parent.fullName,
    '${prefix}MaritalStatus': _number(value(ParentField.maritalStatus)),
    '${prefix}Address': value(ParentField.address),
    '${prefix}ResidenceCountry': _number(value(ParentField.country)),
    '${prefix}ResidenceState': _number(value(ParentField.state)),
    '${prefix}ResidenceLga': _number(value(ParentField.lga)),
    '${prefix}Locality': null,
    '${prefix}LocalityType': _number(value(ParentField.localityType)),
    '${prefix}Occupation': _number(value(ParentField.occupation)),
    '${prefix}Nationality': _number(value(ParentField.nationality)),
    '${prefix}OriginState': null,
    '${prefix}OriginLga': null,
    '${prefix}TownOfOrigin': null,
    '${prefix}Nin': _verifiedNin(
      parent[ParentField.nin],
      parent[ParentField.verifiedNin],
    ),
    '${prefix}PassportNo': null,
    '${prefix}LiteracyLevel': _number(value(ParentField.literacy)),
    '${prefix}EducationLevel': _number(value(ParentField.educationLevel)),
    '${prefix}Phone': value(ParentField.phone),
  };
}

JsonMap _surrogateMotherToJson(SurrogateMotherParticulars mother) {
  String? value(SurrogateField field) =>
      mother.applies(field) ? mother[field] : null;
  return {
    'smFullName': mother.fullName,
    'smAgeAtBirth': _number(value(SurrogateField.ageAtBirth)),
    'smBirthOrder': _number(value(SurrogateField.birthOrder)),
    'smAddress': value(SurrogateField.address),
    'smNationality': _number(value(SurrogateField.nationality)),
    'smOriginCountry': _number(value(SurrogateField.countryOfOrigin)),
    'smOriginState': _number(value(SurrogateField.stateOfOrigin)),
    'smOriginLga': _number(value(SurrogateField.lgaOfOrigin)),
    'smTownOfOrigin': value(SurrogateField.town),
    'smLocalityType': _number(value(SurrogateField.localityType)),
    'smLocality': null,
    'smNin': _verifiedNin(
      mother[SurrogateField.nin],
      mother[SurrogateField.verifiedNin],
    ),
    'smPassportNo': null,
    'smLiteracyLevel': _number(value(SurrogateField.literacy)),
    'smEducationLevel': _number(value(SurrogateField.educationLevel)),
    'smOccupation': _number(value(SurrogateField.occupation)),
    'smPhone': value(SurrogateField.phone),
  };
}

/// Only `success` isn't false is checked; take a tracking or
/// certificate number if one comes back.
String? submittedFromJson(Object? json) {
  if (json case {'success': false}) {
    throw const FormatException('The submission was not accepted.');
  }
  return switch (json) {
    {'trackingId': final String id} || {'certificateNo': final String id} => id,
    {'data': {'certificateNo': final String id}} => id,
    _ => null,
  };
}

/// `{"url": "https://…", "key": "…"}`
({Uri url, String key}) uploadTargetFromJson(Object? json) {
  final map = json.asJsonMap();
  final url = Uri.tryParse(map.requireString('url'));
  if (url == null || url.scheme != 'https') {
    throw const FormatException('Expected an HTTPS upload URL.');
  }
  return (url: url, key: map.requireString('key'));
}

// ---- Reading a saved application back -------------------------------------

/// `GET …/{id}` or `GET …/{referenceId}/resume`: the flat
/// `child*`/`lp1*`/`lp2*`/`sm*`/`inf*` record.
SurrogacyRecord surrogacyRecordFromJson(Object? json) {
  final outer = json.asJsonMap();
  final data = outer['data'] is Map<String, Object?>
      ? outer.requireMap('data')
      : outer;
  String? text(String key) => switch (data[key]) {
    null => null,
    final String value when value.trim().isEmpty => null,
    final String value => value,
    final value => '$value',
  };
  String? date(String key) {
    final parsed = DateTime.tryParse(text(key) ?? '');
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day).toIso8601String();
  }

  // Files come back as storage keys (or URLs to them); kept as already
  // uploaded, so they are sent back unchanged.
  final uploads = <String, String>{};
  String? file(String? key) {
    if (key == null) return null;
    uploads[key] = key;
    return key;
  }

  FieldValues<F> values<F extends Enum>(Map<F, String?> entries) => FieldValues(
    {for (final MapEntry(:key, :value) in entries.entries) key: ?value},
  );

  // The backend keeps one full name, "Surname First Middle".
  (String?, String?, String?) names(String? fullName) {
    final parts = (fullName ?? '').trim().split(RegExp(r'\s+'));
    if (parts.first.isEmpty) return (null, null, null);
    return (
      parts.first,
      parts.length > 1 ? parts[1] : null,
      parts.length > 2 ? parts.sublist(2).join(' ') : null,
    );
  }

  ParentParticulars parent(String prefix) {
    final (surname, first, middle) = names(text('${prefix}FullName'));
    final nin = text('${prefix}Nin');
    return ParentParticulars(
      values({
        ParentField.nin: nin,
        // Only validated NINs are sent, so a saved one was validated.
        ParentField.verifiedNin: nin,
        ParentField.surname: surname,
        ParentField.firstName: first,
        ParentField.middleName: middle,
        ParentField.maritalStatus: text('${prefix}MaritalStatus'),
        ParentField.address: text('${prefix}Address'),
        ParentField.occupation: text('${prefix}Occupation'),
        ParentField.nationality: text('${prefix}Nationality'),
        ParentField.country: text('${prefix}ResidenceCountry'),
        ParentField.state: text('${prefix}ResidenceState'),
        ParentField.lga: text('${prefix}ResidenceLga'),
        ParentField.localityType: text('${prefix}LocalityType'),
        ParentField.literacy: text('${prefix}LiteracyLevel'),
        ParentField.educationLevel: text('${prefix}EducationLevel'),
        ParentField.phone: text('${prefix}Phone'),
      }),
    );
  }

  final (smSurname, smFirst, smMiddle) = names(text('smFullName'));
  final smNin = text('smNin');
  final infNin = text('infNin');
  final consent = switch (text('infConsentType')) {
    'signature_pad' || 'signature' => ConsentType.signature,
    final other => other,
  };
  final ninVerified = data['childNinVerified'] == true;
  final paymentReference = text('paymentReference');

  final court = text('courtNameOrReference');
  final courtParts = court?.split(' / ');
  final documents = <SurrogacyDocument, AttachedFile>{};
  AttachedFile? passport;
  for (final entry
      in data['supportingDocument'] as List<Object?>? ?? const <Object?>[]) {
    final map = entry.asJsonMap();
    final key = map.optionalString('file');
    if (key == null) continue;
    final attached = AttachedFile(
      path: file(key)!,
      name: key.substring(key.lastIndexOf('/') + 1),
      sizeBytes: 0,
    );
    final type = map.optionalString('type');
    if (type == SurrogacyDocument.passportType) passport = attached;
    for (final document in SurrogacyDocument.values) {
      if (document.apiType == type) documents[document] = attached;
    }
  }

  final lastSection = switch (data['lastCompletedSection'] ??
      outer['lastCompletedSection']) {
    final num value => value.toInt(),
    _ => 0,
  };

  final draft = SurrogacyDraft(
    referenceId: data.requireString('referenceId'),
    startedOn: DateTime.tryParse(text('createdAt') ?? '') ?? DateTime(1970),
    // A paid draft passed the NIN step either way.
    ninDecision: ninVerified
        ? ChildNinDecision.verified
        : paymentReference != null
        ? ChildNinDecision.skipped
        : null,
    childNin: text('childNin'),
    paymentReference: paymentReference,
    step: switch (lastSection) {
      >= 4 => SurrogacyStep.review,
      3 => SurrogacyStep.documents,
      2 => SurrogacyStep.informant,
      1 => SurrogacyStep.legalMother,
      _ => SurrogacyStep.child,
    },
    child: ChildParticulars(
      values({
        ChildField.surname: text('childSurname'),
        ChildField.firstName: text('childFirstName'),
        ChildField.middleName: text('childMiddleName'),
        ChildField.dateOfBirth: date('dateOfBirth'),
        ChildField.birthOrder: text('birthOrder'),
        ChildField.sex: text('childSex'),
        ChildField.typeOfBirth: text('birthType'),
        ChildField.placeOfBirth: text('placeOfBirth'),
        ChildField.stateOfBirth: text('birthState'),
        ChildField.lgaOfBirth: text('birthLga'),
        ChildField.townOfBirth: text('townOfBirth'),
        ChildField.registrationCenter: text('regCenter'),
        ChildField.localityOfBirth: text('localityType'),
        ChildField.facePhoto: file(text('childFace')),
      }),
    ),
    surrogacy: SurrogacyDetails(
      values({
        SurrogacyDetailsField.arrangementType: text('surrogacyArrangementType'),
        SurrogacyDetailsField.courtName: courtParts?.first,
        SurrogacyDetailsField.orderReference:
            courtParts != null && courtParts.length > 1
            ? courtParts.sublist(1).join(' / ')
            : null,
        SurrogacyDetailsField.orderDate: date('parentalOrderDate'),
      }),
    ),
    legalMother: parent('lp1'),
    hasLegalFather: data['lp2Present'] is bool
        ? data['lp2Present']! as bool
        : null,
    legalFather: data['lp2Present'] == true
        ? parent('lp2')
        : const ParentParticulars(),
    surrogateMother: SurrogateMotherParticulars(
      values({
        SurrogateField.nin: smNin,
        SurrogateField.verifiedNin: smNin,
        SurrogateField.surname: smSurname,
        SurrogateField.firstName: smFirst,
        SurrogateField.middleName: smMiddle,
        SurrogateField.ageAtBirth: text('smAgeAtBirth'),
        SurrogateField.birthOrder: text('smBirthOrder'),
        SurrogateField.address: text('smAddress'),
        SurrogateField.nationality: text('smNationality'),
        SurrogateField.countryOfOrigin: text('smOriginCountry'),
        SurrogateField.stateOfOrigin: text('smOriginState'),
        SurrogateField.lgaOfOrigin: text('smOriginLga'),
        SurrogateField.town: text('smTownOfOrigin'),
        SurrogateField.localityType: text('smLocalityType'),
        SurrogateField.literacy: text('smLiteracyLevel'),
        SurrogateField.educationLevel: text('smEducationLevel'),
        SurrogateField.occupation: text('smOccupation'),
        SurrogateField.phone: text('smPhone'),
      }),
    ),
    informant: InformantParticulars(
      values({
        InformantField.nin: infNin,
        InformantField.verifiedNin: infNin,
        InformantField.surname: text('infSurname'),
        InformantField.firstName: text('infFirstName'),
        InformantField.middleName: text('infMiddleName'),
        InformantField.sameResidence: switch (data['infSameResidenceAsLp1']) {
          true => Answer.yes,
          false => Answer.no,
          _ => null,
        },
        InformantField.country: text('infCountry'),
        InformantField.state: text('infStateProvince'),
        InformantField.address: text('infResidenceAddress'),
        InformantField.nationality: text('infNationality'),
        InformantField.countryOfOrigin: text('infOriginCountry'),
        InformantField.stateOfOrigin: text('infOriginState'),
        InformantField.lgaOfOrigin: text('infOriginLga'),
        InformantField.relationship: text('infRelationshipToChild'),
        InformantField.phone: text('infPhone'),
        InformantField.passportNumber: text('infPassportNo'),
        InformantField.consentType: consent,
        InformantField.signature: consent == ConsentType.signature
            ? file(text('infSignature'))
            : null,
      }),
    ),
    informantPassport: passport,
    documents: documents,
    uploads: uploads,
  );

  final status = data['status'];
  return SurrogacyRecord(
    id: '${data['id'] ?? draft.referenceId}',
    referenceId: draft.referenceId,
    status: switch (status) {
      1 => SurrogacyRecordStatus.approved,
      2 => SurrogacyRecordStatus.queried,
      3 => SurrogacyRecordStatus.drafted,
      _ => SurrogacyRecordStatus.pending,
    },
    draft: draft,
    certificateNumber: text('surrogacyCertificateNo') ?? text('certificateNo'),
    remarks: text('remarks'),
    courtNameOrReference: court,
    lastCompletedSection: lastSection,
  );
}
