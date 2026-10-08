part of 'password_reset_page.dart';

/// "Email Verification": the 4-digit code sent to the user's email.
/// Closes itself once the code is accepted.
class _VerifyCodeDialog extends StatelessWidget {
  const _VerifyCodeDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<PasswordResetCubit>();
    final (maskedEmail, canVerify, isSubmitting, failure) = context.select(
      (PasswordResetCubit cubit) => (
        cubit.state.email.masked,
        cubit.state.canVerify,
        cubit.state.isSubmitting,
        cubit.state.failure,
      ),
    );

    return BlocListener<PasswordResetCubit, PasswordResetState>(
      listenWhen: (previous, current) =>
          previous.step != current.step &&
          current.step == PasswordResetStep.verified,
      listener: (context, _) => Navigator.of(context).pop(),
      child: AppDialog(
        children: [
          Text(
            l10n.verifyEmailTitle,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              color: AppPalette.brand,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.verifyEmailMessage(maskedEmail),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppPalette.ink),
          ),
          const SizedBox(height: Spacing.lg),
          AppCodeField(
            length: OtpCode.length,
            semanticLabel: l10n.codeFieldLabel,
            hasError: failure != null,
            onChanged: cubit.codeChanged,
            onSubmitted: (_) => unawaited(cubit.verifyCode()),
          ),
          const _ResendCode(),
          if (failure != null)
            Text(
              failure.localize(l10n),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: Spacing.lg),
          AppButton(
            label: l10n.verify,
            isLoading: isSubmitting,
            onPressed: canVerify ? cubit.verifyCode : null,
          ),
        ],
      ),
    );
  }
}

/// "Didn't get a code? Resend OTP", with a countdown after each send.
class _ResendCode extends StatelessWidget {
  const _ResendCode();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (cooldown, isSubmitting) = context.select(
      (PasswordResetCubit cubit) =>
          (cubit.state.resendCooldown, cubit.state.isSubmitting),
    );
    final canResend = cooldown <= 0 && !isSubmitting;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppPalette.ink);

    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        ),
        onPressed: canResend
            ? () => unawaited(context.read<PasswordResetCubit>().resendCode())
            : null,
        child: Text.rich(
          TextSpan(
            text: '${l10n.resendPrompt} ',
            children: [
              TextSpan(
                text: canResend
                    ? l10n.resendAction
                    : l10n.resendCountdown(cooldown),
                style: TextStyle(
                  color: canResend ? AppPalette.brand : AppPalette.muted,
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
