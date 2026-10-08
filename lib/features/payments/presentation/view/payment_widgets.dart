part of 'payment_page.dart';

/// "Make Payment | Enter Reference", drawn like the design's Card/Transfer
/// tabs: the selected one outlined in green.
class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onChanged});

  final PaymentMode mode;
  final ValueChanged<PaymentMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    Widget tab(PaymentMode value, String label) {
      final selected = value == mode;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Spacing.sm),
              side: BorderSide(
                color: selected ? AppPalette.brand : Colors.transparent,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(Spacing.sm),
              onTap: onChanged == null ? null : () => onChanged!(value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: selected ? AppPalette.inkStrong : AppPalette.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(PaymentMode.makePayment, l10n.baMakePayment),
        const SizedBox(width: Spacing.sm),
        tab(PaymentMode.enterReference, l10n.baEnterReference),
      ],
    );
  }
}

/// Email for the code and reference, with the fee notes.
class _MakePayment extends StatelessWidget {
  const _MakePayment({required this.state, required this.quote});

  final PaymentState state;
  final PaymentQuote quote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PaymentCubit>();
    final reference = state.payment?.reference;
    if (state.hasPendingPayment && reference != null) {
      return _Note(l10n.baPendingPayment(reference));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: l10n.emailLabel,
          hintText: l10n.emailHint,
          initialValue: state.email.value,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          errorText: state.email.displayError == null
              ? null
              : l10n.emailInvalid,
          onChanged: cubit.emailChanged,
        ),
        const SizedBox(height: Spacing.sm),
        _Note(
          l10n.baFeeNote(
            formatNaira(context, quote.total, currency: quote.currency),
          ),
        ),
        _Note(l10n.baReferenceEmailNote),
      ],
    );
  }
}

/// A reference paid earlier.
class _EnterReference extends StatelessWidget {
  const _EnterReference({required this.state});

  final PaymentState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PaymentCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: l10n.baReferenceLabel,
          hintText: l10n.baReferenceHint,
          initialValue: state.reference,
          textCapitalization: TextCapitalization.characters,
          onChanged: cubit.referenceChanged,
          onSubmitted: (_) => unawaited(cubit.verifyReference()),
        ),
        const SizedBox(height: Spacing.sm),
        _Note(l10n.baReferenceNote),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Spacing.xs),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppPalette.ink),
    ),
  );
}

/// The green "Summary" card: subtotal, VAT and total.
class _Summary extends StatelessWidget {
  const _Summary({required this.quote});

  final PaymentQuote quote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Colors.white);

    Widget row(String label, int kobo) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            formatNaira(context, kobo, currency: quote.currency),
            style: style,
          ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.brand,
        borderRadius: BorderRadius.circular(Spacing.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.baSummary,
              style: style?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Spacing.sm),
            // The API gives one amount; the gateway adds its charges.
            row(l10n.baTotal, quote.total),
          ],
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        TextButton(onPressed: onRetry, child: Text(context.l10n.tryAgain)),
      ],
    ),
  );
}

/// "Payment Verified Successfully", with the payment reference to copy.
/// Completes when the user taps Continue.
Future<void> _showVerifiedDialog(
  BuildContext context, {
  required String reference,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) {
    final l10n = dialogContext.l10n;
    final textTheme = Theme.of(dialogContext).textTheme;
    return PopScope(
      canPop: false,
      child: AppDialog(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppPalette.brand,
            size: 48,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            l10n.baPaymentVerifiedTitle,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              color: AppPalette.brand,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.baPaymentVerifiedMessage,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppPalette.ink),
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.fieldFill,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    reference,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppPalette.inkStrong,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.baCopyReference,
                color: AppPalette.brand,
                icon: const Icon(Icons.copy_outlined),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: reference));
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.baReferenceCopied)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          AppButton(
            label: l10n.baContinue,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  },
);
