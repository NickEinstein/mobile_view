part of 'modifications_cubit.dart';

final class ModificationsState extends Equatable {
  const ModificationsState({
    this.kind = ModificationKind.birth,
    this.status = ModificationStatus.pending,
    this.query = '',
    this.isLoading = true,
    this.counts = const {},
    this.items = const [],
    this.failure,
  });

  /// The selected card; its requests are listed.
  final ModificationKind kind;

  /// Chosen with the filter button.
  final ModificationStatus status;
  final String query;
  final bool isLoading;
  final Map<ModificationKind, int> counts;
  final List<ModificationSummary> items;
  final Failure? failure;

  int countOf(ModificationKind kind) => counts[kind] ?? 0;

  /// [failure] is cleared unless passed, so a successful reload hides it.
  ModificationsState copyWith({
    ModificationKind? kind,
    ModificationStatus? status,
    String? query,
    bool? isLoading,
    Map<ModificationKind, int>? counts,
    List<ModificationSummary>? items,
    Failure? failure,
  }) => ModificationsState(
    kind: kind ?? this.kind,
    status: status ?? this.status,
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
