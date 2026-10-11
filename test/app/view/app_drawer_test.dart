import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vital_reg_mobile/app/view/app_drawer.dart';
import 'package:vital_reg_mobile/core/offline/pending_sends.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';

import '../../helpers/pump_app.dart';

/// [unsent] registrations; sending clears [sendable] of them.
class _FakePendingSends implements PendingSends {
  _FakePendingSends(this.unsent, {this.sendable = 0});

  int unsent;
  final int sendable;
  int sends = 0;

  @override
  Future<int> count() async => unsent;

  @override
  Future<void> sendNow() async {
    sends++;
    unsent -= sendable;
  }
}

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

  Future<void> openDrawerAndTapLogOut(
    WidgetTester tester, {
    PendingSends? pendingSends,
  }) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpApp(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: Scaffold(
          key: scaffoldKey,
          drawer: AppDrawer(
            onHome: () {},
            onServices: () {},
            pendingSends: pendingSends,
          ),
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

  testWidgets('with registrations not sent, it says so before logging out', (
    tester,
  ) async {
    await openDrawerAndTapLogOut(tester, pendingSends: _FakePendingSends(2));

    expect(find.text('Registrations not sent'), findsOneWidget);
    expect(find.textContaining('2 registrations saved'), findsOneWidget);

    await tester.tap(find.text('Delete and log out'));
    await tester.pumpAndSettle();

    verify(() => authBloc.add(const AuthLogoutRequested())).called(1);
  });

  testWidgets('sending them first, then the usual question', (tester) async {
    final pending = _FakePendingSends(1, sendable: 1);
    await openDrawerAndTapLogOut(tester, pendingSends: pending);

    await tester.tap(find.text('Send now'));
    await tester.pumpAndSettle();

    expect(pending.sends, 1);
    expect(find.text('Log out?'), findsOneWidget);
    verifyNever(() => authBloc.add(any()));
  });

  testWidgets('what could not be sent is asked about again', (tester) async {
    final pending = _FakePendingSends(1);
    await openDrawerAndTapLogOut(tester, pendingSends: pending);

    await tester.tap(find.text('Send now'));
    await tester.pumpAndSettle();
    expect(find.text('Registrations not sent'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => authBloc.add(any()));
  });
}
