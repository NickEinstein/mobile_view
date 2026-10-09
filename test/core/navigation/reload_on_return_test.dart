import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/navigation/reload_on_return.dart';
import 'package:vital_reg_mobile/core/network/record_changes.dart';

void main() {
  late int returns;
  late RecordChanges changes;
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> pumpHome(WidgetTester tester) async {
    returns = 0;
    changes = RecordChanges();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [appRouteObserver],
        home: ReloadOnReturn(
          onReturn: () => returns++,
          changes: changes,
          child: const Text('home'),
        ),
      ),
    );
  }

  testWidgets('a page closing over it calls onReturn', (tester) async {
    await pumpHome(tester);
    navigatorKey.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const Text('form')))
        .ignore();
    await tester.pumpAndSettle();
    expect(returns, 0);

    changes.bump();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(returns, 1);
  });

  testWidgets('a replaced page closing still calls onReturn', (tester) async {
    await pumpHome(tester);
    navigatorKey.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const Text('nin check')))
        .ignore();
    await tester.pumpAndSettle();
    navigatorKey.currentState!
        .pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const Text('form')),
        )
        .ignore();
    await tester.pumpAndSettle();

    changes.bump();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(returns, 1);
  });

  testWidgets('closing a dialog does not', (tester) async {
    await pumpHome(tester);
    showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (_) => const Text('dialog'),
    ).ignore();
    await tester.pumpAndSettle();

    changes.bump();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(returns, 0);
  });

  testWidgets('without a write since it loaded, it does not', (tester) async {
    await pumpHome(tester);
    for (var i = 0; i < 2; i++) {
      navigatorKey.currentState!
          .push(MaterialPageRoute<void>(builder: (_) => const Text('module')))
          .ignore();
      await tester.pumpAndSettle();
      // Only the first visit writes.
      if (i == 0) changes.bump();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
    }
    expect(returns, 1);
  });

  testWidgets('inside a nested navigator, a root page closing calls it', (
    tester,
  ) async {
    returns = 0;
    changes = RecordChanges();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [appRouteObserver],
        // Like the app shell's tab navigator.
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => ReloadOnReturn(
              onReturn: () => returns++,
              changes: changes,
              child: const Text('home tab'),
            ),
          ),
        ),
      ),
    );
    navigatorKey.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const Text('module')))
        .ignore();
    await tester.pumpAndSettle();

    changes.bump();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(returns, 1);
  });
}
