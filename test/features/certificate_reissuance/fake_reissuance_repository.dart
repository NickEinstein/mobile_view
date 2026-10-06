import 'dart:typed_data';

import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/face_source.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/attestation_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_options.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

final ninRecord = ApplicantNinRecord(
  nin: '12345678901',
  surname: 'Ogunlade',
  firstName: 'Bolaji',
  dateOfBirth: DateTime(1999, 6, 16),
  sex: Sex.male,
  stateOfOrigin: 'Bauchi',
  lgaOfOrigin: 'Bogoro',
);

final sampleRequests = [
  ReissuanceSummary(
    id: '1',
    name: 'Lee Michael',
    reference: 'BRT1',
    status: ReissuanceStatus.pending,
    createdOn: DateTime(2026, 9, 23),
  ),
  const ReissuanceSummary(
    id: '2',
    name: 'Martinez Sofia',
    reference: 'BRT2',
    status: ReissuanceStatus.approved,
  ),
];

List<Option> _options(List<(String, String)> pairs) => [
  for (final (id, label) in pairs) Option(id, label),
];

/// The option lists' ids (Nigeria is 63, literate is 1).
final sampleOptions = ReissuanceOptions(
  typesOfBirth: _options([('1', 'Single'), ('2', 'Twins')]),
  birthOrders: _options([('1', '1'), ('2', '2'), ('3', '3')]),
  sexes: _options([('1', 'Male'), ('2', 'Female')]),
  placesOfOccurrence: _options([('1', 'Hospital'), ('5', 'Bus')]),
  localityTypes: _options([('1', 'Urban'), ('2', 'Rural')]),
  maritalStatuses: _options([('1', 'Married'), ('2', 'Single')]),
  ethnicGroups: _options([('4', 'Afemai')]),
  literacyLevels: _options([('1', 'Literate'), ('2', 'Illiterate')]),
  educationLevels: _options([('9', 'Masters')]),
  occupations: _options([('3', 'Able Seaman')]),
  identityTypes: _options([('2', 'Nigerian Passport')]),
  requestReasons: _options([('3', 'Loss of Letter of Attestation')]),
  requirements: _options([
    ('job in nigeria', 'A job in Nigeria'),
    ('job abroad', 'A job abroad'),
  ]),
  countries: _options([('63', 'Nigeria'), ('31', 'Ghana')]),
  nationalities: _options([('63', 'Nigerian'), ('31', 'Ghanaian')]),
  centres: const [
    RegistrationCentre(option: Option('510', 'Bogoro PHC'), lgaId: '51'),
    RegistrationCentre(option: Option('2510', 'Ikeja Centre'), lgaId: '251'),
  ],
);

/// In-memory reissuance repository with scripted answers.
class FakeReissuanceRepository implements ReissuanceRepository {
  Result<ReissuanceCounts> countsResult = const Ok(
    ReissuanceCounts(total: 4, pending: 1, approved: 2, queried: 1),
  );
  Result<List<ReissuanceSummary>> requestsResult = Ok(sampleRequests);
  Result<ApplicantNinRecord> ninResult = Ok(ninRecord);

  ReissuanceDraft? draft;

  /// Each list request: (kind, status, query).
  final requestsAsked = <(ReissuanceKind, ReissuanceStatus?, String)>[];
  final countsAsked = <ReissuanceKind>[];
  final deleted = <String>[];
  int discards = 0;

  @override
  Future<Result<ReissuanceCounts>> counts(ReissuanceKind kind) async {
    countsAsked.add(kind);
    return countsResult;
  }

  @override
  Future<Result<List<ReissuanceSummary>>> requests({
    required ReissuanceKind kind,
    ReissuanceStatus? status,
    String query = '',
  }) async {
    requestsAsked.add((kind, status, query));
    return requestsResult;
  }

  @override
  PaymentSource get payments => throw UnimplementedError();

  @override
  FaceSource get face => throw UnimplementedError();

  @override
  Future<Result<ApplicantNinRecord>> verifyNin(String nin) async => ninResult;

  Result<ReissuanceOptions> optionsResult = Ok(sampleOptions);
  final statesAsked = <String>[];
  final lgasAsked = <String>[];

  @override
  Future<Result<ReissuanceOptions>> options() async => optionsResult;

  @override
  Future<Result<List<Option>>> states(String countryCode) async {
    statesAsked.add(countryCode);
    return Ok(switch (countryCode) {
      '63' => const [Option('5', 'Bauchi'), Option('25', 'Lagos')],
      '31' => const [Option('901', 'Greater Accra')],
      _ => const [],
    });
  }

  @override
  Future<Result<List<Option>>> lgas(String stateId) async {
    lgasAsked.add(stateId);
    return Ok(switch (stateId) {
      '5' => const [Option('51', 'Bogoro')],
      '25' => const [Option('251', 'Ikeja')],
      _ => const [],
    });
  }

  @override
  Future<ReissuanceDraft?> loadDraft() async => draft;

  @override
  Future<void> saveDraft(ReissuanceDraft draft) async => this.draft = draft;

  @override
  Future<void> discardDraft() async {
    discards++;
    deleted.addAll(draft?.files ?? const []);
    draft = null;
  }

  /// Keeps the picked path as is, so tests can follow it.
  @override
  Future<String> keepDocument(String pickedPath, {String? replacing}) async {
    if (replacing != null) deleted.add(replacing);
    return pickedPath;
  }

  @override
  Future<void> deleteFile(String path) async => deleted.add(path);

  int signatures = 0;

  /// A new path per signature, so replacing one can be followed.
  @override
  Future<String> keepSignature(Uint8List png, {String? replacing}) async {
    if (replacing != null) deleted.add(replacing);
    return 'signature-${++signatures}.png';
  }

  Result<void> sendCodeResult = const Ok(null);
  Result<void> confirmCodeResult = const Ok(null);
  final codesSent = <String>[];
  final codesConfirmed = <(String, String)>[];

  @override
  Future<Result<void>> sendEmailCode(String email) async {
    codesSent.add(email);
    return sendCodeResult;
  }

  @override
  Future<Result<void>> resendEmailCode(String email) async {
    codesSent.add(email);
    return const Ok(null);
  }

  @override
  Future<Result<void>> confirmEmailCode({
    required String email,
    required String code,
  }) async {
    codesConfirmed.add((email, code));
    return confirmCodeResult;
  }

  Result<String?> submitResult = const Ok('Submitted');
  final submitted = <(ReissuanceDraft, String)>[];

  @override
  Future<Result<String?>> submitBirth(
    ReissuanceDraft draft, {
    required String email,
  }) async {
    submitted.add((draft, email));
    if (submitResult is Ok) this.draft = null;
    return submitResult;
  }

  Result<BirthReissuanceRecord> recordResult = Ok(queriedRecord);
  Result<String?> updateResult = const Ok('Updated');
  final updated = <(BirthReissuanceRecord, BirthReissuanceForm, String)>[];
  final downloads = <(ReissuanceKind, String)>[];

  @override
  Future<Result<BirthReissuanceRecord>> birthRecord(String id) async =>
      recordResult;

  @override
  Future<Result<String?>> updateBirth(
    BirthReissuanceRecord record,
    BirthReissuanceForm form, {
    required String email,
  }) async {
    updated.add((record, form, email));
    return updateResult;
  }

  Result<AttestationReissuanceRecord>? attestationRecordResult;
  final attestationsSubmitted = <ReissuanceDraft>[];
  final attestationsUpdated =
      <(AttestationReissuanceRecord, AttestationReissuanceForm)>[];

  @override
  Future<Result<String?>> submitAttestation(ReissuanceDraft draft) async {
    attestationsSubmitted.add(draft);
    if (submitResult is Ok) this.draft = null;
    return submitResult;
  }

  @override
  Future<Result<AttestationReissuanceRecord>> attestationRecord(
    String id,
  ) async => attestationRecordResult ?? const Err(NotFoundFailure());

  @override
  Future<Result<String?>> updateAttestation(
    AttestationReissuanceRecord record,
    AttestationReissuanceForm form,
  ) async {
    attestationsUpdated.add((record, form));
    return updateResult;
  }

  @override
  Future<Result<Uint8List>> download(
    ReissuanceKind kind,
    String reference,
  ) async {
    downloads.add((kind, reference));
    return Ok(Uint8List(0));
  }
}

/// A complete queried request, as `/single-birth-reg` gives it: the
/// mother's age is wrong for the second child.
final queriedRecord = BirthReissuanceRecord(
  id: '4103',
  status: ReissuanceStatus.queried,
  reference: 'BRT4',
  nin: '12345678901',
  certificateNumber: 'CR1',
  issuedOn: DateTime(2010, 3, 1),
  certificateKey: 'cert-key',
  faceKey: 'face-key',
  query: const ReissuanceQuery(
    title: 'Wrong age',
    reason: "The mother's age doesn't match the record.",
  ),
  form: BirthReissuanceForm(
    step: BirthReissuanceStep.review,
    child: const ChildParticulars()
        .set(ChildField.surname, 'Ogunlade')
        .set(ChildField.firstName, 'Bolaji')
        .set(ChildField.dateOfBirth, DateTime(2016, 3, 12).toIso8601String())
        .set(ChildField.typeOfBirth, '1')
        .set(ChildField.birthOrder, '1')
        .set(ChildField.sex, '1')
        .set(ChildField.placeOfOccurrence, '1')
        .set(ChildField.stateOfBirth, '5')
        .set(ChildField.lgaOfBirth, '51')
        .set(ChildField.locality, '1')
        .set(ChildField.registrationState, '5')
        .set(ChildField.registrationLga, '51')
        .set(ChildField.registrationCenter, '510'),
    mother: _queriedParent(maiden: 'Alice'),
    father: _queriedParent(),
    keptDocument: const KeptFile(key: 'doc-key', mimeType: 'image/png'),
    keptSignature: const KeptFile(key: 'sign-key', mimeType: 'image/png'),
  ),
);

ParentParticulars _queriedParent({String? maiden}) => const ParentParticulars()
    .set(ParentDetail.surname, 'Ogunlade')
    .set(ParentDetail.firstName, 'Amina')
    .set(ParentDetail.maidenName, maiden)
    .set(ParentDetail.country, '63')
    .set(ParentDetail.state, '5')
    .set(ParentDetail.lga, '51')
    .set(ParentDetail.address, 'No 2 Agwada Str')
    .set(ParentDetail.age, '30')
    .set(ParentDetail.maritalStatus, '1')
    .set(ParentDetail.nationality, '63')
    .set(ParentDetail.stateOfOrigin, '5')
    .set(ParentDetail.lgaOfOrigin, '51')
    .set(ParentDetail.ethnicGroup, '4')
    .set(ParentDetail.literacy, '2')
    .set(ParentDetail.occupation, '3')
    .set(ParentDetail.phone, '08130845852');
