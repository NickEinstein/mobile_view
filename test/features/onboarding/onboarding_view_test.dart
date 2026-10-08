import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vital_reg_mobile/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_reg_mobile/features/onboarding/presentation/view/onboarding_page.dart';

import '../../helpers/pump_app.dart';

class _MockOnboardingCubit extends MockCubit<OnboardingState>
    implements OnboardingCubit {}

void main() {
  late _MockOnboardingCubit cubit;

  setUp(() {
    cubit = _MockOnboardingCubit();
    when(() => cubit.state).thenReturn(const OnboardingState(pageCount: 4));
    when(() => cubit.next()).thenAnswer((_) async {});
    when(() => cubit.finish()).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester) => tester.pumpApp(
    BlocProvider<OnboardingCubit>.value(
      value: cubit,
      child: const OnboardingView(),
    ),
  );

  testWidgets('shows the first page with Skip and Next', (tester) async {
    await pump(tester);

    expect(find.text('Pick what you need'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Next and Skip call the cubit', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Next'));
    await tester.tap(find.text('Skip'));

    verify(() => cubit.next()).called(1);
    verify(() => cubit.finish()).called(1);
  });

  testWidgets('the last page offers Get started and hides Skip', (
    tester,
  ) async {
    when(
      () => cubit.state,
    ).thenReturn(const OnboardingState(pageCount: 4, page: 3));

    await pump(tester);

    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Skip').hitTestable(), findsNothing);
  });
}
