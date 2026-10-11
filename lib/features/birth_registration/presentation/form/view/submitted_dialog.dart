part of 'registration_form_page.dart';

/// Offline: the application is on the device, waiting to be sent.
/// Completes when the user taps Ok.
Future<void> _showSavedForLaterDialog(BuildContext context) => showDialog<void>(
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
            l10n.brSavedForLaterTitle,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              color: AppPalette.brand,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.brSavedForLaterMessage,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppPalette.ink),
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

/// "Application Successfully Submitted", with the tracking ID to copy if
/// the API gave one. Completes when the user taps Ok.
Future<void> _showSubmittedDialog(
  BuildContext context, {
  required String? trackingId,
  required bool remindNin,
  bool correction = false,
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
            correction
                ? l10n.brCorrectionSubmittedTitle
                : l10n.brSubmittedTitle,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              color: AppPalette.brand,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            [
              if (correction)
                l10n.brCorrectionSubmittedMessage
              else
                l10n.brSubmittedMessage,
              if (remindNin) l10n.brSubmittedNinReminder,
            ].join(' '),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppPalette.ink),
          ),
          if (trackingId != null) ...[
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
                      trackingId,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppPalette.inkStrong,
                        letterSpacing: 0.5,
                      ),
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
          ],
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
