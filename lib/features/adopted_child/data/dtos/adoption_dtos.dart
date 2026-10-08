import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_draft.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_form.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

// The adoption API's shapes.

/// `GET /adopted-child-registration/stats`:
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

/// `GET /adopted-child-registration`; an unknown status counts as
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

/// `POST /adopted-child-registration/initiate`: `{"referenceId"}`.
String referenceIdFromJson(Object? json) =>
    json.asJsonMap().requireString('referenceId');

/// The body of `PATCH …/section` (or, with no [section], `…/update`).
/// Missing values go as `null`: the backend rejects empty strings.
JsonMap adoptionSectionToJson(
  AdoptionDraft draft, {
  required AdoptionSection? section,
  required String? Function(String? stateId) stateName,
}) {
  final child = draft.child;
  final face = child[ChildField.facePhoto];
  final details = draft.details;

  return {
    'section': ?section?.number,
    'paymentReference': draft.paymentReference,

    // Child
    'childSurname': child[ChildField.surname],
    'childFirstName': child[ChildField.firstName],
    'childMiddleName': child[ChildField.middleName],
    'childPreviousFullName': child[ChildField.previousFullName],
    'dateOfBirth': _date(child.dateOfBirth),
    'childSex': _number(child[ChildField.sex]),
    'placeOfBirth': _number(child[ChildField.placeOfBirth]),
    'birthOrder': _number(child[ChildField.birthOrder]),
    // The state of birth is always in Nigeria.
    'birthCountry': _number(AdoptionCodes.nigeria),
    'birthState': _number(child[ChildField.stateOfBirth]),
    'birthLga': _number(child[ChildField.lgaOfBirth]),
    'townOfBirth': child[ChildField.townOfBirth],
    'stateProvinceOfBirth': null,
    // No form field sets it, so it goes as null; the design asks for
    // the "Locality of Birth" (urban or rural).
    'localityType': _number(child[ChildField.localityOfBirth]),
    'childFace': face == null ? null : draft.uploads[face],
    'regState': _number(child[ChildField.registrationState]),
    'regLga': _number(child[ChildField.registrationLga]),
    'regCenter': _number(child[ChildField.registrationCenter]),

    // Adopter 1 / Adopter 2 (the API's adoptive mother and father)
    ..._adopterToJson(draft.adopter1, 'ad1', stateName),
    'ad2Present': draft.hasAdopter2,
    ..._adopterToJson(draft.adopter2, 'ad2', stateName),

    // Adoption order
    'courtName': details[AdoptionDetailsField.courtName],
    'orderReferenceNo': details[AdoptionDetailsField.orderReference],
    'adoptionOrderDate': _date(details.orderDate),
    'adoptionType': details[AdoptionDetailsField.adoptionType],

    // Informant
    ..._informantToJson(draft, stateName),

    // Each document asked for, then the informant's
    // passport, each with its storage key.
    'supportingDocument': [
      for (final document in draft.documentsAsked)
        if (draft.documents[document] case final file?)
          if (draft.uploads[file.path] case final key?)
            _document(document.apiType, file.path, key),
      if (draft.informantPassport case final passport?)
        if (draft.uploads[passport.path] case final key?)
          _document(AdoptionDocument.passportType, passport.path, key),
    ],
  };
}

JsonMap _document(String type, String path, String key) => {
  'type': type,
  'file': key,
  'mimeType': path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
};

/// The API's `inf*` fields. Consent by signature or by face shares
/// `infSignature`.
JsonMap _informantToJson(
  AdoptionDraft draft,
  String? Function(String? stateId) stateName,
) {
  final informant = draft.informant;
  String? value(InformantField field) =>
      informant.applies(field) ? informant[field] : null;
  final state = value(InformantField.state);
  final consent = value(InformantField.consentType);
  final artefact = switch (consent) {
    ConsentType.signature => value(InformantField.signature),
    ConsentType.faceCapture => value(InformantField.face),
    _ => null,
  };
  return {
    'infSurname': value(InformantField.surname),
    'infFirstName': value(InformantField.firstName),
    'infMiddleName': value(InformantField.middleName),
    'infSameResidenceAsAdopter1':
        informant[InformantField.sameResidence] == Answer.yes,
    'infCountry': _number(value(InformantField.country)),
    'infResidenceState': _number(state),
    'infResidenceLga': _number(value(InformantField.lga)),
    'infStateProvince': state == null ? null : stateName(state),
    'infResidenceAddress': value(InformantField.address),
    'infNationality': _number(value(InformantField.nationality)),
    'infOriginCountry': _number(value(InformantField.countryOfOrigin)),
    'infOriginState': _number(value(InformantField.stateOfOrigin)),
    'infOriginLga': _number(value(InformantField.lgaOfOrigin)),
    'infTownOfOrigin': null,
    'infRelationshipToChild': _number(value(InformantField.relationship)),
    'infPhone': value(InformantField.phone),
    // Sent only once validated.
    'infNin': informant.isNinVerified ? informant[InformantField.nin] : null,
    'infPassportNo': value(InformantField.passportNumber),
    'infConsentType': switch (consent) {
      ConsentType.signature => 'signature_pad',
      final other => other,
    },
    'infSignature': artefact == null ? null : draft.uploads[artefact],
  };
}

/// `POST …/submit`: a tracking number when the server gives one.
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

/// The API's adopter fields. Origin, locality and passport have
/// no field in the designs and go as null.
JsonMap _adopterToJson(
  AdopterParticulars adopter,
  String prefix,
  String? Function(String? stateId) stateName,
) {
  String? value(AdopterField field) =>
      adopter.applies(field) ? adopter[field] : null;
  final state = value(AdopterField.state);
  final stateText = state == null ? null : stateName(state);
  return {
    '${prefix}FullName': adopter.fullName,
    '${prefix}MaritalStatus': _number(value(AdopterField.maritalStatus)),
    '${prefix}Address': value(AdopterField.address),
    '${prefix}ResidenceCountry': _number(value(AdopterField.country)),
    '${prefix}ResidenceState': _number(state),
    '${prefix}ResidenceLga': _number(value(AdopterField.lga)),
    // The state's name goes to both.
    '${prefix}StateProvince': stateText,
    '${prefix}ResidenceStateProvince': stateText,
    '${prefix}Locality': null,
    '${prefix}LocalityType': _number(value(AdopterField.localityType)),
    '${prefix}Occupation': _number(value(AdopterField.occupation)),
    '${prefix}Nationality': _number(value(AdopterField.nationality)),
    '${prefix}OriginState': null,
    '${prefix}OriginLga': null,
    '${prefix}TownOfOrigin': null,
    // Sent only once validated.
    '${prefix}Nin': adopter.isNinVerified ? adopter[AdopterField.nin] : null,
    '${prefix}PassportNo': null,
    '${prefix}LiteracyLevel': _number(value(AdopterField.literacy)),
    '${prefix}EducationLevel': _number(value(AdopterField.educationLevel)),
    '${prefix}Phone': value(AdopterField.phone),
  };
}

Object? _number(String? value) =>
    value == null ? null : int.tryParse(value) ?? value;

String? _date(DateTime? value) => value == null
    ? null
    : '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';

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
/// `child*`/`ad1*`/`ad2*`/`inf*` record.
AdoptionRecord adoptionRecordFromJson(Object? json) {
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

  // Files come back as storage keys; kept as already uploaded, so they are
  // sent back unchanged.
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

  AdopterParticulars adopter(String prefix) {
    final (surname, first, middle) = names(text('${prefix}FullName'));
    final nin = text('${prefix}Nin');
    return AdopterParticulars(
      values({
        AdopterField.nin: nin,
        // Only validated NINs are sent, so a saved one was validated.
        AdopterField.verifiedNin: nin,
        AdopterField.surname: surname,
        AdopterField.firstName: first,
        AdopterField.middleName: middle,
        AdopterField.maritalStatus: text('${prefix}MaritalStatus'),
        AdopterField.nationality: text('${prefix}Nationality'),
        AdopterField.address: text('${prefix}Address'),
        AdopterField.occupation: text('${prefix}Occupation'),
        AdopterField.country: text('${prefix}ResidenceCountry'),
        AdopterField.state: text('${prefix}ResidenceState'),
        AdopterField.lga: text('${prefix}ResidenceLga'),
        AdopterField.localityType: text('${prefix}LocalityType'),
        AdopterField.literacy: text('${prefix}LiteracyLevel'),
        AdopterField.educationLevel: text('${prefix}EducationLevel'),
        AdopterField.phone: text('${prefix}Phone'),
      }),
    );
  }

  final infNin = text('infNin');
  final consent = switch (text('infConsentType')) {
    'signature_pad' || 'signature' => ConsentType.signature,
    final other => other,
  };
  final ninVerified = data['childNinVerified'] == true;
  final paymentReference = text('paymentReference');

  final documents = <AdoptionDocument, AttachedFile>{};
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
    if (type == AdoptionDocument.passportType) passport = attached;
    for (final document in AdoptionDocument.values) {
      if (document.apiType == type) documents[document] = attached;
    }
  }

  final lastSection = switch (data['lastCompletedSection'] ??
      outer['lastCompletedSection']) {
    final num value => value.toInt(),
    _ => 0,
  };

  final draft = AdoptionDraft(
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
    // The step after the last section saved.
    step: switch (lastSection) {
      >= 5 => AdoptionStep.review,
      4 => AdoptionStep.documents,
      3 => AdoptionStep.informant,
      2 => AdoptionStep.adoptionDetails,
      1 => AdoptionStep.adopter1,
      _ => AdoptionStep.child,
    },
    child: ChildParticulars(
      values({
        ChildField.surname: text('childSurname'),
        ChildField.firstName: text('childFirstName'),
        ChildField.middleName: text('childMiddleName'),
        ChildField.dateOfBirth: date('dateOfBirth'),
        ChildField.sex: text('childSex'),
        ChildField.previousFullName: text('childPreviousFullName'),
        ChildField.placeOfBirth: text('placeOfBirth'),
        ChildField.birthOrder: text('birthOrder'),
        ChildField.stateOfBirth: text('birthState'),
        ChildField.lgaOfBirth: text('birthLga'),
        ChildField.townOfBirth: text('townOfBirth'),
        ChildField.registrationState: text('regState'),
        ChildField.registrationLga: text('regLga'),
        ChildField.registrationCenter: text('regCenter'),
        ChildField.localityOfBirth: text('localityType'),
        ChildField.facePhoto: file(text('childFace')),
      }),
    ),
    adopter1: adopter('ad1'),
    adopter2: data['ad2Present'] == true
        ? adopter('ad2')
        : const AdopterParticulars(),
    details: AdoptionDetails(
      values({
        AdoptionDetailsField.adoptionType: text('adoptionType'),
        AdoptionDetailsField.courtName: text('courtName'),
        AdoptionDetailsField.orderReference: text('orderReferenceNo'),
        AdoptionDetailsField.orderDate: date('adoptionOrderDate'),
      }),
    ),
    informant: InformantParticulars(
      values({
        InformantField.nin: infNin,
        InformantField.verifiedNin: infNin,
        InformantField.surname: text('infSurname'),
        InformantField.firstName: text('infFirstName'),
        InformantField.middleName: text('infMiddleName'),
        InformantField.sameResidence:
            switch (data['infSameResidenceAsAdopter1']) {
              true => Answer.yes,
              false => Answer.no,
              _ => null,
            },
        InformantField.country: text('infCountry'),
        InformantField.state: text('infResidenceState'),
        InformantField.lga: text('infResidenceLga'),
        InformantField.address: text('infResidenceAddress'),
        InformantField.nationality: text('infNationality'),
        InformantField.countryOfOrigin: text('infOriginCountry'),
        InformantField.stateOfOrigin: text('infOriginState'),
        InformantField.lgaOfOrigin: text('infOriginLga'),
        InformantField.relationship: text('infRelationshipToChild'),
        InformantField.phone: text('infPhone'),
        InformantField.passportNumber: text('infPassportNo'),
        InformantField.consentType: consent,
        // Both kinds of consent share `infSignature`.
        InformantField.signature: consent == ConsentType.signature
            ? file(text('infSignature'))
            : null,
        InformantField.face: consent == ConsentType.faceCapture
            ? file(text('infSignature'))
            : null,
      }),
    ),
    informantPassport: passport,
    documents: documents,
    uploads: uploads,
  );

  return AdoptionRecord(
    id: '${data['id'] ?? draft.referenceId}',
    referenceId: draft.referenceId,
    status: switch (data['status']) {
      1 => AdoptionRecordStatus.approved,
      2 => AdoptionRecordStatus.queried,
      3 => AdoptionRecordStatus.drafted,
      _ => AdoptionRecordStatus.pending,
    },
    draft: draft,
    certificateNumber: text('certificateNo'),
    remarks: text('remarks'),
    lastCompletedSection: lastSection,
  );
}
