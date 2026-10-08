import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_code_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_dialog.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/auth/domain/auth_repository.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';
import 'package:vital_reg_mobile/features/auth/presentation/password_reset/cubit/password_reset_cubit.dart';
import 'package:vital_reg_mobile/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'password_reset_steps.dart';
part 'verify_code_dialog.dart';

/// Composition only: provides the cubit. [onExit] (from the router) returns
/// to login, from "Back" or after the password has been reset.
class PasswordResetPage extends StatelessWidget {
  const PasswordResetPage({required this.onExit, super.key});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PasswordResetCubit(GetIt.instance<AuthRepository>()),
      child: PasswordResetView(onExit: onExit),
    );
  }
}

class PasswordResetView extends StatelessWidget {
  const PasswordResetView({required this.onExit, super.key});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final step = context.select((PasswordResetCubit cubit) => cubit.state.step);
    return BlocListener<PasswordResetCubit, PasswordResetState>(
      listenWhen: (previous, current) => previous.step != current.step,
      listener: (context, state) {
        switch (state.step) {
          case PasswordResetStep.code:
            unawaited(_verifyEmail(context));
          case PasswordResetStep.done:
            unawaited(_confirmReset(context));
          case PasswordResetStep.email ||
              PasswordResetStep.verified ||
              PasswordResetStep.newPassword:
            break;
        }
      },
      child: switch (step) {
        PasswordResetStep.email ||
        PasswordResetStep.code ||
        PasswordResetStep.verified => _EmailStep(onBack: onExit),
        PasswordResetStep.newPassword ||
        PasswordResetStep.done => _NewPasswordStep(onBack: onExit),
      },
    );
  }

  /// Code dialog, then "Verification Successful" if the code was accepted.
  Future<void> _verifyEmail(BuildContext context) async {
    final cubit = context.read<PasswordResetCubit>();
    await showDialog<void>(
      context: context,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _VerifyCodeDialog()),
    );
    if (!context.mounted) return;
    if (cubit.state.step != PasswordResetStep.verified) {
      cubit.codeDismissed();
      return;
    }

    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppStatusDialog(
        title: l10n.verifiedTitle,
        message: l10n.verifiedMessage,
        actionLabel: l10n.proceed,
        onAction: () => Navigator.of(dialogContext).pop(),
      ),
    );
    cubit.startNewPassword();
  }

  /// "Password Reset Successful", then back to login.
  Future<void> _confirmReset(BuildContext context) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppStatusDialog(
        title: l10n.resetDoneTitle,
        message: l10n.resetDoneMessage,
        actionLabel: l10n.proceed,
        onAction: () => Navigator.of(dialogContext).pop(),
      ),
    );
    onExit();
  }
}

/// Failure message from the last request, shown under the form.
class _FailureText extends StatelessWidget {
  const _FailureText();

  @override
  Widget build(BuildContext context) {
    // While the code dialog is open, it shows the error itself.
    final failure = context.select(
      (PasswordResetCubit cubit) => cubit.state.step == PasswordResetStep.code
          ? null
          : cubit.state.failure,
    );
    if (failure == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Text(
        failure.localize(context.l10n),
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
