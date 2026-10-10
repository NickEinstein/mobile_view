import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

/// Storage keys of the files uploaded for a submission (see
/// `GET /file-upload-url/:name`).
typedef RegistrationUploads = ({
  String? childFace,
  String? informantIdentity,
  Map<DocumentType, String> documents,
});

/// Relationship ids for which the API records the parent as informant.
const _fatherRelationship = '1';
const _motherRelationship = '2';

/// `POST /birth-registration/add` for a claimed birth. [places] gives the
/// registration codes that start the certificate number.
JsonMap registrationToJson(
  RegistrationDraft draft, {
  required ReferenceData places,
  required RegistrationUploads uploads,
}) {
  final c = draft.child;
  final relationship = draft.informant[InformantField.relationship];
  String? dob() {
    final date = c.dateOfBirth;
    if (date == null) return null;
    String two(int n) => '$n'.padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  return {
    'Claimed': true,
    'dateInitiated': draft.startedOn.toUtc().toIso8601String(),
    'paymentReference': ?draft.paymentReference,
    'NIN': draft.childNin,
    'SurName': c[ChildField.surname],
    'FirstName': c[ChildField.firstName],
    'MiddleName': c[ChildField.middleName],
    'Date_Of_Birth': dob(),
    'Birth_type': _number(c[ChildField.typeOfBirth]),
    'birth_order': _number(c[ChildField.birthOrder]),
    'gender': _number(c[ChildField.sex]),
    'birth_place': _number(c[ChildField.placeOfOccurrence]),
    'StateID': _number(c[ChildField.stateOfBirth]),
    'LGA_of_Birth': _number(c[ChildField.lgaOfBirth]),
    'town_of_birth': c[ChildField.localityOfBirth],
    'countryOfOrigin': _number(ReferenceData.nigeria),
    'stateOfOrigin': _number(c[ChildField.stateOfOrigin]),
    'LGA_of_Origin': _number(c[ChildField.lgaOfOrigin]),
    'townOfOrigin': c[ChildField.townOfOrigin],
    'childBirthLocality': _number(c[ChildField.localityType]),
    // Deprecated by the API in favour of childBirthLocality, but still
    // accepted, so it is sent too.
    'locality_of_birth': _number(c[ChildField.localityType]),
    'registration_lga': _number(c[ChildField.registrationLga]),
    'Reg_Center': _number(c[ChildField.registrationCenter]),
    'State_Code': places.stateCode(c[ChildField.registrationState]),
    'LGA_Code': places.lgaCode(
      c[ChildField.registrationState],
      c[ChildField.registrationLga],
    ),
    'ChildFace': uploads.childFace,
    ..._parentJson(
      draft.mother,
      ParentRole.mother,
      mother: draft.mother,
      isInformant: relationship == _motherRelationship,
      passport: uploads.documents[DocumentType.motherPassport],
    ),
    ..._parentJson(
      draft.father,
      ParentRole.father,
      mother: draft.mother,
      isInformant: relationship == _fatherRelationship,
      passport: uploads.documents[DocumentType.fatherPassport],
    ),
    ..._informantJson(draft.informant, mother: draft.mother),
    'informant_signature': uploads.informantIdentity,
    'SupportingDocument': [
      for (final type in draft.documentTypes)
        {
          'type': type.apiType,
          'file': uploads.documents[type],
          'mimeType': switch (draft.documents[type]?.name.toLowerCase()) {
            null => null,
            final name when name.endsWith('.png') => 'image/png',
            _ => 'image/jpeg',
          },
        },
    ],
  };
}

/// Option ids are numbers to the API; anything else is sent as it is.
Object? _number(String? value) =>
    value == null ? null : int.tryParse(value) ?? value;

/// The API's names for one person's place of residence.
typedef _ResidenceKeys = ({
  String country,
  String state,
  String lga,
  String address,
  String settlement,
});

_ResidenceKeys _residenceKeys(String person) => (
  country: '${person}_Country_of_Residence',
  state: '${person}_State_of_Residence',
  lga: '${person}_LGA_Of_Residence',
  address: '${person}_Address',
  settlement: '${person}_Settlement_Type',
);

/// The mother's place of residence, under [keys].
JsonMap _mothersResidence(ParentParticulars mother, _ResidenceKeys keys) {
  String? field(ParentField field) =>
      mother.applies(field, ParentRole.mother) ? mother[field] : null;
  return {
    keys.country: _number(field(ParentField.country)),
    keys.state: _number(field(ParentField.state)),
    keys.lga: _number(field(ParentField.lga)),
    keys.address: field(ParentField.address),
    keys.settlement: _number(field(ParentField.settlement)),
  };
}

JsonMap _parentJson(
  ParentParticulars parent,
  ParentRole role, {
  required ParentParticulars mother,
  required bool isInformant,
  required String? passport,
}) {
  final isMother = role == ParentRole.mother;
  final p = isMother ? 'Mother' : 'Father';
  String? value(ParentField field) =>
      parent.applies(field, role) ? parent[field] : null;
  Object? number(ParentField field) => _number(value(field));
  final residence = _residenceKeys(p);

  return {
    '${p}_SurName': value(ParentField.surname),
    '${p}_FirstName': value(ParentField.firstName),
    if (isMother) ...{
      'Mothers_Maiden_Name': value(ParentField.maidenName),
      'Mother_Middle_Name': value(ParentField.middleName),
    } else
      'Father_MiddleName': value(ParentField.middleName),
    '${p}_age_at_birth': number(ParentField.age),
    // The nationality also goes as the country of origin.
    '${p}_Country_of_Origin': number(ParentField.nationality),
    '${p}_Nationality': number(ParentField.nationality),
    if (isMother) ...{
      'MotherStateOriginId': number(ParentField.stateOfOrigin),
      'Mother_LGA_Of_Origin': number(ParentField.lgaOfOrigin),
    } else ...{
      'Father_State_of_Origin': number(ParentField.stateOfOrigin),
      'Father_LGA': number(ParentField.lgaOfOrigin),
    },
    '${p}_Ethnic_Group': number(ParentField.ethnicGroup),
    '${p}_Marital_Status': number(ParentField.maritalStatus),
    '${p}_Literacy_Level': number(ParentField.literacy),
    '${p}_Education': number(ParentField.educationLevel),
    // The API keeps an occupation for the mother only.
    if (isMother) 'Mother_Occupation': number(ParentField.occupation),
    '${p}_Phone_No': value(ParentField.phone),
    '${p}_NIN': value(ParentField.nin),
    '${p}_Is_Informant': isInformant,
    if (parent.isForeign) '${p}_Passport': passport,
    if (parent.livesWithMother(role))
      ..._mothersResidence(mother, residence)
    else ...{
      residence.country: number(ParentField.country),
      residence.state: number(ParentField.state),
      residence.lga: number(ParentField.lga),
      residence.address: value(ParentField.address),
      residence.settlement: number(ParentField.settlement),
    },
  };
}

JsonMap _informantJson(
  InformantParticulars informant, {
  required ParentParticulars mother,
}) {
  String? value(InformantField field) =>
      informant.applies(field) ? informant[field] : null;
  final residence = _residenceKeys('Informant');
  return {
    'Informant_Relationship_ID': _number(value(InformantField.relationship)),
    'Informant_surname': value(InformantField.surname),
    'Informant_firstname': value(InformantField.firstName),
    'Informant_middle_name': value(InformantField.middleName),
    'Informant_Phone_No': value(InformantField.phone),
    'Informant_NIN': value(InformantField.nin),
    'Informant_Tracking_ID': value(InformantField.trackingId),
    if (informant.livesWithMother)
      ..._mothersResidence(mother, residence)
    else ...{
      residence.country: _number(value(InformantField.country)),
      residence.state: _number(value(InformantField.state)),
      residence.lga: _number(value(InformantField.lga)),
      residence.address: value(InformantField.address),
      residence.settlement: _number(value(InformantField.settlement)),
    },
  };
}

/// The certificate number, if the answer has one (rarely).
String? registrationAddedFromJson(Object? json) => switch (json) {
  {'record': {'Certificate_No': final String number}} => number,
  {'Certificate_No': final String number} => number,
  {'trackingId': final String id} => id,
  _ => null,
};

/// `{"url": "https://…", "key": "…"}` from `GET /file-upload-url/:name`.
({Uri url, String key}) uploadTargetFromJson(Object? json) {
  final map = json.asJsonMap();
  final url = Uri.tryParse(map.requireString('url'));
  if (url == null || url.scheme != 'https') {
    throw const FormatException('Expected an HTTPS upload URL.');
  }
  return (url: url, key: map.requireString('key'));
}

/// `PATCH /birth-registration/update`: the application with the record's
/// id and fee, without the child's NIN. A null file keeps the one on file.
JsonMap registrationUpdateToJson(
  RegistrationDraft draft, {
  required QueriedRecord queried,
  required ReferenceData places,
  required RegistrationUploads uploads,
}) => {
  ...registrationToJson(draft, places: places, uploads: uploads),
  'Birth_Reg_ID': _number(queried.recordId),
  'NIN': null,
  'paymentReference': queried.paymentReference,
};
