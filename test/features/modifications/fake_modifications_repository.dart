import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_submission.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_summary.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/queried_modification.dart';
import 'package:vital_reg_mobile/features/modifications/domain/modifications_repository.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

import '../payments/fake_payment_source.dart';

final michael = ModificationSummary(
  id: '1',
  name: 'Lee Michael',
  certificateNumber: 'FA30087677',
  status: ModificationStatus.pending,
  modifiedOn: DateTime(2026, 9, 23),
);

/// Scripted answers; records each list request.
class FakeModificationsRepository implements ModificationsRepository {
  Map<ModificationKind, Result<int>> countResults = {
    ModificationKind.birth: const Ok(3),
    ModificationKind.attestation: const Ok(1),
    ModificationKind.death: const Err(ServerFailure(statusCode: 500)),
  };
  Result<List<ModificationSummary>> listResult = Ok([michael]);
  final List<(ModificationKind, ModificationStatus, String)> requested = [];

  @override
  Future<Result<int>> count(ModificationKind kind) async =>
      countResults[kind] ?? const Ok(0);

  @override
  Future<Result<List<ModificationSummary>>> requests({
    required ModificationKind kind,
    required ModificationStatus status,
    String query = '',
  }) async {
    requested.add((kind, status, query));
    return listResult;
  }

  Result<ModificationRecord> recordResult = const Ok(sampleRecord);
  final List<(ModificationKind, String)> lookedUp = [];

  @override
  Future<Result<ModificationRecord>> findRecord(
    ModificationKind kind,
    String certificateNumber,
  ) async {
    lookedUp.add((kind, certificateNumber));
    return recordResult;
  }

  final FakePaymentSource payment = FakePaymentSource(stored: paidPayment);
  final List<ModificationRequest> paidFor = [];

  @override
  PaymentSource payments(ModificationRequest request) {
    paidFor.add(request);
    return payment;
  }

  Result<List<Option>> statesResult = const Ok([
    Option('1', 'Abia'),
    Option('25', 'Lagos'),
  ]);
  Map<String, List<Option>> lgasByState = const {
    '1': [Option('11', 'Isiukwuato'), Option('12', 'Umuahia North')],
    '25': [Option('251', 'Ikeja')],
  };
  final List<String> lgasAsked = [];

  @override
  Future<Result<List<Option>>> states() async => statesResult;

  @override
  Future<Result<List<Option>>> lgas(String stateId) async {
    lgasAsked.add(stateId);
    return Ok(lgasByState[stateId] ?? const []);
  }

  /// Files "kept" (picked path → kept path) and deleted.
  final List<String> kept = [];
  final List<String> deleted = [];

  @override
  Future<String> keepDocument(String pickedPath, {String? replacing}) async {
    kept.add(pickedPath);
    if (replacing != null) deleted.add(replacing);
    return 'kept/$pickedPath';
  }

  @override
  Future<void> deleteFile(String path) async => deleted.add(path);

  Result<QueriedModification>? queriedResult;
  final List<(ModificationKind, String)> queriedAsked = [];

  @override
  Future<Result<QueriedModification>> queried(
    ModificationKind kind,
    String id,
  ) async {
    queriedAsked.add((kind, id));
    return queriedResult ?? const Err(NotFoundFailure());
  }

  Result<String?> submitResult = const Ok('Submitted.');
  final List<ModificationSubmission> submitted = [];

  @override
  Future<Result<String?>> submit(ModificationSubmission submission) async {
    submitted.add(submission);
    return submitResult;
  }
}

/// A payment already made, unless told otherwise.
const sampleRecord = ModificationRecord(
  kind: ModificationKind.birth,
  recordId: '40',
  certificateNumber: 'B123',
  name: 'Hassan Suleiman',
  values: {
    RecordField.surname: 'Hasan',
    RecordField.firstName: 'Suleiman',
    RecordField.dateOfBirth: '2020-09-09',
    RecordField.sex: '1',
    RecordField.birthState: '1',
    RecordField.birthLga: '11',
    RecordField.birthTown: 'Ovim',
    RecordField.motherSurname: 'Ikemefuna',
    RecordField.motherFirstName: 'Devine',
    RecordField.fatherSurname: 'Ikemefuna',
    RecordField.fatherFirstName: 'Chidi',
  },
);
