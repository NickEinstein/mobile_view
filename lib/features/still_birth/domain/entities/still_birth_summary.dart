import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';

/// One row in the still birth list.
final class StillBirthSummary extends Equatable {
  const StillBirthSummary({
    required this.id,
    required this.motherName,
    required this.trackingId,
    required this.registeredOn,
    required this.status,
  });

  final String id;

  /// Still births are listed by the mother's name.
  final String motherName;
  final String trackingId;
  final DateTime registeredOn;
  final ApplicationStatus status;

  @override
  List<Object?> get props => [id, motherName, trackingId, registeredOn, status];
}
