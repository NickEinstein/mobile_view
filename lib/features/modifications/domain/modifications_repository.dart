import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_submission.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_summary.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/queried_modification.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

abstract interface class ModificationsRepository {
  /// How many modification requests there are for [kind].
  Future<Result<int>> count(ModificationKind kind);

  /// Requests for [kind] in [status], optionally filtered by name or
  /// certificate number.
  Future<Result<List<ModificationSummary>>> requests({
    required ModificationKind kind,
    required ModificationStatus status,
    String query = '',
  });

  /// The payment for [request]'s fee, which depends on what it changes.
  PaymentSource payments(ModificationRequest request);

  /// The registered record with [certificateNumber]. A
  /// `NotFoundFailure` when there's none.
  Future<Result<ModificationRecord>> findRecord(
    ModificationKind kind,
    String certificateNumber,
  );

  /// Nigeria's states.
  Future<Result<List<Option>>> states();

  Future<Result<List<Option>>> lgas(String stateId);

  /// Moves a picked document into private storage and returns its new
  /// path. [replacing] is deleted.
  Future<String> keepDocument(String pickedPath, {String? replacing});

  Future<void> deleteFile(String path);

  /// A queried request, with what it was sent with and why it was queried.
  Future<Result<QueriedModification>> queried(ModificationKind kind, String id);

  /// Uploads the new documents, then sends the request (or resends a
  /// queried one). Returns the server's confirmation message, if any.
  Future<Result<String?>> submit(ModificationSubmission submission);
}
