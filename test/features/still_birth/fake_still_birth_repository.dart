import 'dart:typed_data';

import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_draft.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_form.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_record.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_reference_data.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_summary.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/still_birth_repository.dart';

List<Option> _options(List<(String, String)> pairs) => [
  for (final (id, label) in pairs) Option(id, label),
];

/// The option lists' ids (Nigeria is 63, "Mother" is 2).
final sampleReferenceData = StillBirthReferenceData(
  placesOfOccurrence: _options([('1', 'Hospital'), ('5', 'Bus')]),
  sexes: _options([('1', 'Male'), ('2', 'Female')]),
  typesOfDelivery: _options([('1', 'Single'), ('2', 'Twins')]),
  countries: _options([('63', 'Nigeria'), ('31', 'Ghana')]),
  nationalities: _options([('63', 'Nigerian'), ('31', 'Ghanaian')]),
  settlements: _options([('1', 'Urban'), ('2', 'Rural')]),
  ethnicGroups: _options([('4', 'Afemai')]),
  relationships: _options([('2', 'Mother'), ('3', 'Brother')]),
  states: const [
    StateOption(
      option: Option('5', 'Bauchi'),
      lgas: [
        LgaOption(
          option: Option('51', 'Bogoro'),
          towns: [],
          registrationCenters: [],
        ),
      ],
    ),
  ],
);

final sampleRegistrations = [
  StillBirthSummary(
    id: '1',
    motherName: 'Michael Lee',
    trackingId: 'FA30087677',
    registeredOn: DateTime(2026, 9, 23),
    status: ApplicationStatus.pending,
  ),
  StillBirthSummary(
    id: '2',
    motherName: 'Sofia Martinez',
    trackingId: 'FA30087678',
    registeredOn: DateTime(2025, 10, 15),
    status: ApplicationStatus.pending,
  ),
];

/// In-memory still birth repository with scripted answers.
class FakeStillBirthRepository implements StillBirthRepository {
  Result<int> countResult = const Ok(3);
  Result<List<StillBirthSummary>> listResult = Ok(sampleRegistrations);
  Result<StillBirthReferenceData> referenceResult = Ok(sampleReferenceData);
  Result<String?> submitResult = const Ok('SB123');
  Result<StillBirthRecord>? detailsResult;

  StillBirthDraft? draft;
  final searches = <String>[];
  final submitted = <StillBirthDraft>[];
  final deleted = <String>[];
  int signatures = 0;

  @override
  Future<Result<int>> count() async => countResult;

  @override
  Future<Result<List<StillBirthSummary>>> registrations({
    String query = '',
  }) async {
    searches.add(query);
    return listResult;
  }

  /// An approved record with a few answers, unless [detailsResult] is set.
  @override
  Future<Result<StillBirthRecord>> details(String id) async =>
      detailsResult ??
      Ok(
        StillBirthRecord(
          summary: StillBirthSummary(
            id: id,
            motherName: 'Ogunlade Amina',
            trackingId: 'FA30087677',
            registeredOn: DateTime(2026, 9, 23),
            status: ApplicationStatus.approved,
          ),
          deceased: const DeceasedParticulars()
              .set(DeceasedField.placeOfOccurrence, '1')
              .set(DeceasedField.village, 'Amaba'),
          mother: const MotherParticulars().set(
            MotherField.fullName,
            'Ogunlade Amina',
          ),
          informant: const InformantParticulars()
              .set(InformantField.fullName, 'Ogunlade Bolaji')
              .set(InformantField.signature, 'https://files.test/sign.png'),
        ),
      );

  /// The states each [referenceData] call asked LGAs for.
  final List<Set<String>> lgaRequests = [];

  /// Already holds every state's LGAs.
  @override
  Future<Result<StillBirthReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  }) async {
    lgaRequests.add({...withLgasOf});
    return referenceResult;
  }

  @override
  Future<StillBirthDraft?> loadDraft() async => draft;

  @override
  Future<void> saveDraft(StillBirthDraft draft) async => this.draft = draft;

  @override
  Future<bool> hasResumableDraft() async => draft?.hasAnswers ?? false;

  @override
  Future<void> discardDraft() async => draft = null;

  @override
  Future<String> keepSignature(Uint8List png, {String? replacing}) async {
    if (replacing != null) deleted.add(replacing);
    return 'signature-${++signatures}.png';
  }

  @override
  Future<void> deleteFile(String path) async => deleted.add(path);

  @override
  Future<Result<String?>> submit(StillBirthDraft draft) async {
    submitted.add(draft);
    return submitResult;
  }
}
