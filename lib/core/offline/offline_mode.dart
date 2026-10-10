import 'package:flutter/foundation.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';

/// Birth Registration's offline switch, per user and kept across restarts
/// and log-outs. While it's on, forms use saved lists and skip online
/// checks.
class OfflineMode extends ChangeNotifier {
  OfflineMode(this._storage);

  final UserStorage _storage;
  static final _key = UserStorage.settingKey('birth_registration_offline');

  bool _isOn = false;
  String? _loadedFor;

  /// The current user's setting, as last [load]ed. Off before that.
  bool get isOn => _loadedFor != null && _loadedFor == _userId && _isOn;

  String? get _userId => _storage.scope.userId;

  /// Reads the current user's setting, once per user.
  Future<bool> load() async {
    final userId = _userId;
    if (userId == null) return false;
    if (_loadedFor == userId) return _isOn;
    final on = await _storage.read(key: _key) == 'true';
    // Another user may have signed in while reading.
    if (_userId != userId) return false;
    _isOn = on;
    _loadedFor = userId;
    notifyListeners();
    return on;
  }

  Future<void> turn({required bool on}) async {
    final userId = _userId;
    if (userId == null) return;
    await _storage.write(key: _key, value: '$on');
    _isOn = on;
    _loadedFor = userId;
    notifyListeners();
  }
}
