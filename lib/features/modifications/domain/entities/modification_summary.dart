import 'package:equatable/equatable.dart';

/// Where a modification request is.
enum ModificationStatus { pending, approved, queried }

/// One row in the Modifications list.
final class ModificationSummary extends Equatable {
  const ModificationSummary({
    required this.id,
    required this.name,
    required this.certificateNumber,
    required this.status,
    this.modifiedOn,
  });

  final String id;

  /// The child's, applicant's or deceased's name on the record.
  final String name;
  final String certificateNumber;
  final ModificationStatus status;
  final DateTime? modifiedOn;

  @override
  List<Object?> get props => [id, name, certificateNumber, status, modifiedOn];
}
