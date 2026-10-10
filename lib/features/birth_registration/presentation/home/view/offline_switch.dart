part of 'birth_registration_home_page.dart';

/// The app bar's offline switch. Turning it on first downloads the latest
/// place lists (with [stateId]'s LGAs and centres) while still online.
class _OfflineSwitch extends StatefulWidget {
  const _OfflineSwitch({
    required this.mode,
    required this.repository,
    this.stateId,
  });

  final OfflineMode mode;
  final BirthRegistrationRepository repository;
  final String? stateId;

  @override
  State<_OfflineSwitch> createState() => _OfflineSwitchState();
}

class _OfflineSwitchState extends State<_OfflineSwitch> {
  bool _busy = false;

  Future<void> _turn({required bool on}) async {
    if (on) {
      setState(() => _busy = true);
      final stateId = widget.stateId;
      final lists = await widget.repository.referenceData(
        withLgasOf: [?stateId],
      );
      if (!mounted) return;
      if (lists is Err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.brOfflineListsNotUpdated)),
        );
      }
    }
    await widget.mode.turn(on: on);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.mode,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.brOfflineSwitch,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: widget.mode.isOn ? AppPalette.onWarningContainer : null,
            ),
          ),
          Switch(
            value: widget.mode.isOn,
            onChanged: _busy ? null : (on) => unawaited(_turn(on: on)),
          ),
        ],
      ),
    );
  }
}

/// Shown while offline mode is on.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.mode});

  final OfflineMode mode;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mode,
      builder: (context, _) => !mode.isOn
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: Spacing.md),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.warningContainer,
                  borderRadius: BorderRadius.circular(Spacing.sm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        color: AppPalette.onWarningContainer,
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          context.l10n.brOfflineBanner,
                          style: const TextStyle(
                            color: AppPalette.onWarningContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// "Waiting to send (n)", while any application saved offline is on the
/// device; opens the list.
class _OutboxCard extends StatelessWidget {
  const _OutboxCard({required this.onOpen});

  final OpenScreen onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<OutboxCubit>();
    final entries = context.select((OutboxCubit c) => c.state.entries);
    if (entries.isEmpty) return const SizedBox.shrink();
    final needsAttention = entries.any(
      (e) =>
          e.status == OutboxStatus.needsFix ||
          e.status == OutboxStatus.possibleDuplicate,
    );
    final color = needsAttention ? AppPalette.danger : AppPalette.brand;
    return ReloadOnReturn(
      changes: outboxChanges,
      onReturn: () {
        if (!cubit.isClosed) cubit.load().ignore();
      },
      child: Padding(
        padding: const EdgeInsets.only(top: Spacing.md),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: color),
            borderRadius: BorderRadius.circular(Spacing.sm),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: Icon(
              needsAttention ? Icons.error_outline : Icons.outbox_outlined,
              color: color,
            ),
            title: Text(l10n.brOutboxCard(entries.length)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(onOpen()),
          ),
        ),
      ),
    );
  }
}
