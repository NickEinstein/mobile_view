import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/icons/app_icons.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/shared/application_status_style.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_summary.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/still_birth_repository.dart';
import 'package:vital_reg_mobile/features/still_birth/presentation/home/cubit/still_birth_home_cubit.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Opens another screen and completes when the user comes back.
typedef OpenScreen = Future<void> Function();

/// Opens one registration's details.
typedef OpenRegistration = Future<void> Function(String id);

/// Still Birth Registration home. Navigation comes from the router.
class StillBirthHomePage extends StatelessWidget {
  const StillBirthHomePage({
    required this.onOpenForm,
    required this.onOpenRegistration,
    this.repository,
    super.key,
  });

  /// Opens the form, which continues the draft on the device if there is
  /// one.
  final OpenScreen onOpenForm;

  /// "Certificate Details".
  final OpenRegistration onOpenRegistration;

  /// Defaults to the registered one; tests pass a fake.
  final StillBirthRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StillBirthHomeCubit(
        repository ?? GetIt.instance<StillBirthRepository>(),
      )..load().ignore(),
      child: StillBirthHomeView(
        onOpenForm: onOpenForm,
        onOpenRegistration: onOpenRegistration,
      ),
    );
  }
}

class StillBirthHomeView extends StatelessWidget {
  const StillBirthHomeView({
    required this.onOpenForm,
    required this.onOpenRegistration,
    super.key,
  });

  final OpenScreen onOpenForm;
  final OpenRegistration onOpenRegistration;

  /// Offers to resume an unfinished registration before starting a new one.
  Future<void> _newRegistration(BuildContext context) async {
    final cubit = context.read<StillBirthHomeCubit>();
    final l10n = context.l10n;
    if (await cubit.hasSavedDraft()) {
      if (!context.mounted) return;
      final resume = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.brResumeTitle),
          content: Text(l10n.sbResumeMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.brResumeStartNew),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.brResumeContinue),
            ),
          ],
        ),
      );
      if (resume == null) return;
      if (!resume) await cubit.discardDraft();
    }
    await onOpenForm();
    // Back from the form: the total may have changed.
    if (!cubit.isClosed) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: context.read<StillBirthHomeCubit>().load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            0,
            Spacing.md,
            Spacing.lg,
          ),
          children: [
            Text(
              l10n.moduleStillBirthRegistration,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppPalette.inkStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.md),
            const _TotalCard(),
            const SizedBox(height: Spacing.md),
            _SearchRow(onNew: () => unawaited(_newRegistration(context))),
            const SizedBox(height: Spacing.md),
            _RegistrationList(onOpen: onOpenRegistration),
          ],
        ),
      ),
    );
  }
}

/// "Total Registration", full width and green as in the design.
class _TotalCard extends StatelessWidget {
  const _TotalCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final total = context.select(
      (StillBirthHomeCubit cubit) => cubit.state.total,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.selectedCardFill,
        border: Border.all(color: AppPalette.selectedCardBorder),
        borderRadius: BorderRadius.circular(Spacing.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sm + Spacing.xs),
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppPalette.accentBlue.withValues(alpha: 0.12),
                child: const AppIcon(
                  AppIcons.stillBirth,
                  size: 17,
                  color: AppPalette.accentBlue,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                '$total',
                style: textTheme.titleMedium?.copyWith(
                  color: AppPalette.inkStrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                context.l10n.sbTotalRegistration,
                style: textTheme.bodySmall?.copyWith(
                  color: AppPalette.ink,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: context.read<StillBirthHomeCubit>().queryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.brSearchHint,
              prefixIcon: const Icon(Icons.search, color: AppPalette.muted),
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        IconButton.filled(
          tooltip: l10n.sbNewRegistration,
          style: IconButton.styleFrom(
            backgroundColor: AppPalette.brand,
            foregroundColor: Colors.white,
            minimumSize: const Size.square(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Spacing.sm),
            ),
          ),
          onPressed: onNew,
          icon: const Icon(Icons.person_add_alt),
        ),
      ],
    );
  }
}

class _RegistrationList extends StatelessWidget {
  const _RegistrationList({required this.onOpen});

  final OpenRegistration onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<StillBirthHomeCubit>().state;
    final failure = state.failure;
    if (failure != null) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Text(failure.localize(l10n), textAlign: TextAlign.center),
      );
    }
    if (state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Text(l10n.sbNoRegistrations, textAlign: TextAlign.center),
      );
    }
    return Column(
      children: [
        for (final item in state.items) ...[
          _RegistrationTile(
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

class _RegistrationTile extends StatelessWidget {
  const _RegistrationTile({required this.item, required this.onOpen});

  final StillBirthSummary item;
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
    ).format(item.registeredOn);

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
                      item.motherName,
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
