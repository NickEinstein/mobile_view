import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';

/// The backend's `RegistrationStatus`: 0 pending, 1 approved, 2 queried,
/// 3 a draft not yet submitted.
enum AdoptionRecordStatus {
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
final class AdoptionRecord extends Equatable {
  const AdoptionRecord({
    required this.id,
    required this.referenceId,
    required this.status,
    required this.draft,
    this.certificateNumber,
    this.remarks,
    this.lastCompletedSection = 0,
  });

  final String id;
  final String referenceId;
  final AdoptionRecordStatus status;
  final AdoptionDraft draft;

  /// Once approved.
  final String? certificateNumber;

  /// Why it was queried.
  final String? remarks;

  /// For a draft: the last section saved (0 to 5).
  final int lastCompletedSection;

  @override
  List<Object?> get props => [
    id,
    referenceId,
    status,
    draft,
    certificateNumber,
    remarks,
    lastCompletedSection,
  ];

  /// Contains personal data: keep it out of logs.
  @override
  String toString() => 'AdoptionRecord(status: ${status.name})';
}
