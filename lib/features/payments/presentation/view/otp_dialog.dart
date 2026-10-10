part of 'payment_page.dart';

/// "Authorize Transaction": the code emailed to the payer. Closes itself
/// once the code is accepted (or the user backs out).
Future<void> _showOtpDialog(BuildContext context) {
  final cubit = context.read<PaymentCubit>();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) cubit.cancelOtp();
        },
        child: const _OtpDialog(),
      ),
    ),
  );
}

/// A wrong or used code comes back as 404; an expired one as 406 with its
/// own message.
String _otpError(Failure failure, AppLocalizations l10n) => switch (failure) {
  NotFoundFailure() => l10n.baOtpInvalid,
  _ => failure.localize(l10n),
};

bool _isCodeStep(PaymentStep step) =>
    step == PaymentStep.otp || step == PaymentStep.confirmingOtp;

class _OtpDialog extends StatelessWidget {
  const _OtpDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<PaymentCubit>();
    final state = context.watch<PaymentCubit>().state;
    final failure = state.failure;
    final isConfirming = state.step != PaymentStep.otp;

    return BlocListener<PaymentCubit, PaymentState>(
      // Closes once, as the step leaves the code (accepted or cancelled),
      // before the checkout opens.
      listenWhen: (previous, current) =>
          _isCodeStep(previous.step) && !_isCodeStep(current.step),
      // Unless the dialog is already closing (Close or Back cancelled the
      // code), which would otherwise pop the payment page too.
      listener: (context, _) {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          Navigator.of(context).pop();
        }
      },
      child: AppDialog(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Visibility.maintain(
              visible: !isConfirming,
              child: IconButton(
                tooltip: l10n.baOtpClose,
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppPalette.ink),
              ),
            ),
          ),
          Text(
            l10n.baOtpTitle,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              color: AppPalette.inkStrong,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            l10n.baOtpMessage(state.email.masked),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppPalette.ink),
          ),
          const SizedBox(height: Spacing.lg),
          AppCodeField(
            length: PaymentCubit.otpLength,
            semanticLabel: l10n.baOtpFieldLabel,
            hasError: failure != null,
            onChanged: cubit.otpChanged,
            onSubmitted: (_) => unawaited(cubit.confirmOtp()),
          ),
          _ResendCode(
            cooldown: state.resendCooldown,
            onResend: cubit.resendOtp,
          ),
          if (failure != null)
            Text(
              _otpError(failure, l10n),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: Spacing.lg),
          AppButton(
            label: l10n.baAuthorize,
            isLoading: isConfirming,
            onPressed: state.otpComplete && !isConfirming
                ? cubit.confirmOtp
                : null,
          ),
        ],
      ),
    );
  }
}

/// "Didn't get a code? Resend OTP", with a countdown after each send.
class _ResendCode extends StatelessWidget {
  const _ResendCode({required this.cooldown, required this.onResend});

  final int cooldown;
  final Future<void> Function() onResend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canResend = cooldown <= 0;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        ),
        onPressed: canResend ? () => unawaited(onResend()) : null,
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
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.ink),
        ),
      ),
    );
  }
}
