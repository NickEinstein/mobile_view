import 'dart:typed_data';

import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/adopted_child_repository.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_draft.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_form.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_record.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_reference_data.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

import '../payments/fake_payment_source.dart';

/// The option lists' ids.
const sampleReferenceData = AdoptionReferenceData(
  sexes: [Option('1', 'Male'), Option('2', 'Female')],
  birthOrders: [Option('1', 'First Order'), Option('2', 'Second Order')],
  placesOfBirth: [Option('1', 'Hospital')],
  localityTypes: [Option('1', 'Rural'), Option('2', 'Urban')],
  countries: [Option('63', 'Nigeria'), Option('31', 'Ghana')],
  nationalities: [Option('63', 'Nigerian'), Option('31', 'Ghanaian')],
  maritalStatuses: [Option('1', 'Married'), Option('2', 'Single')],
  occupations: [Option('1', 'House Wife'), Option('100', 'Professional')],
  literacyLevels: [Option('1', 'Literate'), Option('2', 'Illiterate')],
  educationLevels: [Option('7', 'Bachelors Degree')],
  relationships: [Option('2', 'Mother'), Option('13', 'Others')],
  states: [
    StateOption(
      option: Option('25', 'Lagos'),
      lgas: [
        LgaOption(
          option: Option('501', 'Agege'),
          towns: [],
          registrationCenters: [Option('5011', 'Primary Health Center')],
        ),
      ],
    ),
  ],
);

final sampleNinRecord = ApplicantNinRecord(
  nin: '12345678901',
  surname: 'Hassan',
  firstName: 'Suleiman',
  dateOfBirth: DateTime(2015, 9, 9),
  sex: Sex.male,
);

/// In-memory adoption repository with scripted answers.
class FakeAdoptedChildRepository implements AdoptedChildRepository {
  Result<String> initiateResult = const Ok('ACR-2026-0003150');
  Result<ApplicantNinRecord> ninResult = Ok(sampleNinRecord);
  Result<void> verifyResult = const Ok(null);
  Result<void> skipResult = const Ok(null);
  Result<void> attachResult = const Ok(null);
  Result<AdoptionReferenceData> referenceResult = const Ok(sampleReferenceData);
  Failure? saveFailure;
  Result<String?> submitResult = const Ok(null);
  int signatures = 0;
  final submitted = <String>[];
  Result<AdoptionRecord>? detailsResult;
  Result<AdoptionRecord>? resumeResult;
  Result<List<BirthApplicationSummary>> draftsResult = const Ok([]);
  Result<void> amendResult = const Ok(null);
  final amended = <AdoptionDraft>[];
  final deleted = <String>[];

  @override
  final FakePaymentSource payments = FakePaymentSource(stored: paidPayment);

  AdoptionDraft? draft;
  int initiated = 0;
  final verified = <(String, String)>[];
  final skipped = <String>[];
  final attached = <(String, String)>[];
  final savedSections = <(AdoptionSection, AdoptionDraft)>[];

  @override
  Future<Result<ApplicationCounts>> counts() async =>
      const Ok(ApplicationCounts({ApplicationStatus.pending: 3}));

  @override
  Future<Result<List<BirthApplicationSummary>>> applications({
    required ApplicationStatus status,
    String query = '',
  }) async => const Ok([]);

  @override
  Future<Result<String>> initiate() async {
    initiated++;
    return initiateResult;
  }

  @override
  Future<Result<ApplicantNinRecord>> lookupNin(String nin) async => ninResult;

  @override
  Future<Result<void>> verifyChildNin({
    required String referenceId,
    required String nin,
  }) async {
    verified.add((referenceId, nin));
    return verifyResult;
  }

  @override
  Future<Result<void>> skipChildNin(String referenceId) async {
    skipped.add(referenceId);
    return skipResult;
  }

  @override
  Future<Result<void>> attachPayment({
    required String referenceId,
    required String reference,
  }) async {
    attached.add((referenceId, reference));
    return attachResult;
  }

  /// The states each [referenceData] call asked LGAs for.
  final List<Set<String>> lgaRequests = [];

  /// Already holds every state's LGAs.
  @override
  Future<Result<AdoptionReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  }) async {
    lgaRequests.add({...withLgasOf});
    return referenceResult;
  }

  @override
  Future<Result<AdoptionDraft>> saveSection(
    AdoptionDraft draft,
    AdoptionSection section,
  ) async {
    final failure = saveFailure;
    if (failure != null) return Err(failure);
    savedSections.add((section, draft));
    return Ok(
      draft.copyWith(
        uploads: {
          for (final path in draft.filesToUpload) path: 'key/$path',
          ...draft.uploads,
        },
      ),
    );
  }

  @override
  Future<AdoptionDraft?> loadDraft() async => draft;

  @override
  Future<void> saveDraft(AdoptionDraft draft) async => this.draft = draft;

  @override
  Future<bool> hasResumableDraft() async => draft != null;

  @override
  Future<void> discardDraft() async => draft = null;

  @override
  Future<String> keepPhoto(String capturedPath, {String? replacing}) async =>
      'kept/$capturedPath';

  @override
  Future<String> keepSignature(Uint8List png, {String? replacing}) async =>
      'signature-${++signatures}.png';

  @override
  Future<String> keepDocument(String pickedPath, {String? replacing}) async =>
      'kept/$pickedPath';

  @override
  Future<void> deleteFile(String path) async => deleted.add(path);

  @override
  Future<Result<AdoptionRecord>> details(String id) async =>
      detailsResult ?? const Err(NotFoundFailure());

  @override
  Future<Result<List<BirthApplicationSummary>>> drafts() async => draftsResult;

  @override
  Future<Result<AdoptionRecord>> resume(String referenceId) async =>
      resumeResult ?? const Err(NotFoundFailure());

  @override
  Future<Result<void>> amend(AdoptionDraft draft) async {
    amended.add(draft);
    return amendResult;
  }

  @override
  Future<Result<String?>> submit(String referenceId) async {
    submitted.add(referenceId);
    return submitResult;
  }
}

/// Ready for the form: NIN skipped and paid.
AdoptionDraft paidDraft({AdoptionStep step = AdoptionStep.child}) =>
    AdoptionDraft(
      referenceId: 'ACR-2026-0003150',
      startedOn: DateTime(2026, 10, 4),
      ninDecision: ChildNinDecision.skipped,
      paymentReference: 'BRTPAID1',
      step: step,
    );

ChildParticulars completeChild() => const ChildParticulars()
    .set(ChildField.surname, 'Hassan')
    .set(ChildField.firstName, 'Suleiman')
    .set(ChildField.dateOfBirth, DateTime(2015, 9, 9).toIso8601String())
    .set(ChildField.sex, '1');

/// Adopter 1 as the design fills it, with a validated NIN.
AdopterParticulars completeAdopter() => const AdopterParticulars()
    .set(AdopterField.nin, '72921010909')
    .set(AdopterField.verifiedNin, '72921010909')
    .set(AdopterField.surname, 'Ololade')
    .set(AdopterField.firstName, 'Semiola')
    .set(AdopterField.maritalStatus, '1')
    .set(AdopterField.nationality, '63')
    .set(AdopterField.address, 'No 12 Adeleke road, Lekki')
    .set(AdopterField.occupation, '100');

AdoptionDetails completeDetails() => const AdoptionDetails()
    .set(AdoptionDetailsField.adoptionType, AdoptionCodes.domestic)
    .set(AdoptionDetailsField.courtName, 'Federal High Court')
    .set(AdoptionDetailsField.orderReference, 'FCT/HC/CV/1889/2026')
    .set(
      AdoptionDetailsField.orderDate,
      DateTime(2025, 9, 9).toIso8601String(),
    );

InformantParticulars completeInformant() => const InformantParticulars()
    .set(InformantField.surname, 'Keith')
    .set(InformantField.firstName, 'Ryan')
    .set(InformantField.country, '31')
    .set(InformantField.address, 'No 2 Agwoda St')
    .set(InformantField.relationship, '13')
    .set(InformantField.phone, '08123123123')
    .set(InformantField.consentType, ConsentType.signature)
    .set(InformantField.signature, 'signature-1.png');

AttachedFile photo(String name) =>
    AttachedFile(path: '/$name', name: name, sizeBytes: 60 * 1024);

/// Every step done, ready for the review.
AdoptionDraft completeDraft() => paidDraft(step: AdoptionStep.review).copyWith(
  child: completeChild(),
  adopter1: completeAdopter(),
  details: completeDetails(),
  informant: completeInformant(),
  documents: {
    AdoptionDocument.courtOrder: photo('order.jpg'),
    AdoptionDocument.adoptionCertificate: photo('certificate.jpg'),
    AdoptionDocument.adopter1Identity: photo('id1.png'),
  },
);

/// A record as the server returns it.
AdoptionRecord sampleRecord({
  AdoptionRecordStatus status = AdoptionRecordStatus.queried,
  AdoptionDraft? draft,
}) => AdoptionRecord(
  id: 'adoption-queried-0',
  referenceId: 'ACR-2026-0003150',
  status: status,
  draft: draft ?? completeDraft().copyWith(step: AdoptionStep.child),
  remarks: status == AdoptionRecordStatus.queried
      ? 'The date of birth does not match the court order.'
      : null,
);
