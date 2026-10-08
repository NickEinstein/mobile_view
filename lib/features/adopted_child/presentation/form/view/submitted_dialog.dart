part of 'adoption_form_page.dart';

/// "Application Successfully Submitted", with the number to copy.
/// Completes when the user taps OK.
Future<void> _showSubmittedDialog(
  BuildContext context, {
  required String trackingId,
  bool corrected = false,
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
          Text(
            corrected ? l10n.acResubmittedTitle : l10n.brSubmittedTitle,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              color: AppPalette.brand,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            corrected
                ? l10n.acResubmittedMessage
                : '${l10n.brSubmittedMessage} ${l10n.brSubmittedNinReminder}',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppPalette.ink),
          ),
          const SizedBox(height: Spacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: SelectableText(
                  trackingId,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppPalette.inkStrong,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.brCopyTrackingId,
                color: AppPalette.brand,
                icon: const Icon(Icons.copy_outlined),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: trackingId));
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.brTrackingIdCopied)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          AppButton(
            label: l10n.brOk,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  },
);
