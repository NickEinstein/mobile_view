part of 'login_page.dart';

class _SessionEndedBanner extends StatelessWidget {
  const _SessionEndedBanner({required this.reason});

  final SessionEndReason reason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = switch (reason) {
      SessionEndReason.inactivity => l10n.sessionTimedOut,
      SessionEndReason.expired => l10n.sessionExpired,
      SessionEndReason.invalid => l10n.sessionInvalid,
      SessionEndReason.userInitiated => '',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.warningContainer,
        borderRadius: BorderRadius.circular(Spacing.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text(
          message,
          style: const TextStyle(color: AppPalette.onWarningContainer),
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = context.select(
      (LoginCubit cubit) => cubit.state.email.displayError,
    );
    return AppTextField(
      label: l10n.emailLabel,
      hintText: l10n.emailHint,
      errorText: switch (error) {
        EmailError.empty => l10n.emailRequired,
        EmailError.invalid => l10n.emailInvalid,
        null => null,
      },
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email, AutofillHints.username],
      onChanged: context.read<LoginCubit>().emailChanged,
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = context.select(
      (LoginCubit cubit) => cubit.state.password.displayError,
    );
    return AppTextField(
      label: l10n.passwordLabel,
      hintText: l10n.passwordHint,
      obscureText: true,
      errorText: switch (error) {
        PasswordError.empty => l10n.passwordRequired,
        PasswordError.tooShort => l10n.passwordTooShort(Password.minLength),
        null => null,
      },
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      onChanged: context.read<LoginCubit>().passwordChanged,
      onSubmitted: (_) => unawaited(context.read<LoginCubit>().submit()),
    );
  }
}

class _ForgotPassword extends StatelessWidget {
  const _ForgotPassword({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppPalette.muted);
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        ),
        onPressed: onPressed,
        child: Text.rich(
          TextSpan(
            text: '${l10n.forgotPasswordPrompt} ',
            children: [
              TextSpan(
                text: l10n.forgotPasswordAction,
                style: const TextStyle(
                  color: AppPalette.brand,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          style: style,
        ),
      ),
    );
  }
}

class _FailureText extends StatelessWidget {
  const _FailureText();

  @override
  Widget build(BuildContext context) {
    final failure = context.select((LoginCubit cubit) => cubit.state.failure);
    if (failure == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Text(
        failure.localize(context.l10n),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton();

  @override
  Widget build(BuildContext context) {
    final (canSubmit, isBusy) = context.select(
      (LoginCubit cubit) => (cubit.state.canSubmit, cubit.state.status.isBusy),
    );
    return AppButton(
      label: context.l10n.loginButton,
      isLoading: isBusy,
      // Grey until both fields have text, as in the designs.
      onPressed: canSubmit ? context.read<LoginCubit>().submit : null,
    );
  }
}
