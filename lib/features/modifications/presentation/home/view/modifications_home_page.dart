import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_stat_card.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_summary.dart';
import 'package:vital_reg_mobile/features/modifications/domain/modifications_repository.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/home/cubit/modifications_cubit.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/shared/modification_labels.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'modification_list.dart';

/// Opens the request screen for [kind] and completes when the user comes
/// back.
typedef StartModification = Future<void> Function(ModificationKind kind);

/// Opens a queried request to answer it; completes when the user is back.
typedef OpenQueried = Future<void> Function(ModificationKind kind, String id);

/// Modifications home. Navigation comes from the router, so this feature
/// doesn't depend on app route paths.
class ModificationsHomePage extends StatelessWidget {
  const ModificationsHomePage({
    required this.onNewRequest,
    required this.onOpenQueried,
    super.key,
  });

  final StartModification onNewRequest;
  final OpenQueried onOpenQueried;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ModificationsCubit(GetIt.instance<ModificationsRepository>())
            ..load().ignore(),
      child: ModificationsHomeView(
        onNewRequest: onNewRequest,
        onOpenQueried: onOpenQueried,
      ),
    );
  }
}

class ModificationsHomeView extends StatelessWidget {
  const ModificationsHomeView({
    required this.onNewRequest,
    required this.onOpenQueried,
    super.key,
  });

  final StartModification onNewRequest;
  final OpenQueried onOpenQueried;

  Future<void> _newRequest(BuildContext context) async {
    final cubit = context.read<ModificationsCubit>();
    await onNewRequest(cubit.state.kind);
    // Back from the request: counts may have changed.
    if (!cubit.isClosed) await cubit.load();
  }

  Future<void> _openQueried(BuildContext context, String id) async {
    final cubit = context.read<ModificationsCubit>();
    await onOpenQueried(cubit.state.kind, id);
    // Answered: it moves from Queried to Pending.
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
        onRefresh: context.read<ModificationsCubit>().load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            0,
            Spacing.md,
            Spacing.lg,
          ),
          children: [
            Text(
              l10n.moduleModifications,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppPalette.inkStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.md),
            const _KindGrid(),
            const SizedBox(height: Spacing.md),
            _SearchRow(onNew: () => unawaited(_newRequest(context))),
            const SizedBox(height: Spacing.md),
            _ModificationList(
              onOpenQueried: (id) => unawaited(_openQueried(context, id)),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindGrid extends StatelessWidget {
  const _KindGrid();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ModificationsCubit>().state;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Spacing.sm,
      crossAxisSpacing: Spacing.sm,
      childAspectRatio: 1.6,
      children: [
        for (final kind in ModificationKind.values)
          AppStatCard(
            icon: kind.visual.$1,
            color: kind.visual.$2,
            count: state.countOf(kind),
            label: kind.title(l10n),
            selected: kind == state.kind,
            onTap: () => unawaited(
              context.read<ModificationsCubit>().kindSelected(kind),
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
    final cubit = context.read<ModificationsCubit>();
    final status = context.select(
      (ModificationsCubit cubit) => cubit.state.status,
    );
    final squareButton = IconButton.styleFrom(
      foregroundColor: Colors.white,
      minimumSize: const Size.square(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Spacing.sm),
      ),
    );
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: cubit.queryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.modSearchHint,
              prefixIcon: const Icon(Icons.search, color: AppPalette.muted),
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        PopupMenuButton<ModificationStatus>(
          tooltip: l10n.modFilterStatus,
          initialValue: status,
          style: squareButton.copyWith(
            backgroundColor: const WidgetStatePropertyAll(AppPalette.ink),
          ),
          icon: const Icon(Icons.filter_alt_outlined),
          onSelected: (status) => unawaited(cubit.statusSelected(status)),
          itemBuilder: (_) => [
            for (final option in ModificationStatus.values)
              CheckedPopupMenuItem(
                value: option,
                checked: option == status,
                child: Text(option.label(l10n)),
              ),
          ],
        ),
        const SizedBox(width: Spacing.sm),
        IconButton.filled(
          tooltip: l10n.modNewRequest,
          style: squareButton.copyWith(
            backgroundColor: const WidgetStatePropertyAll(AppPalette.brand),
          ),
          onPressed: onNew,
          icon: const Icon(Icons.person_add_alt),
        ),
      ],
    );
  }
}
