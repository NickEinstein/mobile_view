import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';

/// What an applications home (status cards, list, search, resume) needs.
/// Birth Registration and Birth Attestation both provide it.
abstract interface class ApplicationsSource {
  Future<Result<ApplicationCounts>> counts();

  /// Applications in [status], optionally filtered by name or tracking id.
  Future<Result<List<BirthApplicationSummary>>> applications({
    required ApplicationStatus status,
    String query = '',
  });

  /// Whether an unfinished application on this device is worth resuming.
  Future<bool> hasResumableDraft();

  /// Deletes the unfinished application and the files it captured.
  Future<void> discardDraft();
}
