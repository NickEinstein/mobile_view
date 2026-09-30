import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vital_reg_mobile/app/view/app_drawer.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';

import '../../helpers/pump_app.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  late _MockAuthBloc authBloc;

  setUpAll(() => registerFallbackValue(const AuthLogoutRequested()));

  setUp(() {
    authBloc = _MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthUnauthenticated(),
    );
  });

  Future<void> openDrawerAndTapLogOut(WidgetTester tester) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpApp(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: Scaffold(
          key: scaffoldKey,
          drawer: AppDrawer(onHome: () {}, onServices: () {}),
          body: const SizedBox(),
        ),
      ),
    );
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
  }

  testWidgets('logging out asks first, since drafts are removed', (
    tester,
  ) async {
    await openDrawerAndTapLogOut(tester);

    expect(find.text('Log out?'), findsOneWidget);
    expect(
      find.textContaining("Applications you haven't submitted"),
      findsOneWidget,
    );
    verifyNever(() => authBloc.add(any()));
  });

  testWidgets('cancelling keeps the user signed in', (tester) async {
    await openDrawerAndTapLogOut(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => authBloc.add(any()));
  });

  testWidgets('confirming logs out', (tester) async {
    await openDrawerAndTapLogOut(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Log Out'));
    await tester.pumpAndSettle();

    verify(() => authBloc.add(const AuthLogoutRequested())).called(1);
  });
}
