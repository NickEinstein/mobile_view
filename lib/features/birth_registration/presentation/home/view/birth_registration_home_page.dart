import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_stat_card.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/cubit/applications_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/shared/application_status_style.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'application_list.dart';

/// Opens another screen and completes when the user comes back.
typedef OpenScreen = Future<void> Function();

/// Opens one application's details.
typedef OpenApplication = Future<void> Function(String id);

/// Birth Registration home. Navigation comes from the router, so this
/// feature doesn't depend on app route paths.
class BirthRegistrationHomePage extends StatelessWidget {
  const BirthRegistrationHomePage({
    required this.onStartApplication,
    required this.onResumeApplication,
    required this.onOpenApplication,
    super.key,
  });

  final OpenScreen onStartApplication;
  final OpenScreen onResumeApplication;
  final OpenApplication onOpenApplication;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ApplicationsCubit(GetIt.instance<BirthRegistrationRepository>())
            ..load().ignore(),
      child: BirthRegistrationHomeView(
        onStartApplication: onStartApplication,
        onResumeApplication: onResumeApplication,
        onOpenApplication: onOpenApplication,
      ),
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
    super.key,
  });

  /// Defaults to "Birth Registration".
  final String? title;

  /// "You have an unfinished … on this device"; defaults to birth
  /// registration's.
  final String? resumeMessage;

  /// Extra app bar buttons, e.g. Surrogacy's saved drafts.
  final List<Widget>? actions;
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
    // Back from the form: counts may have changed.
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
            const SizedBox(height: Spacing.md),
            const _StatusGrid(),
            const SizedBox(height: Spacing.md),
            _SearchRow(onNew: () => unawaited(_newApplication(context))),
            const SizedBox(height: Spacing.md),
            _ApplicationList(onOpen: onOpenApplication),
          ],
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
