/// Abandons a request (it ends with a `CancelledFailure`), without features
/// depending on Dio's `CancelToken`.
final class Cancellation {
  final List<void Function()> _listeners = [];
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners) {
      listener();
    }
    _listeners.clear();
  }

  /// Runs [listener] on [cancel], or now if already cancelled.
  void onCancel(void Function() listener) =>
      _cancelled ? listener() : _listeners.add(listener);
}
