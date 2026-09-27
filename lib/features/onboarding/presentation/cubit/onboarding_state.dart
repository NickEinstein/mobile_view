part of 'onboarding_cubit.dart';

final class OnboardingState extends Equatable {
  const OnboardingState({
    required this.pageCount,
    this.page = 0,
    this.isFinishing = false,
  });

  final int pageCount;
  final int page;

  /// True once Skip or "Get started" was tapped, so a double tap is ignored.
  final bool isFinishing;

  bool get isLastPage => page == pageCount - 1;

  OnboardingState copyWith({int? page, bool? isFinishing}) => OnboardingState(
    pageCount: pageCount,
    page: page ?? this.page,
    isFinishing: isFinishing ?? this.isFinishing,
  );

  @override
  List<Object?> get props => [pageCount, page, isFinishing];
}
