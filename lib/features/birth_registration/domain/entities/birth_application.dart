import 'package:equatable/equatable.dart';

/// Where a submitted application is in its lifecycle.
enum ApplicationStatus { pending, approved, printed, queried }

/// One row in the Birth Registration list.
final class BirthApplicationSummary extends Equatable {
  const BirthApplicationSummary({
    required this.id,
    required this.childName,
    required this.trackingId,
    required this.submittedOn,
    required this.status,
  });

  final String id;
  final String childName;
  final String trackingId;
  final DateTime submittedOn;
  final ApplicationStatus status;

  @override
  List<Object?> get props => [id, childName, trackingId, submittedOn, status];
}

/// How many applications are in each status.
final class ApplicationCounts extends Equatable {
  const ApplicationCounts(this._counts);

  static const empty = ApplicationCounts({});

  final Map<ApplicationStatus, int> _counts;

  int of(ApplicationStatus status) => _counts[status] ?? 0;

  @override
  List<Object?> get props => [_counts];
}
