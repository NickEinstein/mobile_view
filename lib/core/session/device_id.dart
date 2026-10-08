import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// This install's id, sent with every sign-in. The backend binds an account
/// to its first device, so it is made once and never cleared.
class DeviceId {
  /// [override] (dev and staging only, see `AppConfig.deviceIdOverride`)
  /// is used as is, and nothing is stored.
  DeviceId(this._storage, {Random? random, String? override})
    : _random = random ?? Random.secure(),
      _cached = override;

  final FlutterSecureStorage _storage;
  final Random _random;
  static const _key = 'device_id';

  String? _cached;

  Future<String> read() async {
    final cached = _cached;
    if (cached != null) return cached;
    final stored = await _storage.read(key: _key);
    if (stored != null) return _cached = stored;
    final created = [
      for (var i = 0; i < 16; i++)
        _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await _storage.write(key: _key, value: created);
    return _cached = created;
  }
}
