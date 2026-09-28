import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/core/session/user_scope.dart';
import 'package:vital_reg_mobile/core/storage/draft_files.dart';
import 'package:vital_reg_mobile/core/storage/draft_store.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';

final class _Draft {
  const _Draft(this.name, this.photo);

  factory _Draft.fromJson(JsonMap json) =>
      _Draft(json.requireString('name'), json['photo'] as String?);

  final String name;
  final String? photo;

  JsonMap toJson() => {'name': name, 'photo': photo};
}

void main() {
  late Directory root;
  late UserStorage storage;
  late DraftStore<_Draft> drafts;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('draft_store_test');
    final scope = UserScope()..enter('ada');
    storage = UserStorage(
      const FlutterSecureStorage(),
      scope,
      files: DraftFiles(scope, root: () async => root),
    );
    drafts = DraftStore<_Draft>(
      storage,
      key: 'test_draft',
      fromJson: _Draft.fromJson,
      toJson: (draft) => draft.toJson(),
      files: (draft) => [?draft.photo],
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('saves and loads a draft', () async {
    expect(await drafts.load(), isNull);
    await drafts.save(const _Draft('Ada', null));
    expect((await drafts.load())?.name, 'Ada');
  });

  test('drops a draft it cannot read', () async {
    await storage.write(key: 'test_draft', value: '{"no name": true}');

    expect(await drafts.load(), isNull);
    expect(await storage.read(key: 'test_draft'), isNull);
  });

  test('discarding deletes the draft and its files', () async {
    final photo = await storage.files.keepSignature(Uint8List.fromList([1]));
    await drafts.save(_Draft('Ada', photo));

    final discarded = await drafts.discard();

    expect(discarded?.name, 'Ada');
    expect(File(photo).existsSync(), isFalse);
    expect(await drafts.load(), isNull);
  });
}
