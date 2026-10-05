part of 'still_birth_home_cubit.dart';

final class StillBirthHomeState extends Equatable {
  const StillBirthHomeState({
    this.isLoading = false,
    this.total = 0,
    this.items = const [],
    this.query = '',
    this.failure,
  });

  final bool isLoading;

  /// "Total Registration".
  final int total;
  final List<StillBirthSummary> items;
  final String query;
  final Failure? failure;

  StillBirthHomeState copyWith({
    bool? isLoading,
    int? total,
    List<StillBirthSummary>? items,
    String? query,
    Failure? Function()? failure,
  }) => StillBirthHomeState(
    isLoading: isLoading ?? this.isLoading,
    total: total ?? this.total,
    items: items ?? this.items,
    query: query ?? this.query,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [isLoading, total, items, query, failure];
}
