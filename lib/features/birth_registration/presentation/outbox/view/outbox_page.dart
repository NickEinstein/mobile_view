import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/core/storage/outbox.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/outbox_sync.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/outbox/cubit/outbox_cubit.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Opens an outbox application in the form; completes when the user is
/// back.
typedef EditOutboxEntry = Future<void> Function(String id);

/// "Waiting to send": applications saved offline, with why any of them
/// couldn't be sent.
class OutboxPage extends StatelessWidget {
  const OutboxPage({
    required this.repository,
    required this.sync,
    required this.onEdit,
    super.key,
  });

  final BirthRegistrationRepository repository;
  final OutboxSync sync;
  final EditOutboxEntry onEdit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutboxCubit(repository, sync)..load().ignore(),
      child: OutboxView(onEdit: onEdit),
    );
  }
}

class OutboxView extends StatelessWidget {
  const OutboxView({required this.onEdit, super.key});

  final EditOutboxEntry onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<OutboxCubit>().state;
    final cubit = context.read<OutboxCubit>();
    final sendable = state.entries.any(
      (e) => e.status != OutboxStatus.possibleDuplicate,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            0,
            Spacing.md,
            Spacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.brOutboxTitle,
                style: textTheme.titleLarge?.copyWith(
                  color: AppPalette.inkStrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                l10n.brOutboxIntro,
                style: textTheme.bodyMedium?.copyWith(color: AppPalette.ink),
              ),
              const SizedBox(height: Spacing.md),
              Expanded(
                child: !state.isLoaded
                    ? const Center(child: CircularProgressIndicator())
                    : state.entries.isEmpty
                    ? Center(
                        child: Text(
                          l10n.brOutboxEmpty,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: cubit.load,
                        child: ListView.separated(
                          itemCount: state.entries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: Spacing.sm),
                          itemBuilder: (context, index) {
                            final entry = state.entries[index];
                            return _OutboxTile(
                              entry: entry,
                              sending: entry.id == state.sendingId,
                              busy: state.isSending,
                              onEdit: () => unawaited(_edit(context, entry)),
                            );
                          },
                        ),
                      ),
              ),
              if (sendable) ...[
                const SizedBox(height: Spacing.md),
                AppButton(
                  label: l10n.brOutboxSendAll,
                  isLoading: state.isSending,
                  onPressed: state.isSending
                      ? null
                      : () => unawaited(cubit.sendAll()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Back from the form, the edit (if saved) is sent straight away.
  Future<void> _edit(
    BuildContext context,
    OutboxEntry<RegistrationDraft> entry,
  ) async {
    final cubit = context.read<OutboxCubit>();
    await onEdit(entry.id);
    if (cubit.isClosed) return;
    await cubit.load();
    final edited = cubit.state.entries.where((e) => e.id == entry.id);
    if (edited.firstOrNull?.status == OutboxStatus.waiting) {
      await cubit.send(entry.id);
    }
  }
}

enum _Action { send, edit, delete }

class _OutboxTile extends StatelessWidget {
  const _OutboxTile({
    required this.entry,
    required this.sending,
    required this.busy,
    required this.onEdit,
  });

  final OutboxEntry<RegistrationDraft> entry;
  final bool sending;

  /// Something is being sent; nothing else can start.
  final bool busy;
  final VoidCallback onEdit;

  Future<void> _act(BuildContext context, _Action action) async {
    final cubit = context.read<OutboxCubit>();
    switch (action) {
      case _Action.send:
        await cubit.send(entry.id);
      case _Action.edit:
        onEdit();
      case _Action.delete:
        if (await _confirmDelete(context)) await cubit.remove(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final child = entry.item.child;
    final name = [
      child[ChildField.surname],
      child[ChildField.firstName],
    ].nonNulls.join(' ');
    final saved = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm().format(entry.savedAt);
    final reason = _reason(l10n);
    final duplicate = entry.status == OutboxStatus.possibleDuplicate;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppPalette.cardBorder),
        borderRadius: BorderRadius.circular(Spacing.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.sm + Spacing.xs,
          Spacing.sm,
          0,
          Spacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusLabel(status: entry.status, sending: sending),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    name.isEmpty ? l10n.brOutboxUnnamed : name,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppPalette.inkStrong,
                    ),
                  ),
                  Text(
                    l10n.brOutboxSavedOn(saved),
                    style: textTheme.labelSmall?.copyWith(
                      color: AppPalette.muted,
                    ),
                  ),
                  if (reason != null) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      reason,
                      style: textTheme.bodySmall?.copyWith(
                        color: entry.status == OutboxStatus.retryLater
                            ? AppPalette.ink
                            : AppPalette.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<_Action>(
              tooltip: l10n.brMoreActions,
              icon: const Icon(Icons.more_vert),
              enabled: !sending,
              onSelected: (action) => unawaited(_act(context, action)),
              itemBuilder: (_) => [
                if (!duplicate)
                  PopupMenuItem(
                    value: _Action.send,
                    enabled: !busy,
                    child: Text(l10n.brOutboxSendNow),
                  ),
                if (!duplicate)
                  PopupMenuItem(
                    value: _Action.edit,
                    enabled: !busy,
                    child: Text(l10n.brOutboxEdit),
                  ),
                PopupMenuItem(
                  value: _Action.delete,
                  child: Text(
                    l10n.brOutboxDelete,
                    style: const TextStyle(color: AppPalette.danger),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _reason(AppLocalizations l10n) {
    if (entry.status == OutboxStatus.possibleDuplicate) {
      return l10n.brOutboxDuplicate;
    }
    final message = entry.message;
    if (SyncProblem.of(message) case final problem?) {
      final person = switch (problem.person) {
        SyncPerson.child => l10n.brPersonChild,
        SyncPerson.mother => l10n.brPersonMother,
        SyncPerson.father => l10n.brPersonFather,
        SyncPerson.informant => l10n.brPersonInformant,
      };
      return switch (problem.check) {
        SyncCheck.ninNotFound => l10n.brSyncNinNotFound(person),
        SyncCheck.ninNameMismatch => l10n.brSyncNinNameMismatch(person),
        SyncCheck.trackingIdNotFound => l10n.brSyncTrackingIdNotFound,
        SyncCheck.trackingIdNameMismatch => l10n.brSyncTrackingIdMismatch,
      };
    }
    if (entry.status == OutboxStatus.retryLater) {
      return message ?? l10n.brOutboxRetryLater;
    }
    return message;
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.brOutboxDeleteTitle),
        content: Text(l10n.brOutboxDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.logOutCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.brOutboxDelete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status, required this.sending});

  final OutboxStatus status;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, color) = sending
        ? (l10n.brOutboxSending, AppPalette.accentBlue)
        : switch (status) {
            OutboxStatus.waiting => (l10n.brOutboxWaiting, AppPalette.muted),
            OutboxStatus.retryLater => (
              l10n.brOutboxWillRetry,
              AppPalette.accentYellow,
            ),
            OutboxStatus.needsFix => (l10n.brOutboxNeedsFix, AppPalette.danger),
            OutboxStatus.possibleDuplicate => (
              l10n.brOutboxPossibleDuplicate,
              AppPalette.accentPlum,
            ),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Spacing.xs),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
