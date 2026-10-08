import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';

/// Reports errors thrown inside blocs. States and events are deliberately NOT
/// logged, because they contain personal data.
class AppBlocObserver extends BlocObserver {
  AppBlocObserver(this._crashReporter);

  final CrashReporter _crashReporter;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    unawaited(
      _crashReporter.recordError(
        error,
        stackTrace,
        reason: 'Unhandled error in bloc',
      ),
    );
    super.onError(bloc, error, stackTrace);
  }
}
