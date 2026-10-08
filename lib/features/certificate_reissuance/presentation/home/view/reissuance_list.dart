part of 'reissuance_home_page.dart';

class _ReissuanceList extends StatelessWidget {
  const _ReissuanceList({
    required this.onOpenDetails,
    required this.onUpdate,
    required this.onDownload,
  });

  final ValueChanged<String> onOpenDetails;
  final ValueChanged<String> onUpdate;
  final void Function(ReissuanceKind kind, String reference) onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ReissuanceHomeCubit>().state;
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
              child: Text(l10n.crNoRequests, textAlign: TextAlign.center),
            );
    }
    return Column(
      children: [
        for (final item in state.items) ...[
          _ReissuanceTile(
            item: item,
            onOpen: () => onOpenDetails(item.id),
            onUpdate: item.status == ReissuanceStatus.queried
                ? () => onUpdate(item.id)
                : null,
            onDownload:
                item.status == ReissuanceStatus.approved &&
                    item.reference.isNotEmpty
                ? () => onDownload(state.kind, item.reference)
                : null,
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ],
    );
  }
}

enum _Action { view, update, download, copyReference }

class _ReissuanceTile extends StatelessWidget {
  const _ReissuanceTile({
    required this.item,
    this.onOpen,
    this.onUpdate,
    this.onDownload,
  });

  final ReissuanceSummary item;

  /// Each is null where it doesn't apply: Update only for a queried
  /// request, Download only for an approved one.
  final VoidCallback? onOpen;
  final VoidCallback? onUpdate;
  final VoidCallback? onDownload;

  Future<void> _act(BuildContext context, _Action action) async {
    switch (action) {
      case _Action.view:
        onOpen?.call();
      case _Action.update:
        onUpdate?.call();
      case _Action.download:
        onDownload?.call();
      case _Action.copyReference:
        final messenger = ScaffoldMessenger.of(context);
        final copied = context.l10n.crReferenceCopied;
        await Clipboard.setData(ClipboardData(text: item.reference));
        messenger.showSnackBar(SnackBar(content: Text(copied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final createdOn = item.createdOn;
    final date = createdOn == null
        ? null
        : DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(createdOn);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppPalette.cardBorder),
        borderRadius: BorderRadius.circular(Spacing.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
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
                    ReissuanceStatusChip(status: item.status),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      item.name,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppPalette.inkStrong,
                      ),
                    ),
                    Text(
                      [
                        item.reference,
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
                  if (onOpen != null)
                    PopupMenuItem(
                      value: _Action.view,
                      child: Text(l10n.crViewDetails),
                    ),
                  if (onUpdate != null)
                    PopupMenuItem(
                      value: _Action.update,
                      child: Text(l10n.crUpdate),
                    ),
                  if (onDownload != null)
                    PopupMenuItem(
                      value: _Action.download,
                      child: Text(l10n.crDownload),
                    ),
                  PopupMenuItem(
                    value: _Action.copyReference,
                    enabled: item.reference.isNotEmpty,
                    child: Text(l10n.crCopyReference),
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
