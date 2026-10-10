import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/core/session/user_scope.dart';
import 'package:vital_reg_mobile/core/storage/draft_files.dart';
import 'package:vital_reg_mobile/core/storage/draft_store.dart';
import 'package:vital_reg_mobile/core/storage/outbox.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';

final class _Item {
  const _Item(this.name, this.photo);

  factory _Item.fromJson(JsonMap json) =>
      _Item(json.requireString('name'), json['photo'] as String?);

  final String name;
  final String? photo;

  JsonMap toJson() => {'name': name, 'photo': photo};
}

void main() {
  late Directory root;
  late UserScope scope;
  late UserStorage storage;
  late Outbox<_Item> outbox;
  var ids = 0;

  Outbox<_Item> build(UserStorage storage) => Outbox<_Item>(
    storage,
    key: 'test_outbox',
    fromJson: _Item.fromJson,
    toJson: (item) => item.toJson(),
    files: (item) => [?item.photo],
    newId: () => 'id-${++ids}',
    now: () => DateTime(2026, 10, 10, 9),
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('outbox_test');
    scope = UserScope()..enter('ada');
    storage = UserStorage(
      const FlutterSecureStorage(),
      scope,
      files: DraftFiles(scope, root: () async => root),
    );
    outbox = build(storage);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('keeps entries in the order they were added, across restarts', () async {
    await outbox.add(const _Item('first', null));
    await outbox.add(const _Item('second', null));

    final reopened = await build(storage).entries();

    expect(reopened.map((e) => e.item.name), ['first', 'second']);
    expect(reopened.first.status, OutboxStatus.waiting);
    expect(reopened.first.savedAt, DateTime(2026, 10, 10, 9));
    expect(await outbox.count(), 2);
  });

  test('an update keeps the status, message and progress', () async {
    final entry = await outbox.add(const _Item('Ada', 'photo.jpg'));

    await outbox.update(
      entry.copyWith(
        status: OutboxStatus.needsFix,
        message: () => 'NIN name mismatch',
        progress: {'photo.jpg': 'storage/key'},
      ),
    );

    final saved = await outbox.read(entry.id);
    expect(saved?.status, OutboxStatus.needsFix);
    expect(saved?.message, 'NIN name mismatch');
    expect(saved?.progress, {'photo.jpg': 'storage/key'});
  });

  test('removing an entry deletes its files; nothing else goes', () async {
    final photo = await storage.files.keepSignature(Uint8List.fromList([1]));
    final kept = await outbox.add(const _Item('kept', null));
    final removed = await outbox.add(_Item('removed', photo));

    await outbox.remove(removed.id);
    // Updating a removed entry doesn't bring it back.
    await outbox.update(removed.copyWith(status: OutboxStatus.retryLater));

    expect(File(photo).existsSync(), isFalse);
    expect((await outbox.entries()).map((e) => e.id), [kept.id]);
  });

  test('each user has their own outbox', () async {
    await outbox.add(const _Item('Ada', null));

    scope.enter('bola');

    expect(await outbox.entries(), isEmpty);
  });

  test('an entry it cannot read is left out but kept', () async {
    final entry = await outbox.add(const _Item('Ada', null));
    await storage.write(key: 'test_outbox/${entry.id}', value: '{"x": 1}');

    expect(await outbox.entries(), isEmpty);
    expect(await outbox.count(), 1);
  });

  test('forgetting a draft keeps its files for the outbox', () async {
    final drafts = DraftStore<_Item>(
      storage,
      key: 'test_draft',
      fromJson: _Item.fromJson,
      toJson: (item) => item.toJson(),
      files: (item) => [?item.photo],
    );
    final photo = await storage.files.keepSignature(Uint8List.fromList([1]));
    await drafts.save(_Item('Ada', photo));

    await drafts.forget();

    expect(await drafts.load(), isNull);
    expect(File(photo).existsSync(), isTrue);
  });
}
