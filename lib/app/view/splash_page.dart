import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Shown while the stored session is being restored.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: context.l10n.loading,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
