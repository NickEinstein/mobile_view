/// The user whose drafts, payments and files are in use (registrars share
/// devices). Kept when a session ends, so a late save lands with its owner.
class UserScope {
  String? _userId;

  /// Null until a user has signed in on this run of the app.
  String? get userId => _userId;

  void enter(String userId) => _userId = userId;

  /// [userId] made safe for storage keys and directory names. Encoding
  /// (rather than replacing characters) keeps distinct ids distinct.
  String get segment {
    final userId = _userId;
    if (userId == null) {
      throw StateError('No user has signed in yet.');
    }
    return Uri.encodeComponent(userId);
  }
}

/// A value cached in memory for the current user only. After a different
/// user signs in, it reads as empty and is loaded again.
final class UserCache<T extends Object> {
  UserCache(this._scope);

  final UserScope _scope;
  String? _owner;
  T? _value;

  T? get value => _owner != null && _owner == _scope.userId ? _value : null;

  set value(T? value) {
    _owner = _scope.userId;
    _value = value;
  }
}
