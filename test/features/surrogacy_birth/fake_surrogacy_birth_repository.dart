import 'dart:typed_data';

import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_form.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_record.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_reference_data.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/surrogacy_birth_repository.dart';

import '../payments/fake_payment_source.dart';

/// The option lists' ids.
const sampleReferenceData = SurrogacyReferenceData(
  sexes: [Option('1', 'Male'), Option('2', 'Female')],
  birthOrders: [Option('1', '1'), Option('2', '2')],
  typesOfBirth: [Option('1', 'Single'), Option('2', 'Twins')],
  placesOfBirth: [Option('1', 'Hospital')],
  localityTypes: [Option('1', 'Rural'), Option('2', 'Urban')],
  arrangementTypes: [
    Option('gestational', 'Gestational Surrogacy'),
    Option('traditional', 'Traditional Surrogacy'),
  ],
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
  centres: [(option: Option('5011', 'Primary Health Center'), lga: '501')],
);

final sampleNinRecord = ApplicantNinRecord(
  nin: '12345678901',
  surname: 'Hassan',
  firstName: 'Suleiman',
  dateOfBirth: DateTime(2025, 9, 9),
  sex: Sex.male,
);

/// In-memory surrogacy repository with scripted answers.
class FakeSurrogacyBirthRepository implements SurrogacyBirthRepository {
  Result<String> initiateResult = const Ok('SBR-2026-0004821');
  Result<ApplicantNinRecord> ninResult = Ok(sampleNinRecord);
  Result<void> verifyResult = const Ok(null);
  Result<void> skipResult = const Ok(null);
  Result<void> attachResult = const Ok(null);
  Result<SurrogacyReferenceData> referenceResult = const Ok(
    sampleReferenceData,
  );
  Failure? saveFailure;
  Result<String?> submitResult = const Ok(null);
  int signatures = 0;
  final submitted = <String>[];
  final deleted = <String>[];

  @override
  final FakePaymentSource payments = FakePaymentSource(stored: paidPayment);

  SurrogacyDraft? draft;
  int initiated = 0;
  final verified = <(String, String)>[];
  final skipped = <String>[];
  final attached = <(String, String)>[];
  final savedSections = <(SurrogacySection, SurrogacyDraft)>[];

  @override
  Future<Result<ApplicationCounts>> counts() async =>
      const Ok(ApplicationCounts({ApplicationStatus.pending: 2}));

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
  Future<Result<SurrogacyReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  }) async {
    lgaRequests.add({...withLgasOf});
    return referenceResult;
  }

  @override
  Future<Result<SurrogacyDraft>> saveSection(
    SurrogacyDraft draft,
    SurrogacySection section,
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
  Future<SurrogacyDraft?> loadDraft() async => draft;

  @override
  Future<void> saveDraft(SurrogacyDraft draft) async => this.draft = draft;

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

  Result<SurrogacyRecord>? detailsResult;
  Result<List<BirthApplicationSummary>> draftsResult = const Ok([]);
  Result<SurrogacyRecord>? resumeResult;
  Result<void> amendResult = const Ok(null);
  final amended = <SurrogacyDraft>[];

  @override
  Future<Result<SurrogacyRecord>> details(String id) async =>
      detailsResult ?? const Err(NotFoundFailure());

  @override
  Future<Result<List<BirthApplicationSummary>>> drafts() async => draftsResult;

  @override
  Future<Result<SurrogacyRecord>> resume(String referenceId) async =>
      resumeResult ?? const Err(NotFoundFailure());

  @override
  Future<Result<void>> amend(SurrogacyDraft draft) async {
    amended.add(draft);
    return amendResult;
  }

  @override
  Future<Result<String?>> submit(String referenceId) async {
    submitted.add(referenceId);
    return submitResult;
  }
}

/// Ready for the form: NIN verified and paid.
SurrogacyDraft paidDraft({SurrogacyStep step = SurrogacyStep.child}) =>
    SurrogacyDraft(
      referenceId: 'SBR-2026-0004821',
      startedOn: DateTime(2026, 10, 4),
      ninDecision: ChildNinDecision.skipped,
      paymentReference: 'BRTPAID1',
      step: step,
    );

ChildParticulars completeChild() => const ChildParticulars()
    .set(ChildField.surname, 'Hassan')
    .set(ChildField.firstName, 'Suleiman')
    .set(ChildField.dateOfBirth, DateTime(2025, 9, 9).toIso8601String())
    .set(ChildField.birthOrder, '1')
    .set(ChildField.sex, '1')
    .set(ChildField.typeOfBirth, '1');

SurrogacyDetails completeDetails() => const SurrogacyDetails()
    .set(SurrogacyDetailsField.arrangementType, 'traditional')
    .set(SurrogacyDetailsField.courtName, 'Federal High Court')
    .set(SurrogacyDetailsField.orderReference, 'SBR-2026-0004821')
    .set(
      SurrogacyDetailsField.orderDate,
      DateTime(2025, 9, 9).toIso8601String(),
    );
