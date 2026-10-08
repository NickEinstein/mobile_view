part of 'dashboard_cubit.dart';

enum DashboardStatus { loading, ready, failure }

final class DashboardState extends Equatable {
  const DashboardState({
    required this.year,
    required this.currentYear,
    this.status = DashboardStatus.loading,
    this.category = RegistrationCategory.birthRegistration,
    this.summary,
    this.failure,
  });

  /// How many past years the year picker offers.
  static const yearsShown = 5;

  final int year;
  final int currentYear;
  final DashboardStatus status;
  final RegistrationCategory category;

  /// The last loaded summary. Kept while a new year loads, so the screen
  /// doesn't flash empty.
  final DashboardSummary? summary;
  final Failure? failure;

  List<int> get years => [for (var i = 0; i < yearsShown; i++) currentYear - i];

  CategoryStats statsOf(RegistrationCategory category) =>
      summary?.of(category) ?? CategoryStats.empty;

  DashboardState copyWith({
    int? year,
    DashboardStatus? status,
    RegistrationCategory? category,
    DashboardSummary? summary,
    Failure? failure,
  }) => DashboardState(
    year: year ?? this.year,
    currentYear: currentYear,
    status: status ?? this.status,
    category: category ?? this.category,
    summary: summary ?? this.summary,
    failure: failure,
  );

  @override
  List<Object?> get props => [
    year,
    currentYear,
    status,
    category,
    summary,
    failure,
  ];
}
