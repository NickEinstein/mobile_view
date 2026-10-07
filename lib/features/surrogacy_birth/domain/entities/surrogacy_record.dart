import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';

/// The backend's `RegistrationStatus`: 0 pending, 1 approved, 2 queried,
/// 3 a draft not yet submitted.
enum SurrogacyRecordStatus {
  pending,
  approved,
  queried,
  drafted;

  /// For the shared status chip; a draft has none.
  ApplicationStatus? get applicationStatus => switch (this) {
    pending => ApplicationStatus.pending,
    approved => ApplicationStatus.approved,
    queried => ApplicationStatus.queried,
    drafted => null,
  };
}

/// One application from the server, in the form's shape (files as stored
/// keys).
final class SurrogacyRecord extends Equatable {
  const SurrogacyRecord({
    required this.id,
    required this.referenceId,
    required this.status,
    required this.draft,
    this.certificateNumber,
    this.remarks,
    this.courtNameOrReference,
    this.lastCompletedSection = 0,
  });

  final String id;
  final String referenceId;
  final SurrogacyRecordStatus status;
  final SurrogacyDraft draft;

  /// Once approved.
  final String? certificateNumber;

  /// Why it was queried.
  final String? remarks;

  /// The court name and order reference as the backend keeps them, in one
  /// field.
  final String? courtNameOrReference;

  /// For a draft: the last section saved (0 to 4).
  final int lastCompletedSection;

  @override
  List<Object?> get props => [
    id,
    referenceId,
    status,
    draft,
    certificateNumber,
    remarks,
    courtNameOrReference,
    lastCompletedSection,
  ];

  @override
  String toString() => 'SurrogacyRecord(status: ${status.name})';
}
