import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/core/navigation/reload_on_return.dart';
import 'package:vital_reg_mobile/core/offline/offline_mode.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/storage/outbox.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_stat_card.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/outbox_sync.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/cubit/applications_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/outbox/cubit/outbox_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/shared/application_status_style.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'application_list.dart';
part 'offline_switch.dart';

/// Opens another screen and completes when the user comes back.
typedef OpenScreen = Future<void> Function();

/// Opens one application's details.
typedef OpenApplication = Future<void> Function(String id);

/// Birth Registration home; navigation comes from the router.
class BirthRegistrationHomePage extends StatelessWidget {
  const BirthRegistrationHomePage({
    required this.onStartApplication,
    required this.onResumeApplication,
    required this.onOpenApplication,
    this.repository,
    this.offlineMode,
    this.registrarStateId,
    this.outboxSync,
    this.onOpenOutbox,
    super.key,
  });

  final OpenScreen onStartApplication;
  final OpenScreen onResumeApplication;
  final OpenApplication onOpenApplication;

  /// Defaults to the registered one; tests pass a fake.
  final BirthRegistrationRepository? repository;

  /// The offline switch; without it, none is shown.
  final OfflineMode? offlineMode;

  /// The signed-in registrar's state, whose lists are downloaded before
  /// going offline.
  final String? registrarStateId;

  /// With [onOpenOutbox], shows the applications waiting to be sent.
  final OutboxSync? outboxSync;
  final OpenScreen? onOpenOutbox;

  @override
  Widget build(BuildContext context) {
    final repository =
        this.repository ?? GetIt.instance<BirthRegistrationRepository>();
    final offlineMode = this.offlineMode;
    unawaited(offlineMode?.load());
    final (sync, openOutbox) = (outboxSync, onOpenOutbox);
    final home = BlocProvider(
      create: (_) => ApplicationsCubit(repository)..load().ignore(),
      child: BirthRegistrationHomeView(
        onStartApplication: onStartApplication,
        onResumeApplication: onResumeApplication,
        onOpenApplication: onOpenApplication,
        actions: [
          if (offlineMode != null)
            _OfflineSwitch(
              mode: offlineMode,
              repository: repository,
              stateId: registrarStateId,
            ),
        ],
        banner: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (offlineMode != null) _OfflineBanner(mode: offlineMode),
            if (sync != null && openOutbox != null)
              _OutboxCard(onOpen: openOutbox),
          ],
        ),
      ),
    );
    if (sync == null) return home;
    return BlocProvider(
      create: (_) => OutboxCubit(repository, sync)..load().ignore(),
      child: home,
    );
  }
}

/// Also the Birth Attestation home, which differs only in [title].
class BirthRegistrationHomeView extends StatelessWidget {
  const BirthRegistrationHomeView({
    required this.onStartApplication,
    required this.onResumeApplication,
    required this.onOpenApplication,
    this.title,
    this.resumeMessage,
    this.actions,
    this.banner,
    super.key,
  });

  /// Defaults to "Birth Registration".
  final String? title;

  /// "You have an unfinished … on this device"; defaults to birth
  /// registration's.
  final String? resumeMessage;

  /// Extra app bar buttons, e.g. Surrogacy's saved drafts.
  final List<Widget>? actions;

  /// Shown under the title, e.g. Birth Registration's offline notice.
  final Widget? banner;
  final OpenScreen onStartApplication;
  final OpenScreen onResumeApplication;
  final OpenApplication onOpenApplication;

  /// Offers to resume an unfinished application before starting a new one.
  Future<void> _newApplication(BuildContext context) async {
    final cubit = context.read<ApplicationsCubit>();
    final l10n = context.l10n;
    final hasDraft = await cubit.hasSavedDraft();
    if (!context.mounted) return;
    if (!hasDraft) {
      await onStartApplication();
    } else {
      final resume = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.brResumeTitle),
          content: Text(resumeMessage ?? l10n.brResumeMessage),
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
      if (resume) {
        await onResumeApplication();
      } else {
        await cubit.discardDraft();
        await onStartApplication();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ApplicationsCubit>();
    // Back from a form or details page: counts may have changed.
    return ReloadOnReturn(
      onReturn: () {
        if (!cubit.isClosed) cubit.load().ignore();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          actions: actions,
        ),
        body: RefreshIndicator(
          onRefresh: context.read<ApplicationsCubit>().load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              0,
              Spacing.md,
              Spacing.lg,
            ),
            children: [
              Text(
                title ?? l10n.moduleBirthRegistration,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppPalette.inkStrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ?banner,
              const SizedBox(height: Spacing.md),
              const _StatusGrid(),
              const SizedBox(height: Spacing.md),
              _SearchRow(onNew: () => unawaited(_newApplication(context))),
              const SizedBox(height: Spacing.md),
              _ApplicationList(onOpen: onOpenApplication),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (selected, counts) = context.select(
      (ApplicationsCubit cubit) => (cubit.state.status, cubit.state.counts),
    );
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Spacing.sm,
      crossAxisSpacing: Spacing.sm,
      childAspectRatio: 1.6,
      children: [
        for (final status in ApplicationStatus.values)
          AppStatCard(
            icon: status.visual.$1,
            color: status.visual.$2,
            count: counts.of(status),
            label: status.cardLabel(l10n),
            selected: status == selected,
            onTap: () => unawaited(
              context.read<ApplicationsCubit>().statusSelected(status),
            ),
          ),
      ],
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
            onChanged: context.read<ApplicationsCubit>().queryChanged,
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
          tooltip: l10n.brNewApplication,
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
