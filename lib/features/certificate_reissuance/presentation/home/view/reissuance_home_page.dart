import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_stat_card.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/home/cubit/reissuance_home_cubit.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/certificate_viewer.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/reissuance_labels.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'reissuance_list.dart';

/// Opens another screen and completes when the user comes back.
typedef OpenScreen = Future<void> Function();

/// Opens a request's details, or its correction; completes when the user
/// is back.
typedef OpenRequest = Future<void> Function(ReissuanceKind kind, String id);

/// Picks an unfinished request up where it stopped
/// ([ReissuanceDraft.nextStep]).
typedef ResumeReissuance = Future<void> Function(ReissuanceDraft draft);

/// Certificate Reissuance home. Navigation comes from the router, so this
/// feature doesn't depend on app route paths.
class ReissuanceHomePage extends StatelessWidget {
  const ReissuanceHomePage({
    required this.onStart,
    required this.onResume,
    required this.onOpenDetails,
    required this.onUpdate,
    this.repository,
    super.key,
  });

  /// A new request: payment first.
  final OpenScreen onStart;
  final ResumeReissuance onResume;

  /// "Certificate Details" and a queried request's correction.
  final OpenRequest onOpenDetails;
  final OpenRequest onUpdate;

  /// Defaults to the registered one; tests pass a fake.
  final ReissuanceRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repository =
        this.repository ?? GetIt.instance<ReissuanceRepository>();
    return BlocProvider(
      create: (_) => ReissuanceHomeCubit(repository)..load().ignore(),
      child: ReissuanceHomeView(
        repository: repository,
        onStart: onStart,
        onResume: onResume,
        onOpenDetails: onOpenDetails,
        onUpdate: onUpdate,
      ),
    );
  }
}

class ReissuanceHomeView extends StatelessWidget {
  const ReissuanceHomeView({
    required this.repository,
    required this.onStart,
    required this.onResume,
    required this.onOpenDetails,
    required this.onUpdate,
    super.key,
  });

  final ReissuanceRepository repository;
  final OpenScreen onStart;
  final ResumeReissuance onResume;
  final OpenRequest onOpenDetails;
  final OpenRequest onUpdate;

  /// Opens a request's screen, then reloads (an update moves it to
  /// Pending).
  Future<void> _open(BuildContext context, OpenRequest open, String id) async {
    final cubit = context.read<ReissuanceHomeCubit>();
    await open(cubit.state.kind, id);
    if (!cubit.isClosed) await cubit.load();
  }

  /// Offers to resume an unfinished request before starting a new one.
  Future<void> _newRequest(BuildContext context) async {
    final cubit = context.read<ReissuanceHomeCubit>();
    final l10n = context.l10n;
    final draft = await repository.loadDraft();
    if (!context.mounted) return;
    if (draft == null) {
      await onStart();
    } else {
      final resume = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.brResumeTitle),
          content: Text(l10n.crResumeMessage),
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
        await onResume(draft);
      } else {
        await repository.discardDraft();
        await onStart();
      }
    }
    // Back from the request: counts may have changed.
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
        onRefresh: context.read<ReissuanceHomeCubit>().load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            0,
            Spacing.md,
            Spacing.lg,
          ),
          children: [
            Text(
              l10n.crTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppPalette.inkStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.md),
            const _KindTabs(),
            const SizedBox(height: Spacing.md),
            const _StatusGrid(),
            const SizedBox(height: Spacing.md),
            _SearchRow(onNew: () => unawaited(_newRequest(context))),
            const SizedBox(height: Spacing.md),
            _ReissuanceList(
              onOpenDetails: (id) =>
                  unawaited(_open(context, onOpenDetails, id)),
              onUpdate: (id) => unawaited(_open(context, onUpdate, id)),
              onDownload: (kind, reference) => unawaited(
                showCertificate(
                  context,
                  image: repository.download(kind, reference),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Birth Reissuance | Attestation Reissuance": the selected one filled
/// green, as in the design.
class _KindTabs extends StatelessWidget {
  const _KindTabs();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final selected = context.select(
      (ReissuanceHomeCubit cubit) => cubit.state.kind,
    );
    Widget tab(ReissuanceKind kind) {
      final isSelected = kind == selected;
      return Expanded(
        child: Semantics(
          selected: isSelected,
          button: true,
          child: Material(
            color: isSelected ? AppPalette.brand : AppPalette.fieldFill,
            borderRadius: BorderRadius.circular(Spacing.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(Spacing.sm),
              onTap: () => unawaited(
                context.read<ReissuanceHomeCubit>().kindSelected(kind),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  kind.tab(l10n),
                  textAlign: TextAlign.center,
                  style: textTheme.labelMedium?.copyWith(
                    color: isSelected ? Colors.white : AppPalette.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(ReissuanceKind.birth),
        const SizedBox(width: Spacing.sm),
        tab(ReissuanceKind.attestation),
      ],
    );
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid();

  /// "Total", then each status.
  static const _cards = <ReissuanceStatus?>[null, ...ReissuanceStatus.values];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (selected, counts) = context.select(
      (ReissuanceHomeCubit cubit) => (cubit.state.status, cubit.state.counts),
    );
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Spacing.sm,
      crossAxisSpacing: Spacing.sm,
      childAspectRatio: 1.6,
      children: [
        for (final status in _cards)
          AppStatCard(
            icon: status.visual.$1,
            color: status.visual.$2,
            count: counts.of(status),
            label: status.cardLabel(l10n),
            selected: status == selected,
            onTap: () => unawaited(
              context.read<ReissuanceHomeCubit>().statusSelected(status),
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
            onChanged: context.read<ReissuanceHomeCubit>().queryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.crSearchHint,
              prefixIcon: const Icon(Icons.search, color: AppPalette.muted),
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        IconButton.filled(
          tooltip: l10n.crNewRequest,
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
