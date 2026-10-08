import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/auth/domain/auth_repository.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vital_reg_mobile/features/auth/presentation/login/cubit/login_cubit.dart';
import 'package:vital_reg_mobile/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'login_form_fields.dart';

/// Product name in the heading. Not translated.
const _brand = 'VitalReg';

/// Provides the cubit; the UI is [LoginView].
class LoginPage extends StatelessWidget {
  const LoginPage({required this.onForgotPassword, super.key});

  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(GetIt.instance<AuthRepository>()),
      child: LoginView(onForgotPassword: onForgotPassword),
    );
  }
}

class LoginView extends StatelessWidget {
  const LoginView({required this.onForgotPassword, super.key});

  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = context.watch<AuthBloc>().state;
    final endReason = authState is AuthUnauthenticated
        ? authState.reason
        : null;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, current) =>
          current is AuthUnauthenticated &&
          current.reason == SessionEndReason.invalid,
      listener: (context, _) => context.read<LoginCubit>().sessionRejected(),
      child: AuthScaffold(
        title: l10n.loginWelcome(_brand),
        highlight: _brand,
        subtitle: l10n.loginSubtitle,
        body: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (endReason case final reason?
                  when reason != SessionEndReason.userInitiated) ...[
                _SessionEndedBanner(reason: reason),
                const SizedBox(height: Spacing.md),
              ],
              const _EmailField(),
              const SizedBox(height: Spacing.lg),
              const _PasswordField(),
              _ForgotPassword(onPressed: onForgotPassword),
              const _FailureText(),
            ],
          ),
        ),
        actions: const [_SubmitButton()],
      ),
    );
  }
}
