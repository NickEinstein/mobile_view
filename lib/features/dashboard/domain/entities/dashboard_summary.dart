import 'package:equatable/equatable.dart';

/// The four record types counted on the home dashboard.
enum RegistrationCategory {
  birthRegistration,
  birthAttestation,
  deathRegistration,
  stillBirth,
}

/// One category's numbers. [total] counts
/// all time (the card) and [monthly] the selected year (the chart).
final class CategoryStats extends Equatable {
  const CategoryStats({required this.total, required this.monthly});

  static const empty = CategoryStats(
    total: 0,
    monthly: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );

  final int total;

  /// January to December: always 12 values (checked by the DTO).
  final List<int> monthly;

  @override
  List<Object?> get props => [total, monthly];
}

/// Registration counts for the signed-in user's scope; the monthly series
/// are for [year].
final class DashboardSummary extends Equatable {
  const DashboardSummary({required this.year, required this.stats});

  final int year;
  final Map<RegistrationCategory, CategoryStats> stats;

  CategoryStats of(RegistrationCategory category) =>
      stats[category] ?? CategoryStats.empty;

  @override
  List<Object?> get props => [year, stats];
}
