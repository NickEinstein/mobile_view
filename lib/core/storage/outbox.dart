import 'dart:convert';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/core/network/record_changes.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';

/// Bumped by every outbox change, so screens showing one reload on return.
final outboxChanges = RecordChanges();

/// Where an outbox entry stands. Only the user removes an entry that
/// can't be sent.
enum OutboxStatus {
  /// Not tried yet, or tried and interrupted.
  waiting,

  /// The server or the connection failed; tried again later.
  retryLater,

  /// Turned down (e.g. a NIN that doesn't match); the user must fix it.
  needsFix,

  /// The server already has a matching record, probably from an earlier
  /// attempt whose answer was lost. Never sent again.
  possibleDuplicate,
}

/// One record waiting to be sent.
final class OutboxEntry<T extends Object> extends Equatable {
  const OutboxEntry({
    required this.id,
    required this.savedAt,
    required this.item,
    this.status = OutboxStatus.waiting,
    this.message,
    this.progress = const {},
  });

  final String id;
  final DateTime savedAt;
  final T item;
  final OutboxStatus status;

  /// Why it couldn't be sent, as the server or a check said.
  final String? message;

  /// Steps already done, so a retry skips them: e.g. an uploaded file's
  /// storage key by its local path, or a check that passed.
  final Map<String, String> progress;

  OutboxEntry<T> copyWith({
    T? item,
    OutboxStatus? status,
    String? Function()? message,
    Map<String, String>? progress,
  }) => OutboxEntry(
    id: id,
    savedAt: savedAt,
    item: item ?? this.item,
    status: status ?? this.status,
    message: message != null ? message() : this.message,
    progress: progress ?? this.progress,
  );

  @override
  List<Object?> get props => [id, savedAt, item, status, message, progress];
}

/// Records the signed-in user saved on the device to send later, oldest
/// first. Each entry keeps its files until it is removed.
class Outbox<T extends Object> {
  Outbox(
    this._storage, {
    required this.key,
    required T Function(JsonMap json) fromJson,
    required JsonMap Function(T item) toJson,
    required Iterable<String> Function(T item) files,
    String Function()? newId,
    DateTime Function()? now,
  }) : _fromJson = fromJson,
       _toJson = toJson,
       _files = files,
       _newId = newId ?? _randomId,
       _now = now ?? DateTime.now;

  final UserStorage _storage;
  final String key;
  final T Function(JsonMap json) _fromJson;
  final JsonMap Function(T item) _toJson;
  final Iterable<String> Function(T item) _files;
  final String Function() _newId;
  final DateTime Function() _now;

  /// Changes run one after another, so the list of ids stays whole.
  Future<void> _changes = Future.value();

  static String _randomId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  String _entryKey(String id) => '$key/$id';

  Future<List<String>> _ids() async {
    final raw = await _storage.read(key: key);
    if (raw == null) return [];
    final Object? ids = jsonDecode(raw);
    return ids is List ? ids.whereType<String>().toList() : [];
  }

  /// A failed change is reported to its caller without stopping the next.
  Future<void> _change(Future<void> Function() change) {
    final done = _changes.then((_) => change());
    _changes = done
        .then<void>((_) {}, onError: (Object _) {})
        .whenComplete(outboxChanges.bump);
    return done;
  }

  /// Every entry, oldest first. One that can't be read (e.g. saved by an
  /// older app version) is left out but kept.
  Future<List<OutboxEntry<T>>> entries() async {
    await _changes;
    return [for (final id in await _ids()) ?await read(id)];
  }

  Future<int> count() async {
    await _changes;
    return (await _ids()).length;
  }

  Future<OutboxEntry<T>?> read(String id) async {
    final raw = await _storage.read(key: _entryKey(id));
    if (raw == null) return null;
    try {
      final json = (jsonDecode(raw) as Object?).asJsonMap();
      final progress = json['progress'];
      return OutboxEntry(
        id: id,
        savedAt: DateTime.parse(json.requireString('savedAt')),
        item: _fromJson(json['item'].asJsonMap()),
        status: OutboxStatus.values.byName(json.requireString('status')),
        message: json['message'] as String?,
        progress: progress is Map
            ? {
                for (final MapEntry(:key, :value) in progress.entries)
                  if ((key, value) case (final String k, final String v)) k: v,
              }
            : const {},
      );
    } on Object {
      return null;
    }
  }

  Future<void> _write(OutboxEntry<T> entry) => _storage.write(
    key: _entryKey(entry.id),
    value: jsonEncode({
      'savedAt': entry.savedAt.toIso8601String(),
      'item': _toJson(entry.item),
      'status': entry.status.name,
      'message': entry.message,
      'progress': entry.progress,
    }),
  );

  /// Adds [item] as waiting and returns its entry.
  Future<OutboxEntry<T>> add(T item) async {
    final entry = OutboxEntry(id: _newId(), savedAt: _now(), item: item);
    await _change(() async {
      await _write(entry);
      await _storage.write(
        key: key,
        value: jsonEncode([...await _ids(), entry.id]),
      );
    });
    return entry;
  }

  /// Saves [entry]'s new state, unless it was removed meanwhile.
  Future<void> update(OutboxEntry<T> entry) => _change(() async {
    if ((await _ids()).contains(entry.id)) await _write(entry);
  });

  /// Removes the entry and deletes its files.
  Future<void> remove(String id) => _change(() async {
    final entry = await read(id);
    await _storage.write(
      key: key,
      value: jsonEncode([...(await _ids())..remove(id)]),
    );
    await _storage.delete(key: _entryKey(id));
    for (final path in entry == null ? const <String>[] : _files(entry.item)) {
      await _storage.files.delete(path);
    }
  });
}
