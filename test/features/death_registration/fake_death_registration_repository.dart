import 'dart:async';
import 'dart:typed_data';

import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/cancellation.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/death_registration_repository.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_draft.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_form.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_record.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_reference_data.dart';

List<Option> _options(List<(String, String)> pairs) => [
  for (final (id, label) in pairs) Option(id, label),
];

/// The option lists' ids (Nigeria 63, Hospital 1, Literate 1).
final sampleDeathReferenceData = DeathReferenceData(
  sexes: _options([('1', 'Male'), ('2', 'Female')]),
  countries: _options([('63', 'Nigeria'), ('31', 'Ghana')]),
  nationalities: _options([('63', 'Nigerian'), ('31', 'Ghanaian')]),
  settlements: _options([('1', 'Urban'), ('2', 'Rural')]),
  occupations: _options([('100', 'Accountant')]),
  placesOfDeath: _options([('1', 'Hospital'), ('2', 'At Home')]),
  ethnicGroups: _options([('4', 'Afemai')]),
  maritalStatuses: _options([('1', 'Married')]),
  literacy: _options([('1', 'Literate'), ('2', 'Illiterate')]),
  educationLevels: _options([('6', 'HND')]),
  yesNo: _options([('1', 'Yes'), ('0', 'No')]),
  causesOfDeath: _options([('3', 'Fever')]),
  relationships: _options([('3', 'Brother')]),
  states: const [
    StateOption(
      option: Option('5', 'Bauchi'),
      code: 'BA',
      lgas: [
        LgaOption(
          option: Option('51', 'Bogoro'),
          code: '510',
          towns: [],
          registrationCenters: [Option('9', 'Bogoro PHC')],
        ),
      ],
    ),
  ],
);

/// In-memory death registration repository with scripted answers.
class FakeDeathRegistrationRepository implements DeathRegistrationRepository {
  /// The last submit's cancellation, so tests can see a screen cancel it.
  Cancellation? submitCancellation;

  /// When set, submits wait for it, so a test can leave mid-upload.
  Completer<void>? submitGate;

  Result<DeathReferenceData> referenceResult = Ok(sampleDeathReferenceData);
  Result<String?> submitResult = const Ok('DR123');
  Result<void> updateResult = const Ok(null);

  /// The status every listed row has.
  ApplicationStatus listedStatus = ApplicationStatus.pending;
  final updated = <DeathDraft>[];

  DeathDraft? draft;
  final submitted = <DeathDraft>[];
  final deleted = <String>[];
  int files = 0;

  @override
  Future<Result<ApplicationCounts>> counts() async => const Ok(
    ApplicationCounts({
      ApplicationStatus.pending: 2,
      ApplicationStatus.approved: 3,
    }),
  );

  @override
  Future<Result<List<BirthApplicationSummary>>> applications({
    required ApplicationStatus status,
    String query = '',
  }) async => Ok([
    BirthApplicationSummary(
      id: '40000',
      childName: 'Lee Michael',
      trackingId: 'DC30087677',
      submittedOn: DateTime(2026, 9, 23),
      status: listedStatus,
    ),
  ]);

  /// A queried record: no NIN, police report and affidavit on file, but
  /// no next-of-kin letter.
  @override
  Future<Result<DeathRecord>> details(String id) async => Ok(
    DeathRecord(
      summary: BirthApplicationSummary(
        id: id,
        childName: 'Allison Favour',
        trackingId: 'DC30087677',
        submittedOn: DateTime(2026, 9, 23),
        status: ApplicationStatus.queried,
      ),
      deceased: const DeceasedParticulars(
        FieldValues({
          DeceasedField.noNinReason: 'Never enrolled',
          DeceasedField.surname: 'Allison',
          DeceasedField.firstName: 'Favour',
          DeceasedField.sex: '2',
          DeceasedField.country: '31',
          DeceasedField.occupation: '100',
          DeceasedField.dateOfDeath: '2026-09-22T00:00:00.000',
          DeceasedField.placeOfDeath: '2',
          DeceasedField.village: 'Amaba',
          DeceasedField.ageAtDeath: '90',
          DeceasedField.nationality: '31',
          DeceasedField.maritalStatus: '1',
          DeceasedField.certifiedByDoctor: '1',
          DeceasedField.causeOfDeath: '3',
          DeceasedField.registrationState: '5',
          DeceasedField.registrationLga: '51',
          DeceasedField.registrationCenter: '9',
        }),
      ),
      informant: const InformantParticulars(
        FieldValues({
          InformantField.nin: '12342567890',
          InformantField.surname: 'Doe',
          InformantField.firstName: 'John',
          InformantField.relationship: '3',
          InformantField.sameAddress: DeathCodes.no,
          InformantField.country: '31',
          InformantField.phone: '08045365780',
        }),
        '12342567890',
      ),
      documentKeys: const {
        DeathDocument.policeReport: 'k/police.jpg',
        DeathDocument.affidavit: 'k/affidavit.jpg',
      },
      signatureKey: 'k/sign.png',
      queryReason: 'Wrong document uploaded',
    ),
  );

  @override
  Future<Result<void>> updateQueried(DeathDraft draft) async {
    updated.add(draft);
    return updateResult;
  }

  /// `00000000000` has no record; any other NIN is Allison Favour.
  @override
  Future<Result<ApplicantNinRecord>> verifyNin(String nin) async =>
      nin == '00000000000'
      ? const Err(NotFoundFailure())
      : Ok(
          ApplicantNinRecord(
            nin: nin,
            surname: 'Allison',
            firstName: 'Favour',
            dateOfBirth: DateTime(1936),
          ),
        );

  /// The states each [referenceData] call asked LGAs for.
  final List<Set<String>> lgaRequests = [];

  /// Already holds every state's LGAs.
  @override
  Future<Result<DeathReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  }) async {
    lgaRequests.add({...withLgasOf});
    return referenceResult;
  }

  @override
  Future<DeathDraft?> loadDraft() async => draft;

  @override
  Future<void> saveDraft(DeathDraft draft) async => this.draft = draft;

  @override
  Future<bool> hasResumableDraft() async => draft?.hasAnswers ?? false;

  @override
  Future<void> discardDraft() async => draft = null;

  @override
  Future<String> keepSignature(Uint8List png, {String? replacing}) async {
    if (replacing != null) deleted.add(replacing);
    return 'signature-${++files}.png';
  }

  @override
  Future<String> keepDocument(String pickedPath, {String? replacing}) async {
    if (replacing != null) deleted.add(replacing);
    return 'document-${++files}.jpg';
  }

  @override
  Future<void> deleteFile(String path) async => deleted.add(path);

  @override
  Future<Result<String?>> submit(
    DeathDraft draft, {
    void Function(int done, int total)? onProgress,
    Cancellation? cancellation,
  }) async {
    submitCancellation = cancellation;
    await submitGate?.future;
    submitted.add(draft);
    onProgress?.call(1, 1);
    return submitResult;
  }
}
