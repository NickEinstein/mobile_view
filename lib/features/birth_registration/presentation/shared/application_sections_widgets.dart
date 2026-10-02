part of 'application_sections.dart';

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.rows,
    required this.incomplete,
    this.onEdit,
  });

  final String title;
  final List<Widget> rows;
  final bool incomplete;

  /// Null hides the Edit link.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final onEdit = this.onEdit;
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
            const SizedBox(height: Spacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
            if (incomplete)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.xs,
                  Spacing.sm,
                  Spacing.xs,
                  0,
                ),
                child: Text(
                  l10n.brSectionIncomplete,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (onEdit == null)
              const SizedBox(height: Spacing.sm)
            else
              Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  button: true,
                  label: l10n.brEditSection(title),
                  excludeSemantics: true,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppPalette.gold,
                    ),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(l10n.brEdit),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A label and the value given, e.g. "SURNAME / Garba".
class _Entry extends StatelessWidget {
  const _Entry(this.label, this.value);

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

/// Whether a photo, signature or document was provided: ✓ or ✗.
class _Status extends StatelessWidget {
  const _Status(this.label, {required this.provided, this.detail});

  final String label;
  final bool provided;

  /// E.g. the file name.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                  semanticLabel: provided
                      ? l10n.brProvided
                      : l10n.brNotProvided,
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

/// Separates groups of entries within a card.
class _Group extends StatelessWidget {
  const _Group();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: Spacing.md, color: AppPalette.cardBorder);
}

/// "Place of Usual Residence", centred between dividers.
class _Subheading extends StatelessWidget {
  const _Subheading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _Group(),
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
