import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Stand-in for a tab whose screen isn't designed yet.
class TabPlaceholderPage extends StatelessWidget {
  const TabPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Text(context.l10n.tabComingSoon, textAlign: TextAlign.center),
      ),
    );
  }
}
