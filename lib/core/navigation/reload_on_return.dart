import 'package:flutter/widgets.dart';
import 'package:vital_reg_mobile/core/network/record_changes.dart';

/// Tells screens when a page above them closes (not a dialog or sheet).
final appRouteObserver = RouteObserver<PageRoute<void>>();

/// Calls [onReturn] when a page above closes, if anything was written to
/// the backend since this screen loaded. (Awaiting `push` misses pages
/// swapped in with `pushReplacement`.)
class ReloadOnReturn extends StatefulWidget {
  const ReloadOnReturn({
    required this.onReturn,
    required this.child,
    this.changes,
    super.key,
  });

  final VoidCallback onReturn;

  /// Defaults to the app's [recordChanges].
  final RecordChanges? changes;
  final Widget child;

  @override
  State<ReloadOnReturn> createState() => _ReloadOnReturnState();
}

class _ReloadOnReturnState extends State<ReloadOnReturn> with RouteAware {
  PageRoute<void>? _route;

  RecordChanges get _changes => widget.changes ?? recordChanges;

  /// The write count when this screen last loaded (it loads as it opens).
  late int _seen;

  @override
  void initState() {
    super.initState();
    _seen = _changes.version;
  }

  /// This screen's route on the root navigator (for a tab, the shell's).
  ModalRoute<Object?>? _rootRoute() {
    var route = ModalRoute.of(context);
    var navigator = Navigator.maybeOf(context);
    while (navigator != null) {
      final outer = navigator.context.findAncestorStateOfType<NavigatorState>();
      if (outer == null) break;
      route = ModalRoute.of(navigator.context);
      navigator = outer;
    }
    return route;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = _rootRoute();
    if (route is PageRoute<void> && route != _route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    final version = _changes.version;
    if (version == _seen) return;
    _seen = version;
    widget.onReturn();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
