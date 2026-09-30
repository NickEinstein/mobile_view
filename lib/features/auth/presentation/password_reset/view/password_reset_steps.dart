part of 'password_reset_page.dart';

/// "Forgot Password": enter the account email.
class _EmailStep extends StatelessWidget {
  const _EmailStep({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PasswordResetCubit>();
    final (error, canSend, isSending) = context.select(
      (PasswordResetCubit cubit) => (
        cubit.state.email.displayError,
        cubit.state.canSendCode,
        cubit.state.isSubmitting && cubit.state.step == PasswordResetStep.email,
      ),
    );

    return AuthScaffold(
      title: l10n.forgotPasswordTitle,
      highlight: l10n.forgotPasswordTitleHighlight,
      subtitle: l10n.forgotPasswordSubtitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: l10n.emailLabel,
            hintText: l10n.emailHint,
            errorText: switch (error) {
              EmailError.empty => l10n.emailRequired,
              EmailError.invalid => l10n.emailInvalid,
              null => null,
            },
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.email],
            onChanged: cubit.emailChanged,
            onSubmitted: (_) => unawaited(cubit.sendCode()),
          ),
          const _FailureText(),
        ],
      ),
      actions: [
        AppButton(
          label: l10n.sendCode,
          isLoading: isSending,
          onPressed: canSend ? cubit.sendCode : null,
        ),
        const SizedBox(height: Spacing.sm),
        _BackButton(onPressed: onBack),
      ],
    );
  }
}

/// "Set a new password": new password and confirmation.
class _NewPasswordStep extends StatelessWidget {
  const _NewPasswordStep({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PasswordResetCubit>();
    final (passwordError, confirmationError, canReset, isSubmitting) = context
        .select(
          (PasswordResetCubit cubit) => (
            cubit.state.password.displayError,
            cubit.state.confirmation.displayError,
            cubit.state.canReset,
            cubit.state.isSubmitting,
          ),
        );

    return AuthScaffold(
      title: l10n.newPasswordTitle,
      subtitle: l10n.newPasswordSubtitle,
      body: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: l10n.newPasswordLabel,
              hintText: l10n.passwordHint,
              obscureText: true,
              errorText: switch (passwordError) {
                PasswordError.empty => l10n.passwordRequired,
                PasswordError.tooShort => l10n.passwordTooShort(
                  Password.minLength,
                ),
                null => null,
              },
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: cubit.passwordChanged,
            ),
            const SizedBox(height: Spacing.lg),
            AppTextField(
              label: l10n.confirmPasswordLabel,
              hintText: l10n.passwordHint,
              obscureText: true,
              errorText: switch (confirmationError) {
                ConfirmedPasswordError.empty => l10n.passwordRequired,
                ConfirmedPasswordError.mismatch => l10n.passwordMismatch,
                null => null,
              },
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: cubit.confirmationChanged,
              onSubmitted: (_) => unawaited(cubit.resetPassword()),
            ),
            const _FailureText(),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: l10n.resetPasswordButton,
          isLoading: isSubmitting,
          onPressed: canReset ? cubit.resetPassword : null,
        ),
        const SizedBox(height: Spacing.sm),
        _BackButton(onPressed: onBack),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppPalette.inkStrong,
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: onPressed,
      child: Text(context.l10n.back),
    );
  }
}
