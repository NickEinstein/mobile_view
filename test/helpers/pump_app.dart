import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

extension PumpApp on WidgetTester {
  /// Pumps [widget] with localization and a Material ancestor, as in the app.
  Future<void> pumpApp(Widget widget) => pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: widget,
    ),
  );
}
