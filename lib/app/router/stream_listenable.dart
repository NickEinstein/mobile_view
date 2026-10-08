import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts a stream (e.g. `AuthBloc.stream`) to the [Listenable] GoRouter
/// needs for `refreshListenable`.
class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
