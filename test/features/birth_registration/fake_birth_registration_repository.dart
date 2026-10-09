import 'dart:async';
import 'dart:typed_data';

import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/cancellation.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/application_details.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';

import '../payments/fake_payment_source.dart';

/// A NIN record for a girl born on 12 March 2016.
final sampleChildNinRecord = ApplicantNinRecord(
  nin: '11111111111',
  surname: 'Ogunlade',
  firstName: 'Ada',
  middleName: 'Favour',
  dateOfBirth: DateTime(2016, 3, 12),
  sex: Sex.female,
);

/// In-memory repository: records drafts and answers NIN checks.
class FakeBirthRegistrationRepository implements BirthRegistrationRepository {
  /// The last submit's cancellation, so tests can see a screen cancel it.
  Cancellation? submitCancellation;

  /// When set, submits wait for it, so a test can leave mid-upload.
  Completer<void>? submitGate;

  RegistrationDraft? draft;
  Result<ApplicantNinRecord> ninResult = Ok(sampleChildNinRecord);
  int saves = 0;
  List<BirthApplicationSummary> items = const [];
  Result<ApplicationDetails>? detailsResult;
  Result<String?> submitResult = const Ok('BR123');
  final List<RegistrationDraft> submitted = [];
  Result<void> updateResult = const Ok(null);
  final List<RegistrationDraft> corrected = [];
  ReferenceData reference = const ReferenceData(
    typesOfBirth: [],
    birthOrders: [],
    sexes: [],
    placesOfOccurrence: [],
    localityTypes: [],
    states: [],
  );

  @override
  Future<RegistrationDraft?> loadDraft() async => draft;

  @override
  Future<void> saveDraft(RegistrationDraft draft) async {
    this.draft = draft;
    saves++;
  }

  @override
  Future<void> discardDraft() async => draft = null;

  @override
  Future<bool> hasResumableDraft() async => draft?.childHasNin != null;

  @override
  Future<Result<ApplicantNinRecord>> verifyNin(String nin) async => ninResult;

  @override
  final FakePaymentSource payments = FakePaymentSource();

  /// When set, asking for any state's LGAs fails with it.
  Failure? lgaFailure;

  /// The states each [referenceData] call asked LGAs for.
  final List<Set<String>> lgaRequests = [];

  /// Already holds every state's LGAs.
  @override
  Future<Result<ReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  }) async {
    lgaRequests.add({...withLgasOf});
    if (lgaFailure case final failure? when withLgasOf.isNotEmpty) {
      return Err(failure);
    }
    return Ok(reference);
  }

  @override
  Future<String> keepPhoto(String capturedPath, {String? replacing}) async =>
      capturedPath;

  @override
  Future<String> keepSignature(Uint8List png, {String? replacing}) async =>
      'signature.png';

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Future<String> keepDocument(String pickedPath, {String? replacing}) async =>
      'kept-$pickedPath';

  @override
  Future<Result<String?>> submit(
    RegistrationDraft draft, {
    void Function(int sent, int total)? onProgress,
    Cancellation? cancellation,
  }) async {
    submitCancellation = cancellation;
    await submitGate?.future;
    submitted.add(draft);
    return submitResult;
  }

  @override
  Future<Result<void>> updateQueried(
    RegistrationDraft draft, {
    void Function(int sent, int total)? onProgress,
    Cancellation? cancellation,
  }) async {
    corrected.add(draft);
    return updateResult;
  }

  @override
  Future<Result<ApplicationCounts>> counts() async =>
      const Ok(ApplicationCounts.empty);

  @override
  Future<Result<List<BirthApplicationSummary>>> applications({
    required ApplicationStatus status,
    String query = '',
  }) async => Ok(items);

  @override
  Future<Result<ApplicationDetails>> details(String id) async =>
      detailsResult ?? const Err(NotFoundFailure());
}
