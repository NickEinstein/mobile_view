import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_reg_mobile/app/view/app_drawer.dart';
import 'package:vital_reg_mobile/app/view/new_registration_sheet.dart';
import 'package:vital_reg_mobile/core/offline/pending_sends.dart';
import 'package:vital_reg_mobile/design_system/icons/app_icons.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Signed-in frame. Each tab keeps its own history; Services opens the
/// "New registration" sheet instead.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, this.pendingSends, super.key});

  final StatefulNavigationShell shell;

  /// Checked before logging out.
  final PendingSends? pendingSends;

  void _select(BuildContext context, _AppTab tab) {
    final branch = tab.branch;
    if (branch == null) {
      unawaited(openNewRegistration(context));
      return;
    }
    shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = _AppTab.forBranch(shell.currentIndex);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: l10n.openMenu,
            icon: const AppIcon(AppIcons.menu, color: AppPalette.inkStrong),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: current == _AppTab.home ? null : Text(current.label(l10n)),
        actions: [
          IconButton(
            tooltip: l10n.notifications,
            icon: const Icon(Icons.notifications, color: AppPalette.inkStrong),
            onPressed: null,
          ),
        ],
      ),
      drawer: AppDrawer(
        onHome: () => _select(context, _AppTab.home),
        onServices: () => _select(context, _AppTab.services),
        pendingSends: pendingSends,
      ),
      body: shell,
      bottomNavigationBar: _BottomNav(
        current: current,
        onSelected: (tab) => _select(context, tab),
      ),
    );
  }
}

enum _AppTab {
  home(AppIcons.home, 0),
  services(AppIcons.services, null),
  profile(AppIcons.profile, 1);

  const _AppTab(this.icon, this.branch);

  final AppIcons icon;

  /// Router branch shown by this tab; null for Services, which is an action.
  final int? branch;

  static _AppTab forBranch(int branch) =>
      values.firstWhere((tab) => tab.branch == branch);

  String label(AppLocalizations l10n) => switch (this) {
    _AppTab.home => l10n.navHome,
    _AppTab.services => l10n.navServices,
    _AppTab.profile => l10n.navProfile,
  };
}

/// Bottom tabs as designed: the active tab is green with a bar above it.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onSelected});

  final _AppTab current;
  final ValueChanged<_AppTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppPalette.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final tab in _AppTab.values)
                Expanded(
                  child: _NavItem(
                    icon: tab.icon,
                    label: tab.label(l10n),
                    labelStyle: labelStyle,
                    selected: tab == current,
                    onTap: () => onSelected(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.labelStyle,
    required this.selected,
    required this.onTap,
  });

  final AppIcons icon;
  final String label;
  final TextStyle? labelStyle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPalette.brand : AppPalette.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: selected ? AppPalette.brand : Colors.transparent,
            ),
            const Spacer(),
            AppIcon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: labelStyle?.copyWith(color: color)),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
