import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vital_reg_mobile/core/session/user_scope.dart';
import 'package:vital_reg_mobile/core/storage/draft_files.dart';

/// Secure storage for one user on a shared device: drafts, payment
/// references and their [files]. Only an explicit sign-out clears drafts.
class UserStorage {
  UserStorage(this._storage, this.scope, {DraftFiles? files})
    : files = files ?? DraftFiles(scope);

  final FlutterSecureStorage _storage;
  final UserScope scope;
  final DraftFiles files;

  static const _paymentPrefix = 'payment_';

  /// The key for a payment reference of a transaction [type]. Kept by
  /// [clearDrafts]: someone paid for it.
  static String paymentKey(String type) => '$_paymentPrefix$type';

  String _key(String key) => 'user/${scope.segment}/$key';

  Future<String?> read({required String key}) => _storage.read(key: _key(key));

  Future<void> write({required String key, required String value}) =>
      _storage.write(key: _key(key), value: value);

  Future<void> delete({required String key}) => _storage.delete(key: _key(key));

  /// Deletes the current user's drafts and draft files, keeping payment
  /// references. Does nothing before anyone has signed in.
  Future<void> clearDrafts() async {
    if (scope.userId == null) return;
    final prefix = _key('');
    final payments = _key(_paymentPrefix);
    final keys = [
      for (final key in (await _storage.readAll()).keys)
        if (key.startsWith(prefix) && !key.startsWith(payments)) key,
    ];
    for (final key in keys) {
      await _storage.delete(key: key);
    }
    await files.clear();
  }
}
