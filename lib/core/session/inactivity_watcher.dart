import 'dart:async';

import 'package:flutter/widgets.dart';

/// One app-wide inactivity timer, running only while [enabled]. Returning
/// from the background after [timeout] also expires the session.
class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({
    required this.enabled,
    required this.timeout,
    required this.onTimeout,
    required this.child,
    super.key,
  });

  final bool enabled;
  final Duration timeout;
  final VoidCallback onTimeout;
  final Widget child;

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restart();
  }

  @override
  void didUpdateWidget(InactivityWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.timeout != widget.timeout) {
      _restart();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        final expiredInBackground =
            since != null && DateTime.now().difference(since) >= widget.timeout;
        if (expiredInBackground) {
          _expire();
        } else {
          _restart();
        }
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _restart() {
    _timer?.cancel();
    _timer = widget.enabled ? Timer(widget.timeout, _expire) : null;
  }

  void _expire() {
    _timer?.cancel();
    _timer = null;
    if (widget.enabled) widget.onTimeout();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: widget.child,
    );
  }
}
