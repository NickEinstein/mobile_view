import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vital_reg_mobile/features/auth/presentation/login/cubit/login_cubit.dart';
import 'package:vital_reg_mobile/features/auth/presentation/login/view/login_page.dart';

import '../../helpers/pump_app.dart';

class _MockLoginCubit extends MockCubit<LoginState> implements LoginCubit {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _filled = LoginState(
  email: Email.dirty('ada@example.com'),
  password: Password.dirty('correct-horse'),
);

void main() {
  late _MockLoginCubit loginCubit;
  late _MockAuthBloc authBloc;

  setUp(() {
    loginCubit = _MockLoginCubit();
    authBloc = _MockAuthBloc();
    when(() => loginCubit.state).thenReturn(const LoginState());
    when(() => loginCubit.submit()).thenAnswer((_) async {});
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());
  });

  Widget subject() => MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<LoginCubit>.value(value: loginCubit),
    ],
    child: const LoginView(),
  );

  FilledButton loginButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('shows the welcome heading and both fields', (tester) async {
    await tester.pumpApp(subject());

    expect(
      find.text('Welcome to VitalReg!', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('Login is disabled until both fields have text', (tester) async {
    await tester.pumpApp(subject());

    expect(loginButton(tester).onPressed, isNull);
  });

  testWidgets('submits when Login is tapped on a filled form', (tester) async {
    when(() => loginCubit.state).thenReturn(_filled);
    await tester.pumpApp(subject());

    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));

    verify(() => loginCubit.submit()).called(1);
  });

  testWidgets('explains a sign-out caused by inactivity', (tester) async {
    when(() => authBloc.state).thenReturn(
      const AuthUnauthenticated(reason: SessionEndReason.inactivity),
    );

    await tester.pumpApp(subject());

    expect(
      find.text('You were signed out after a period of inactivity.'),
      findsOneWidget,
    );
  });
}
