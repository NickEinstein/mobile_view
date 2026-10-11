import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/offline/offline_mode.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/storage/outbox.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/outbox_sync.dart';

import '../../helpers/fakes.dart';
import 'fake_birth_registration_repository.dart';
import 'sample_data.dart';

final _today = DateTime(2026, 10, 10);

/// The fake NIN record's name: Ogunlade Ada.
ParentParticulars _mother({
  String surname = 'Ogunlade',
  String first = 'Ada',
}) => completeParent()
    .set(ParentField.surname, surname)
    .set(ParentField.firstName, first);

RegistrationDraft _draft({ParentParticulars? mother}) =>
    completeDraft(_today).copyWith(
      submissionKey: 'key-1',
      mother: mother ?? _mother(),
      // Without a NIN, so only the mother's is checked.
      father: completeParent().set(ParentField.nin, ''),
    );

void main() {
  late FakeBirthRegistrationRepository repository;
  late OutboxSync sync;
  var signedIn = true;
  var now = DateTime(2026, 10, 10, 9);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    repository = FakeBirthRegistrationRepository();
    signedIn = true;
    now = DateTime(2026, 10, 10, 9);
    sync = OutboxSync(
      repository,
      OfflineMode(signedInUserStorage()),
      isSignedIn: () => signedIn,
      now: () => now,
    );
  });

  Future<OutboxEntry<RegistrationDraft>> save(RegistrationDraft draft) async {
    await repository.saveForLater(draft);
    return repository.outboxEntries.last;
  }

  OutboxEntry<RegistrationDraft>? entry(String id) =>
      repository.outboxEntries.where((e) => e.id == id).firstOrNull;

  test('checks the NINs, sends the application and removes it', () async {
    await save(_draft());

    await sync.syncAll();

    expect(repository.checkedNins, ['12345678901']);
    expect(repository.submitted.single.submissionKey, 'key-1');
    expect(repository.outboxEntries, isEmpty);
  });

  test('a different surname needs fixing, and nothing is sent', () async {
    final saved = await save(_draft(mother: _mother(surname: 'Bello')));

    await sync.syncAll();

    expect(repository.submitted, isEmpty);
    expect(entry(saved.id)?.status, OutboxStatus.needsFix);
    final problem = SyncProblem.of(entry(saved.id)?.message);
    expect(problem?.check, SyncCheck.ninNameMismatch);
    expect(problem?.person, SyncPerson.mother);
  });

  test('a different first name alone is enough to need fixing', () async {
    final saved = await save(_draft(mother: _mother(first: 'Bola')));

    await sync.syncAll();

    expect(entry(saved.id)?.status, OutboxStatus.needsFix);
  });

  test('names match whatever their case and spacing', () async {
    await save(
      _draft(
        mother: _mother(surname: ' OGUNLADE ', first: 'ada'),
      ),
    );

    await sync.syncAll();

    expect(repository.outboxEntries, isEmpty);
  });

  test('a NIN with no record needs fixing', () async {
    repository.ninResult = const Err(NotFoundFailure());
    final saved = await save(_draft());

    await sync.syncAll();

    final problem = SyncProblem.of(entry(saved.id)?.message);
    expect(problem?.check, SyncCheck.ninNotFound);
  });

  test("the informant's tracking ID must carry their name", () async {
    final draft = _draft();
    final saved = await save(
      draft.copyWith(
        informant: draft.informant
            .set(InformantField.surname, 'Ogunlade')
            .set(InformantField.firstName, 'Kemi')
            .set(InformantField.trackingId, 'ABCDEFGHIJ12345'),
      ),
    );

    await sync.syncAll();

    expect(repository.checkedTrackingIds, ['ABCDEFGHIJ12345']);
    final problem = SyncProblem.of(entry(saved.id)?.message);
    expect(problem?.check, SyncCheck.trackingIdNameMismatch);
    expect(problem?.person, SyncPerson.informant);
  });

  test('the child NIN kept unchecked offline is checked too', () async {
    await save(
      RegistrationDraft(
        startedOn: _today,
        childHasNin: true,
        childNin: '11111111111',
        child: completeChild()
            .set(ChildField.surname, 'Ogunlade')
            .set(ChildField.firstName, 'Ada'),
        mother: _mother(),
        father: completeParent().set(ParentField.nin, ''),
        informant: informantWithoutId(),
      ),
    );

    await sync.syncAll();

    expect(repository.checkedNins, ['11111111111', '12345678901']);
    expect(repository.outboxEntries, isEmpty);
  });

  test(
    'without a connection it stops, and the retry skips what was done',
    () async {
      repository.submitResult = const Err(NetworkFailure());
      final first = await save(_draft());
      final second = await save(_draft());

      await sync.syncAll();

      expect(entry(first.id)?.status, OutboxStatus.retryLater);
      // The second wasn't tried: the connection is down.
      expect(entry(second.id)?.status, OutboxStatus.waiting);
      expect(repository.submitted, hasLength(1));

      repository.submitResult = const Ok('BR123');
      await sync.syncAll();

      // The NIN wasn't checked again, nor the files uploaded again.
      expect(repository.checkedNins, hasLength(2));
      expect(
        repository.submittedWithUploads[1],
        containsPair('imc.jpg', 'key/imc.jpg'),
      );
      expect(repository.outboxEntries, isEmpty);
    },
  );

  test('a record the server already has is never sent again', () async {
    repository.submitResult = const Err(
      ValidationFailure(message: 'hash must be unique'),
    );
    final saved = await save(_draft());

    await sync.syncAll();
    await sync.syncAll();
    await sync.syncOne(saved.id);

    expect(entry(saved.id)?.status, OutboxStatus.possibleDuplicate);
    expect(repository.submitted, hasLength(1));
  });

  test('a rejection needs fixing; the others are still sent', () async {
    repository.submitResult = const Err(
      ValidationFailure(message: 'Invalid birth order'),
    );
    final rejected = await save(_draft());
    await sync.syncAll();
    repository.submitResult = const Ok('BR123');
    await save(_draft());

    await sync.syncAll();

    expect(entry(rejected.id)?.status, OutboxStatus.needsFix);
    expect(entry(rejected.id)?.message, 'Invalid birth order');
    expect(repository.outboxEntries, hasLength(1));

    // Sent on request once fixed elsewhere.
    await sync.syncOne(rejected.id);
    expect(repository.outboxEntries, isEmpty);
  });

  test("the server's rate limit pauses sending", () async {
    repository.submitResult = const Err(
      RateLimitedFailure(retryAfter: Duration(seconds: 40)),
    );
    await save(_draft());
    await sync.syncAll();
    repository.submitResult = const Ok('BR123');

    await sync.syncAll();
    expect(repository.outboxEntries, hasLength(1));

    now = now.add(const Duration(seconds: 41));
    await sync.syncAll();
    expect(repository.outboxEntries, isEmpty);
  });

  test('nothing is sent while signed out', () async {
    signedIn = false;
    await save(_draft());

    await sync.syncAll();

    expect(repository.submitted, isEmpty);
  });

  test('a second request joins the run under way', () async {
    await save(_draft());

    await Future.wait([sync.syncAll(), sync.syncAll()]);

    expect(repository.submitted, hasLength(1));
  });
}
