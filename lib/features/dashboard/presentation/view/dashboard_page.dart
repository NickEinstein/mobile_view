import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/core/navigation/reload_on_return.dart';
import 'package:vital_reg_mobile/design_system/icons/app_icons.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_stat_card.dart';
import 'package:vital_reg_mobile/features/dashboard/domain/dashboard_repository.dart';
import 'package:vital_reg_mobile/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:vital_reg_mobile/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'registrations_chart.dart';

/// Home tab. [name] and [roleLabel] come from the signed-in user; the app
/// layer passes them in so this feature doesn't depend on auth.
class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.name, required this.roleLabel, super.key});

  final String name;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardCubit(
        GetIt.instance<DashboardRepository>(),
        currentYear: DateTime.now().year,
      )..load().ignore(),
      child: DashboardView(name: name, roleLabel: roleLabel),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({required this.name, required this.roleLabel, super.key});

  final String name;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    // Back from a module: its records may have changed the counts.
    return ReloadOnReturn(
      onReturn: () {
        if (!cubit.isClosed) cubit.load().ignore();
      },
      child: RefreshIndicator(
        onRefresh: cubit.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.md,
            Spacing.lg,
          ),
          children: [
            _Greeting(name: name, roleLabel: roleLabel),
            const SizedBox(height: Spacing.md),
            const _StatGrid(),
            const SizedBox(height: Spacing.md),
            const _RegistrationsChart(),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.roleLabel});

  final String name;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l10n.greetingMorning
        : hour < 17
        ? l10n.greetingAfternoon
        : l10n.greetingEvening;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.chipFill,
            borderRadius: BorderRadius.circular(Spacing.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: 2,
            ),
            child: Text(
              roleLabel,
              style: textTheme.labelSmall?.copyWith(color: AppPalette.brand),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          greeting,
          style: textTheme.bodyLarge?.copyWith(color: AppPalette.muted),
        ),
        Text(
          name,
          style: textTheme.titleLarge?.copyWith(
            color: AppPalette.inkStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The four counters. Tapping one shows its numbers in the chart.
class _StatGrid extends StatelessWidget {
  const _StatGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Spacing.sm,
      crossAxisSpacing: Spacing.sm,
      childAspectRatio: 1.6,
      children: [
        for (final category in RegistrationCategory.values)
          _StatCard(category: category),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.category});

  final RegistrationCategory category;

  @override
  Widget build(BuildContext context) {
    final (selected, total) = context.select(
      (DashboardCubit cubit) => (
        cubit.state.category == category,
        cubit.state.statsOf(category).total,
      ),
    );
    final (icon, color) = category.visual;
    return AppStatCard(
      icon: icon,
      color: color,
      count: total,
      label: category.label(context.l10n),
      selected: selected,
      onTap: () => context.read<DashboardCubit>().categorySelected(category),
    );
  }
}

extension on RegistrationCategory {
  String label(AppLocalizations l10n) => switch (this) {
    RegistrationCategory.birthRegistration => l10n.statBirthRegistrations,
    RegistrationCategory.birthAttestation => l10n.statBirthAttestation,
    RegistrationCategory.deathRegistration => l10n.statDeathRegistrations,
    RegistrationCategory.stillBirth => l10n.statStillBirths,
  };

  /// Name without the age range, for the chart title.
  String shortLabel(AppLocalizations l10n) =>
      label(l10n).replaceAll(RegExp(r'\s*\(.*\)$'), '');

  (AppIcons, Color) get visual => switch (this) {
    RegistrationCategory.birthRegistration => (
      AppIcons.birthRegistration,
      AppPalette.accentBlue,
    ),
    RegistrationCategory.birthAttestation => (
      AppIcons.birthAttestation,
      AppPalette.accentGreen,
    ),
    RegistrationCategory.deathRegistration => (
      AppIcons.deathRegistration,
      AppPalette.accentYellow,
    ),
    RegistrationCategory.stillBirth => (
      AppIcons.stillBirth,
      AppPalette.accentBlue,
    ),
  };
}
