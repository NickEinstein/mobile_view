import 'package:flutter/material.dart';

/// Primary action button. It disables itself while [isLoading] so a request
/// can't be submitted twice.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.muted = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Looks disabled but still responds, e.g. "Next" on an incomplete step,
  /// where a tap points out what's missing.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final disabledStyle = Theme.of(context).filledButtonTheme.style;
    const disabled = {WidgetState.disabled};
    return FilledButton(
      style: muted
          ? FilledButton.styleFrom(
              backgroundColor: disabledStyle?.backgroundColor?.resolve(
                disabled,
              ),
              foregroundColor: disabledStyle?.foregroundColor?.resolve(
                disabled,
              ),
            )
          : null,
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : Text(label),
    );
  }
}
