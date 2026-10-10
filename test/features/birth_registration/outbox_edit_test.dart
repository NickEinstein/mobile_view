import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/offline/offline_mode.dart';
import 'package:vital_reg_mobile/core/storage/outbox.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/birth_registration_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/outbox_sync.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/form/cubit/registration_form_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/outbox/view/outbox_page.dart';

import '../../helpers/demo_backend.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_birth_registration_repository.dart';
import 'sample_data.dart';

final _today = DateTime(2026, 10, 10);

void main() {
  late FakeBirthRegistrationRepository repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    repository = FakeBirthRegistrationRepository();
  });

  Future<OutboxEntry<RegistrationDraft>> saved({
    OutboxStatus status = OutboxStatus.waiting,
    String? message,
  }) async {
    await repository.saveForLater(
      completeDraft(_today).copyWith(
        submissionKey: 'key-1',
        child: completeChild()
            .set(ChildField.surname, 'Ogunlade')
            .set(ChildField.firstName, 'Ada')
            .set(ChildField.facePhoto, 'old-face.jpg'),
        // The father's NIN record carries his name (see the fake).
        mother: completeParent().set(ParentField.nin, ''),
        father: completeParent()
            .set(ParentField.surname, 'Ogunlade')
            .set(ParentField.firstName, 'Ada'),
      ),
    );
    final entry = repository.outboxEntries.last.copyWith(
      status: status,
      message: () => message,
    );
    await repository.updateOutbox(entry);
    return entry;
  }

  RegistrationFormCubit edit(String id) =>
      RegistrationFormCubit(repository, outboxId: id, now: () => _today);

  group('editing an outbox application', () {
    test('opens on the review, without touching the saved draft', () async {
      final entry = await saved();
      final cubit = edit(entry.id);

      await cubit.load();

      expect(cubit.state.step, RegistrationStep.review);
      expect(cubit.state.draft?.child[ChildField.surname], 'Ogunlade');
      cubit.childChanged(ChildField.firstName, 'Adaeze');
      await cubit.flush();
      expect(repository.draft, isNull);
      await cubit.close();
    });

    test('saving puts it back as waiting, with the same key', () async {
      final entry = await saved(
        status: OutboxStatus.needsFix,
        message: 'check:ninNameMismatch:mother',
      );
      final cubit = edit(entry.id);
      await cubit.load();
      cubit
        ..childChanged(ChildField.firstName, 'Adaeze')
        ..declarationChanged(declared: true);

      await cubit.submit();

      expect(cubit.state.submitStatus, SubmitStatus.savedForLater);
      final updated = repository.outboxEntries.single;
      expect(updated.status, OutboxStatus.waiting);
      expect(updated.message, isNull);
      expect(updated.item.child[ChildField.firstName], 'Adaeze');
      expect(updated.item.submissionKey, 'key-1');
      expect(repository.submitted, isEmpty);
      await cubit.close();
    });

    test("a new photo doesn't delete the saved one until saved", () async {
      final entry = await saved();
      final cubit = edit(entry.id);
      await cubit.load();

      await cubit.childPhotoCaptured('new-face.jpg');
      await cubit.close();

      // Left unsaved: the new photo goes, the saved one stays.
      expect(repository.deletedFiles, ['new-face.jpg']);
      expect(
        repository.outboxEntries.single.item.child[ChildField.facePhoto],
        'old-face.jpg',
      );
    });
  });

  test(
    'replacing an outbox application deletes the files it dropped',
    () async {
      final root = Directory.systemTemp.createTempSync('outbox_replace');
      addTearDown(() => root.deleteSync(recursive: true));
      final repository = BirthRegistrationRepositoryImpl(
        client: demoBackend().client,
        storage: signedInUserStorage(),
      );
      Future<String> file(String name) async {
        final path = '${root.path}/$name';
        await File(path).writeAsBytes([1]);
        return path;
      }

      final (oldFace, newFace) = (await file('old.jpg'), await file('new.jpg'));
      final draft = completeDraft(
        _today,
      ).copyWith(child: completeChild().set(ChildField.facePhoto, oldFace));
      await repository.saveForLater(draft);
      final entry = (await repository.outbox()).single;
      await repository.updateOutbox(
        entry.copyWith(status: OutboxStatus.needsFix, message: () => 'x'),
      );

      await repository.replaceInOutbox(
        entry.id,
        draft.copyWith(child: draft.child.set(ChildField.facePhoto, newFace)),
      );

      final replaced = (await repository.outbox()).single;
      expect(replaced.status, OutboxStatus.waiting);
      expect(replaced.message, isNull);
      expect(File(oldFace).existsSync(), isFalse);
      expect(File(newFace).existsSync(), isTrue);
    },
  );

  group('OutboxPage', () {
    Future<void> pump(WidgetTester tester) => tester.pumpApp(
      OutboxPage(
        repository: repository,
        sync: OutboxSync(
          repository,
          OfflineMode(signedInUserStorage()),
          isSignedIn: () => true,
        ),
        onEdit: (_) async {},
      ),
    );

    testWidgets('shows each application and why it needs fixing', (
      tester,
    ) async {
      await saved(
        status: OutboxStatus.needsFix,
        message: 'check:ninNameMismatch:mother',
      );
      await saved(status: OutboxStatus.possibleDuplicate);

      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('Ogunlade Ada'), findsNWidgets(2));
      expect(find.text('Needs fixing'), findsOneWidget);
      expect(
        find.textContaining("The mother's name doesn't match"),
        findsOneWidget,
      );
      expect(find.text('Possible duplicate'), findsOneWidget);
      expect(find.text('Send all now'), findsOneWidget);
    });

    testWidgets('deleting asks first', (tester) async {
      await saved();
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this application?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.outboxEntries, isEmpty);
      expect(find.text('Nothing is waiting to be sent.'), findsOneWidget);
    });

    testWidgets('Send all now sends what is waiting', (tester) async {
      await saved();
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send all now'));
      await tester.pumpAndSettle();

      expect(repository.submitted, hasLength(1));
      expect(repository.outboxEntries, isEmpty);
    });
  });
}
