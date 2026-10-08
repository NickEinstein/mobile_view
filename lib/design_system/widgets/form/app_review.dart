import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';

// The review ("Information Preview") cards, as the designs draw them.

/// A bordered card with a green-edged title and an "Edit" link.
class AppReviewCard extends StatelessWidget {
  const AppReviewCard({
    required this.title,
    required this.rows,
    this.incomplete = false,
    this.editLabel,
    this.onEdit,
    super.key,
  });

  final String title;
  final List<Widget> rows;

  /// Outlined in red: something in it still needs filling in.
  final bool incomplete;
  final String? editLabel;

  /// Null hides the Edit link.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onEdit = this.onEdit;
    final editLabel = this.editLabel;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: incomplete ? theme.colorScheme.error : AppPalette.cardBorder,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.sm,
          Spacing.sm,
          Spacing.sm,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: AppPalette.fieldFill,
                  border: Border(
                    left: BorderSide(color: AppPalette.brand, width: 3),
                  ),
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppPalette.inkStrong,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            ...rows,
            if (onEdit != null && editLabel != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppPalette.accentYellow,
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(editLabel),
                ),
              )
            else
              const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }
}

/// A label and the value given, e.g. "SURNAME / Garba".
class AppReviewEntry extends StatelessWidget {
  const AppReviewEntry(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(color: AppPalette.muted),
            ),
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                color: AppPalette.inkStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether a photo or document was provided: ✓ or ✗, with its name.
class AppReviewStatus extends StatelessWidget {
  const AppReviewStatus(
    this.label, {
    required this.provided,
    required this.providedLabel,
    required this.notProvidedLabel,
    this.detail,
    super.key,
  });

  final String label;
  final bool provided;

  /// Read by screen readers for the ✓ and ✗.
  final String providedLabel;
  final String notProvidedLabel;

  /// E.g. the file name.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detail = this.detail;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(color: AppPalette.muted),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  provided ? Icons.check_circle_outline : Icons.highlight_off,
                  size: 20,
                  color: provided ? AppPalette.brand : AppPalette.danger,
                  semanticLabel: provided ? providedLabel : notProvidedLabel,
                ),
                if (detail != null) ...[
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppPalette.ink,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Place of Usual Residence", centred under a divider.
class AppReviewSubheading extends StatelessWidget {
  const AppReviewSubheading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Divider(height: Spacing.md, color: AppPalette.cardBorder),
      Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppPalette.inkStrong),
      ),
    ],
  );
}
