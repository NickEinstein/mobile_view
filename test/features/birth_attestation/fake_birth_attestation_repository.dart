import 'dart:async';

import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/cancellation.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';

import '../payments/fake_payment_source.dart';

final adultRecord = ApplicantNinRecord(
  nin: '12345678901',
  surname: 'Ogunlade',
  firstName: 'Bolaji',
  dateOfBirth: DateTime(1990, 6, 14),
  sex: Sex.male,
);

List<Option> _options(List<String> ids) => [
  for (final id in ids) Option(id, id),
];

/// Option ids equal their labels, so tests read naturally.
final sampleReferenceData = AttestationReferenceData(
  sexes: const [Option('1', 'Male'), Option('2', 'Female')],
  maritalStatuses: _options(['Single', 'Married']),
  identityTypes: _options(['Nigerian Passport']),
  placesOfBirth: _options(['Hospital']),
  educationLevels: _options(['BSC']),
  occupations: _options(['Trader']),
  requestReasons: _options(['Birth Not Registered']),
  requirements: _options(['job in nigeria', 'job abroad']),
  countries: const [Option('63', 'Nigeria'), Option('gh', 'Ghana')],
  states: [
    StateOption(
      option: const Option('bauchi', 'Bauchi'),
      lgas: [
        LgaOption(
          option: const Option('bogoro', 'Bogoro'),
          towns: const [],
          registrationCenters: _options(['Bogoro PHC']),
        ),
      ],
    ),
  ],
);

/// In-memory attestation repository with scripted answers.
class FakeBirthAttestationRepository implements BirthAttestationRepository {
  /// The last submit's cancellation, so tests can see a screen cancel it.
  Cancellation? submitCancellation;

  /// When set, submits wait for it, so a test can leave mid-upload.
  Completer<void>? submitGate;

  @override
  final FakePaymentSource payments = FakePaymentSource();

  Result<ApplicantNinRecord> ninResult = Ok(adultRecord);
  Result<bool> faceResult = const Ok(true);
  Result<AttestationReferenceData> referenceResult = Ok(sampleReferenceData);
  Result<String?> submitResult = const Ok('BA123');
  final List<(AttestationDraft, String)> submitted = [];
  Result<AttestationRecord>? detailsResult;
  Result<void> updateResult = const Ok(null);
  final List<AttestationDraft> corrections = [];
  int saves = 0;
  List<BirthApplicationSummary> items = const [];

  AttestationDraft? draft;
  final List<String> facesChecked = [];
  final List<String> deleted = [];

  @override
  Future<Result<ApplicationCounts>> counts() async =>
      const Ok(ApplicationCounts.empty);

  @override
  Future<Result<List<BirthApplicationSummary>>> applications({
    required ApplicationStatus status,
    String query = '',
  }) async => Ok(items);

  @override
  Future<Result<ApplicantNinRecord>> verifyNin(String nin) async => ninResult;

  @override
  Future<Result<bool>> matchFace(
    String photoPath, {
    required String nin,
  }) async {
    facesChecked.add(photoPath);
    return faceResult;
  }

  @override
  Future<AttestationDraft?> loadDraft() async => draft;

  @override
  Future<void> saveDraft(AttestationDraft draft) async {
    saves++;
    this.draft = draft;
  }

  @override
  Future<bool> hasResumableDraft() async => draft?.hasNin != null;

  @override
  Future<void> discardDraft() async {
    deleted.addAll(draft?.files ?? const []);
    draft = null;
  }

  @override
  Future<String> keepPhoto(String capturedPath, {String? replacing}) async {
    if (replacing != null) deleted.add(replacing);
    return capturedPath;
  }

  @override
  Future<void> deleteFile(String path) async => deleted.add(path);

  /// The states each [referenceData] call asked LGAs for.
  final List<Set<String>> lgaRequests = [];

  /// Already holds every state's LGAs.
  @override
  Future<Result<AttestationReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  }) async {
    lgaRequests.add({...withLgasOf});
    return referenceResult;
  }

  @override
  Future<Result<String?>> submit(
    AttestationDraft draft, {
    required String paymentReference,
    void Function(int sent, int total)? onProgress,
    Cancellation? cancellation,
  }) async {
    submitCancellation = cancellation;
    await submitGate?.future;
    submitted.add((draft, paymentReference));
    return submitResult;
  }

  @override
  Future<String> keepDocument(String pickedPath, {String? replacing}) async {
    if (replacing != null) deleted.add(replacing);
    return 'kept-$pickedPath';
  }

  @override
  Future<Result<AttestationRecord>> details(String id) async =>
      detailsResult ?? const Err(NotFoundFailure());

  @override
  Future<Result<void>> updateQueried(AttestationDraft draft) async {
    corrections.add(draft);
    return updateResult;
  }
}
