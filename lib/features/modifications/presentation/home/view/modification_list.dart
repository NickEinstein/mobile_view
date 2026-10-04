part of 'modifications_home_page.dart';

class _ModificationList extends StatelessWidget {
  const _ModificationList({required this.onOpenQueried});

  final ValueChanged<String> onOpenQueried;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ModificationsCubit>().state;
    final failure = state.failure;
    if (failure != null) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Text(failure.localize(l10n), textAlign: TextAlign.center),
      );
    }
    if (state.items.isEmpty) {
      return state.isLoading
          ? const Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          : Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text(l10n.modNoRequests, textAlign: TextAlign.center),
            );
    }
    return Column(
      children: [
        for (final item in state.items) ...[
          _ModificationTile(
            item: item,
            onRespond: item.status == ModificationStatus.queried
                ? () => onOpenQueried(item.id)
                : null,
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ],
    );
  }
}

enum _Action { respond, copyCertificateNumber }

class _ModificationTile extends StatelessWidget {
  const _ModificationTile({required this.item, this.onRespond});

  final ModificationSummary item;

  /// Only for a queried request.
  final VoidCallback? onRespond;

  Future<void> _act(BuildContext context, _Action action) async {
    switch (action) {
      case _Action.respond:
        onRespond?.call();
      case _Action.copyCertificateNumber:
        final messenger = ScaffoldMessenger.of(context);
        final copied = context.l10n.modCertificateNumberCopied;
        await Clipboard.setData(ClipboardData(text: item.certificateNumber));
        messenger.showSnackBar(SnackBar(content: Text(copied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final modifiedOn = item.modifiedOn;
    final date = modifiedOn == null
        ? null
        : DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(modifiedOn);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppPalette.cardBorder),
        borderRadius: BorderRadius.circular(Spacing.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onRespond,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.sm + Spacing.xs,
            Spacing.sm,
            0,
            Spacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ModificationStatusChip(status: item.status),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      item.name,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppPalette.inkStrong,
                      ),
                    ),
                    Text(
                      [
                        item.certificateNumber,
                        ?date,
                      ].where((part) => part.isNotEmpty).join(' · '),
                      style: textTheme.labelSmall?.copyWith(
                        color: AppPalette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_Action>(
                tooltip: l10n.brMoreActions,
                icon: const Icon(Icons.more_vert),
                onSelected: (action) => unawaited(_act(context, action)),
                itemBuilder: (_) => [
                  if (onRespond != null)
                    PopupMenuItem(
                      value: _Action.respond,
                      child: Text(l10n.modRespondToQuery),
                    ),
                  PopupMenuItem(
                    value: _Action.copyCertificateNumber,
                    enabled: item.certificateNumber.isNotEmpty,
                    child: Text(l10n.modCopyCertificateNumber),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
