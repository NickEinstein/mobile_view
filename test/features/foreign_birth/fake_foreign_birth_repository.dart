import 'dart:typed_data';

import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_draft.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_form.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_record.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_reference_data.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/foreign_birth_repository.dart';

import '../payments/fake_payment_source.dart';

/// The option lists' ids.
const sampleReferenceData = ForeignBirthReferenceData(
  sexes: [Option('1', 'Male'), Option('2', 'Female')],
  typesOfBirth: [Option('1', 'Single'), Option('2', 'Twins')],
  birthOrders: [Option('1', '1'), Option('2', '2')],
  placesOfOccurrence: [Option('1', 'Hospital')],
  maritalStatuses: [Option('1', 'Married'), Option('2', 'Single')],
  occupations: [Option('1', 'House Wife'), Option('100', 'Professional')],
  literacyLevels: [Option('1', 'Literate'), Option('2', 'Illiterate')],
  educationLevels: [Option('7', 'Bachelors Degree')],
  ethnicGroups: [Option('5', 'Hausa')],
  relationships: [Option('1', 'Father'), Option('2', 'Mother')],
  countries: [
    ForeignBirthCountry(
      option: Option('181', 'United Kingdom'),
      nationality: Option('181', 'British'),
      isoCode: 'GB',
    ),
    ForeignBirthCountry(
      option: Option('63', 'Nigeria'),
      nationality: Option('63', 'Nigerian'),
      isoCode: 'NG',
    ),
  ],
);

final sampleNinRecord = ApplicantNinRecord(
  nin: '90289384945',
  surname: 'Ololade',
  firstName: 'Adegoke',
  dateOfBirth: DateTime(1990, 1, 1),
  sex: Sex.female,
);

/// In-memory foreign birth repository with scripted answers.
class FakeForeignBirthRepository implements ForeignBirthRepository {
  Result<ForeignBirthReferenceData> referenceResult = const Ok(
    sampleReferenceData,
  );
  Result<ApplicantNinRecord> ninResult = Ok(sampleNinRecord);
  Result<List<Option>>? statesFailure;
  final statesAsked = <String>[];
  final lgasAsked = <String>[];
  final deleted = <String>[];
  Failure? uploadFailure;
  Result<String?> submitResult = const Ok('GB261004512');
  final uploadedPaths = <String>[];
  final submitted = <ForeignBirthDraft>[];
  int signatures = 0;
  Result<ForeignBirthRecord>? detailsResult;
  Result<void> amendResult = const Ok(null);
  final amended = <(ForeignBirthDraft, ForeignBirthRecord)>[];

  @override
  final FakePaymentSource payments = FakePaymentSource(stored: paidPayment);

  ForeignBirthDraft? draft;

  @override
  Future<Result<ApplicationCounts>> counts() async =>
      const Ok(ApplicationCounts({ApplicationStatus.pending: 2}));

  @override
  Future<Result<List<BirthApplicationSummary>>> applications({
    required ApplicationStatus status,
    String query = '',
  }) async => const Ok([]);

  @override
  Future<Result<ForeignBirthReferenceData>> referenceData() async =>
      referenceResult;

  @override
  Future<Result<List<Option>>> states(String countryId) async {
    statesAsked.add(countryId);
    return statesFailure ??
        Ok(switch (countryId) {
          '181' => const [Option('951', 'England'), Option('952', 'Scotland')],
          '63' => const [Option('25', 'Lagos')],
          _ => const [],
        });
  }

  @override
  Future<Result<List<Option>>> lgas(String stateId) async {
    lgasAsked.add(stateId);
    return Ok(stateId == '25' ? const [Option('501', 'Agege')] : const []);
  }

  @override
  Future<Result<ApplicantNinRecord>> lookupNin(String nin) async => ninResult;

  @override
  Future<ForeignBirthDraft?> loadDraft() async => draft;

  @override
  Future<void> saveDraft(ForeignBirthDraft draft) async => this.draft = draft;

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
  Future<Result<ForeignBirthDraft>> uploadFiles(ForeignBirthDraft draft) async {
    final failure = uploadFailure;
    if (failure != null) return Err(failure);
    final pending = [
      for (final path in draft.filesToUpload)
        if (!draft.uploads.containsKey(path)) path,
    ];
    uploadedPaths.addAll(pending);
    return Ok(
      draft.copyWith(
        uploads: {
          ...draft.uploads,
          for (final path in pending) path: 'key/$path',
        },
      ),
    );
  }

  @override
  Future<Result<String?>> submit(ForeignBirthDraft draft) async {
    submitted.add(draft);
    return submitResult;
  }

  @override
  Future<Result<ForeignBirthRecord>> details(String id) async =>
      detailsResult ?? const Err(NotFoundFailure());

  @override
  Future<Result<void>> amend(
    ForeignBirthDraft draft, {
    required ForeignBirthRecord record,
  }) async {
    amended.add((draft, record));
    return amendResult;
  }
}

/// Paid, ready for the form.
ForeignBirthDraft paidDraft({ForeignBirthStep step = ForeignBirthStep.child}) =>
    ForeignBirthDraft(
      startedOn: DateTime(2026, 10, 4),
      paymentReference: 'BRTPAID1',
      step: step,
    );

ChildParticulars completeChild() => const ChildParticulars()
    .set(ChildField.surname, 'Garba')
    .set(ChildField.firstName, 'Amina')
    .set(ChildField.dateOfBirth, DateTime(2025, 12, 12).toIso8601String())
    .set(ChildField.sex, '2')
    .set(ChildField.typeOfBirth, '1')
    .set(ChildField.birthOrder, '1')
    .set(ChildField.placeOfOccurrence, '1')
    .set(ChildField.countryOfBirth, '181')
    .set(ChildField.stateOfBirth, '951');

/// A Nigerian mother living in Lagos, with a validated NIN.
ParentParticulars completeMother() => const ParentParticulars()
    .set(ParentField.nationality, '63')
    .set(ParentField.nin, '90289384945')
    .set(ParentField.verifiedNin, '90289384945')
    .set(ParentField.surname, 'Ololade')
    .set(ParentField.firstName, 'Adegoke')
    .set(ParentField.maidenName, 'Bello')
    .set(ParentField.maritalStatus, '1')
    .set(ParentField.age, '30')
    .set(ParentField.stateOfOrigin, '25')
    .set(ParentField.lgaOfOrigin, '501')
    .set(ParentField.ethnicGroup, '5')
    .set(ParentField.occupation, '100')
    .set(ParentField.country, '63')
    .set(ParentField.state, '25')
    .set(ParentField.lga, '501')
    .set(ParentField.address, 'No 12 Adeleke road, Lekki')
    .set(ParentField.literacy, '2');

/// A British father living in England: no NIN, LGA or ethnic group.
ParentParticulars completeFather() => const ParentParticulars()
    .set(ParentField.nationality, '181')
    .set(ParentField.surname, 'Keith')
    .set(ParentField.firstName, 'Ryan')
    .set(ParentField.maritalStatus, '1')
    .set(ParentField.age, '35')
    .set(ParentField.stateOfOrigin, '951')
    .set(ParentField.country, '181')
    .set(ParentField.state, '951')
    .set(ParentField.address, '10 Baker Street, London')
    .set(ParentField.literacy, '2');

/// A family friend consenting by signature, living in England.
InformantParticulars completeInformant() => const InformantParticulars()
    .set(InformantField.relationship, '13')
    .set(InformantField.surname, 'Keith')
    .set(InformantField.firstName, 'Ryan')
    .set(InformantField.country, '181')
    .set(InformantField.state, '951')
    .set(InformantField.address, '10 Baker Street, London')
    .set(InformantField.nationality, '181')
    .set(InformantField.phone, '08123212820')
    .set(InformantField.email, 'keith@example.com')
    .set(InformantField.consentType, ConsentType.signature)
    .set(InformantField.signature, 'signature-1.png');

AttachedFile photo(String name) =>
    AttachedFile(path: '/$name', name: name, sizeBytes: 60 * 1024);

/// Every step done, ready for the review.
ForeignBirthDraft completeDraft() =>
    paidDraft(step: ForeignBirthStep.review).copyWith(
      child: completeChild(),
      mother: completeMother(),
      father: completeFather(),
      informant: completeInformant(),
      certificate: () => photo('certificate.jpg'),
    );

/// A queried notification as the server returns it: its files are
/// storage keys, already uploaded.
ForeignBirthRecord queriedRecord() => ForeignBirthRecord(
  id: 540,
  status: ApplicationStatus.queried,
  notificationNumber: 'GB261000540',
  queryReason: 'The certificate is unreadable.',
  partyIds: (child: 5401, mother: 5402, father: 5403, informant: 5402),
  draft: completeDraft().copyWith(
    step: ForeignBirthStep.child,
    informant: completeInformant().set(InformantField.signature, 'fb/sig.png'),
    certificate: () =>
        const AttachedFile(path: 'fb/cert.jpg', name: 'cert.jpg', sizeBytes: 0),
    uploads: {'fb/sig.png': 'fb/sig.png', 'fb/cert.jpg': 'fb/cert.jpg'},
  ),
  fileUrls: const {'fb/sig.png': 'https://files.test/sig.png'},
);
