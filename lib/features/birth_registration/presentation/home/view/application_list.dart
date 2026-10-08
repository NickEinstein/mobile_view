part of 'birth_registration_home_page.dart';

class _ApplicationList extends StatelessWidget {
  const _ApplicationList({required this.onOpen});

  final OpenApplication onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ApplicationsCubit>().state;
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
              child: Text(l10n.brNoApplications, textAlign: TextAlign.center),
            );
    }
    return Column(
      children: [
        for (final item in state.items) ...[
          _ApplicationTile(
            item: item,
            onOpen: () => unawaited(onOpen(item.id)),
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ],
    );
  }
}

enum _Action { view, copyTrackingId }

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.item, required this.onOpen});

  final BirthApplicationSummary item;
  final VoidCallback onOpen;

  Future<void> _act(BuildContext context, _Action action) async {
    switch (action) {
      case _Action.view:
        onOpen();
      case _Action.copyTrackingId:
        final messenger = ScaffoldMessenger.of(context);
        final copied = context.l10n.brTrackingIdCopied;
        await Clipboard.setData(ClipboardData(text: item.trackingId));
        messenger.showSnackBar(SnackBar(content: Text(copied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(item.submittedOn);

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
                    StatusChip(status: item.status),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      item.childName,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppPalette.inkStrong,
                      ),
                    ),
                    Text(
                      '${item.trackingId} · $date',
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
                  PopupMenuItem(
                    value: _Action.view,
                    child: Text(l10n.brViewDetails),
                  ),
                  PopupMenuItem(
                    value: _Action.copyTrackingId,
                    child: Text(l10n.brCopyTrackingId),
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
