part of 'applications_cubit.dart';

final class ApplicationsState extends Equatable {
  const ApplicationsState({
    this.status = ApplicationStatus.pending,
    this.query = '',
    this.isLoading = true,
    this.counts = ApplicationCounts.empty,
    this.items = const [],
    this.failure,
  });

  /// The selected card; its applications are listed.
  final ApplicationStatus status;
  final String query;
  final bool isLoading;
  final ApplicationCounts counts;
  final List<BirthApplicationSummary> items;
  final Failure? failure;

  /// [failure] is cleared unless passed, so a successful reload hides it.
  ApplicationsState copyWith({
    ApplicationStatus? status,
    String? query,
    bool? isLoading,
    ApplicationCounts? counts,
    List<BirthApplicationSummary>? items,
    Failure? failure,
  }) => ApplicationsState(
    status: status ?? this.status,
    query: query ?? this.query,
    isLoading: isLoading ?? this.isLoading,
    counts: counts ?? this.counts,
    items: items ?? this.items,
    failure: failure,
  );

  @override
  List<Object?> get props => [status, query, isLoading, counts, items, failure];
}
