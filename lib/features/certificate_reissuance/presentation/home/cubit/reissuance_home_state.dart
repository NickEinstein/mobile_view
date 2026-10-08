part of 'reissuance_home_cubit.dart';

final class ReissuanceHomeState extends Equatable {
  const ReissuanceHomeState({
    this.kind = ReissuanceKind.birth,
    this.status,
    this.query = '',
    this.isLoading = true,
    this.counts = const ReissuanceCounts(),
    this.items = const [],
    this.failure,
  });

  /// The selected tab.
  final ReissuanceKind kind;

  /// The selected card; null is "Total" (every status).
  final ReissuanceStatus? status;
  final String query;
  final bool isLoading;
  final ReissuanceCounts counts;
  final List<ReissuanceSummary> items;
  final Failure? failure;

  /// [failure] is cleared unless passed, so a successful reload hides it.
  /// [status] is a function so it can be set back to null.
  ReissuanceHomeState copyWith({
    ReissuanceKind? kind,
    ReissuanceStatus? Function()? status,
    String? query,
    bool? isLoading,
    ReissuanceCounts? counts,
    List<ReissuanceSummary>? items,
    Failure? failure,
  }) => ReissuanceHomeState(
    kind: kind ?? this.kind,
    status: status != null ? status() : this.status,
    query: query ?? this.query,
    isLoading: isLoading ?? this.isLoading,
    counts: counts ?? this.counts,
    items: items ?? this.items,
    failure: failure,
  );

  @override
  List<Object?> get props => [
    kind,
    status,
    query,
    isLoading,
    counts,
    items,
    failure,
  ];
}
