/// Counts successful writes ([ApiClient] bumps it on every POST, PUT, PATCH
/// or DELETE), so screens know whether records may have changed.
class RecordChanges {
  int _version = 0;

  /// Goes up by one with each write.
  int get version => _version;

  void bump() => _version++;
}

/// The app's one counter, shared by [ApiClient] and [ReloadOnReturn].
final recordChanges = RecordChanges();
