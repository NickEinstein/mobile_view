import 'dart:convert';

import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';

/// One feature's draft for the signed-in user, with its files.
class DraftStore<T extends Object> {
  DraftStore(
    this._storage, {
    required this.key,
    required T Function(JsonMap json) fromJson,
    required JsonMap Function(T draft) toJson,
    required Iterable<String> Function(T draft) files,
  }) : _fromJson = fromJson,
       _toJson = toJson,
       _files = files;

  final UserStorage _storage;
  final String key;
  final T Function(JsonMap json) _fromJson;
  final JsonMap Function(T draft) _toJson;
  final Iterable<String> Function(T draft) _files;

  /// The saved draft. One that can't be read (e.g. saved by an older app
  /// version) is dropped, and the user starts over.
  Future<T?> load() async {
    final raw = await _storage.read(key: key);
    if (raw == null) return null;
    try {
      final Object? json = jsonDecode(raw);
      return _fromJson(json.asJsonMap());
    } on Object {
      await _storage.delete(key: key);
      return null;
    }
  }

  Future<void> save(T draft) =>
      _storage.write(key: key, value: jsonEncode(_toJson(draft)));

  /// Deletes the draft but not its files, which now belong to something
  /// else (e.g. an outbox entry).
  Future<void> forget() => _storage.delete(key: key);

  /// Deletes the draft and its files, and returns what was deleted so the
  /// caller can tidy up anything else that belonged to it.
  Future<T?> discard() async {
    final draft = await load();
    for (final path in draft == null ? const <String>[] : _files(draft)) {
      await _storage.files.delete(path);
    }
    await _storage.delete(key: key);
    return draft;
  }
}
