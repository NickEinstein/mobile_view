import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/session/user_scope.dart';
import 'package:vital_reg_mobile/core/storage/draft_files.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';

void main() {
  late Directory root;
  late UserScope scope;
  late UserStorage storage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('user_storage_test');
    scope = UserScope()..enter('ada');
    storage = UserStorage(
      const FlutterSecureStorage(),
      scope,
      files: DraftFiles(scope, root: () async => root),
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  test("a user never reads another user's draft", () async {
    await storage.write(key: 'birth_registration_draft', value: 'ada draft');

    scope.enter('grace');
    expect(await storage.read(key: 'birth_registration_draft'), isNull);
    await storage.write(key: 'birth_registration_draft', value: 'grace draft');

    scope.enter('ada');
    expect(await storage.read(key: 'birth_registration_draft'), 'ada draft');
  });

  test('ids that differ only in unsafe characters stay apart', () async {
    scope.enter('a/b');
    await storage.write(key: 'draft', value: 'one');
    scope.enter('a_b');
    expect(await storage.read(key: 'draft'), isNull);
  });

  group('clearDrafts', () {
    test("removes the user's drafts and files, keeping payments", () async {
      final paymentKey = UserStorage.paymentKey('attestation_payment');
      await storage.write(key: 'birth_registration_draft', value: 'draft');
      await storage.write(key: paymentKey, value: 'paid reference');
      final photo = File(
        await storage.files.keepSignature(Uint8List.fromList([1])),
      );

      await storage.clearDrafts();

      expect(await storage.read(key: 'birth_registration_draft'), isNull);
      expect(await storage.read(key: paymentKey), 'paid reference');
      expect(photo.existsSync(), isFalse);
    });

    test("leaves other users' drafts and files alone", () async {
      scope.enter('grace');
      await storage.write(key: 'birth_registration_draft', value: 'grace');
      final gracePhoto = File(
        await storage.files.keepSignature(Uint8List.fromList([1])),
      );

      scope.enter('ada');
      await storage.write(key: 'birth_registration_draft', value: 'ada');
      await storage.clearDrafts();

      scope.enter('grace');
      expect(await storage.read(key: 'birth_registration_draft'), 'grace');
      expect(gracePhoto.existsSync(), isTrue);
    });

    test('does nothing before anyone has signed in', () async {
      final signedOut = UserStorage(const FlutterSecureStorage(), UserScope());
      await expectLater(signedOut.clearDrafts(), completes);
    });
  });

  group('UserCache', () {
    test('reads as empty after a different user signs in', () {
      final cache = UserCache<String>(scope)..value = 'ada lists';
      expect(cache.value, 'ada lists');

      scope.enter('grace');
      expect(cache.value, isNull);

      cache.value = 'grace lists';
      expect(cache.value, 'grace lists');
    });
  });
}
