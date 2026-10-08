import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/app/router/app_module.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Stand-in until a module's feature is built. It only appears where that
/// module's flag is on (dev/staging), never as fake data in production.
class ModulePlaceholderPage extends StatelessWidget {
  const ModulePlaceholderPage({required this.module, super.key});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(module.title(l10n))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Text(l10n.moduleComingSoon, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
