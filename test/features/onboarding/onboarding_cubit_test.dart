import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vital_reg_mobile/features/onboarding/domain/onboarding_repository.dart';
import 'package:vital_reg_mobile/features/onboarding/presentation/cubit/onboarding_cubit.dart';

class _MockOnboardingRepository extends Mock implements OnboardingRepository {}

void main() {
  late _MockOnboardingRepository repository;

  setUp(() {
    repository = _MockOnboardingRepository();
    when(() => repository.markCompleted()).thenAnswer((_) async {});
  });

  OnboardingCubit buildCubit() => OnboardingCubit(repository, pageCount: 4);

  const start = OnboardingState(pageCount: 4);

  blocTest<OnboardingCubit, OnboardingState>(
    'next advances one page without completing',
    build: buildCubit,
    act: (cubit) => cubit.next(),
    expect: () => [start.copyWith(page: 1)],
    verify: (_) => verifyNever(() => repository.markCompleted()),
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'next on the last page completes onboarding',
    build: buildCubit,
    seed: () => start.copyWith(page: 3),
    act: (cubit) => cubit.next(),
    expect: () => [start.copyWith(page: 3, isFinishing: true)],
    verify: (_) => verify(() => repository.markCompleted()).called(1),
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'skip completes from any page, once, even when tapped twice',
    build: buildCubit,
    act: (cubit) async {
      await cubit.finish();
      await cubit.finish();
    },
    expect: () => [start.copyWith(isFinishing: true)],
    verify: (_) => verify(() => repository.markCompleted()).called(1),
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'follows swipes',
    build: buildCubit,
    act: (cubit) => cubit.pageChanged(2),
    expect: () => [start.copyWith(page: 2)],
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'Back goes to the previous page',
    build: buildCubit,
    seed: () => start.copyWith(page: 2),
    act: (cubit) => cubit.previous(),
    expect: () => [start.copyWith(page: 1)],
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'Back on the first page changes nothing (the app closes instead)',
    build: buildCubit,
    act: (cubit) => cubit.previous(),
    expect: () => <OnboardingState>[],
  );

  test('knows when it is on the last page', () {
    expect(start.isLastPage, isFalse);
    expect(start.copyWith(page: 3).isLastPage, isTrue);
  });
}
