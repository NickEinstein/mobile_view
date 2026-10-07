import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/birth_attestation_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/face_verifier.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/birth_registration_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/applications_source.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:vital_reg_mobile/features/death_registration/data/death_registration_repository_impl.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_draft.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_form.dart';
import 'package:vital_reg_mobile/features/still_birth/data/still_birth_repository_impl.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_draft.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_form.dart'
    as still;
import 'package:vital_reg_mobile/features/surrogacy_birth/data/surrogacy_birth_repository_impl.dart';

import '../../helpers/demo_backend.dart';
import '../../helpers/fakes.dart';

/// Every screen's read path through the real repositories and decoders,
/// against the demo backend, so the two can't drift apart.
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  /// Counts, every status's list, and each listed record's details.
  Future<void> readsEverything(
    ApplicationsSource source,
    Future<Object?> Function(String id) details,
  ) async {
    ok(await source.counts());
    var read = 0;
    for (final status in ApplicationStatus.values) {
      final items = ok(await source.applications(status: status));
      for (final item in items) {
        await details(item.id);
        read++;
      }
    }
    expect(read, isPositive, reason: 'the demo lists no records to read');
  }

  test('birth registration', () async {
    final repository = BirthRegistrationRepositoryImpl(
      client: demoBackend().client,
      storage: signedInUserStorage(),
    );
    ok(await repository.referenceData());
    await readsEverything(
      repository,
      (id) async => ok(await repository.details(id)),
    );
  });

  test('birth attestation', () async {
    final client = demoBackend().client;
    final repository = BirthAttestationRepositoryImpl(
      client: client,
      storage: signedInUserStorage(),
      faces: FaceVerifier(client: client, url: demoFaceUrl),
    );
    ok(await repository.referenceData());
    ok(await repository.payments.quote());
    await readsEverything(
      repository,
      (id) async => ok(await repository.details(id)),
    );
  });

  test('death registration', () async {
    final repository = DeathRegistrationRepositoryImpl(
      client: demoBackend().client,
      storage: signedInUserStorage(),
    );
    ok(await repository.referenceData());
    await readsEverything(repository, (id) async {
      final record = ok(await repository.details(id));
      final d = record.deceased;
      final i = record.informant;
      // The record's ids are the option lists', so each has a label.
      final data = ok(
        await repository.referenceData(
          withLgasOf: deathStates(deceased: d, informant: i),
        ),
      );
      void known(List<Option> options, String? value, String what) => expect(
        value == null || options.any((o) => o.id == value),
        isTrue,
        reason: '$what "$value" of record $id',
      );
      known(data.sexes, d[DeceasedField.sex], 'sex');
      known(data.placesOfDeath, d[DeceasedField.placeOfDeath], 'place');
      known(data.settlements, d[DeceasedField.settlement], 'settlement');
      known(data.occupations, d[DeceasedField.occupation], 'occupation');
      known(data.maritalStatuses, d[DeceasedField.maritalStatus], 'marital');
      known(data.literacy, d[DeceasedField.literacy], 'literacy');
      known(data.educationLevels, d[DeceasedField.educationLevel], 'education');
      known(data.yesNo, d[DeceasedField.certifiedByDoctor], 'certified');
      known(data.causesOfDeath, d[DeceasedField.causeOfDeath], 'cause');
      known(data.ethnicGroups, d[DeceasedField.ethnicGroup], 'ethnic group');
      known(data.lgasOf(d[DeceasedField.state]), d[DeceasedField.lga], 'LGA');
      known(data.relationships, i[InformantField.relationship], 'relation');
      return record;
    });
  });

  test("death records decode from the backend's shapes", () async {
    final repository = DeathRegistrationRepositoryImpl(
      client: demoBackend().client,
      storage: signedInUserStorage(),
    );

    // Counts arrive as SQL sums, i.e. strings.
    final counts = ok(await repository.counts());
    expect(counts.of(ApplicationStatus.approved), 3);
    final queried = ok(await repository.details('40300'));

    expect(queried.summary.status, ApplicationStatus.queried);
    expect(queried.queryReason, 'Wrong document uploaded');
    // Only the description comes back; its id is the option's.
    expect(queried.deceased[DeceasedField.placeOfDeath], '2');
    expect(queried.deceased[DeceasedField.nationality], '63');
    expect(queried.informant[InformantField.relationship], '3');
    // Keys, not viewing URLs, so a correction can send them back.
    expect(queried.signatureKey, 'death/sign-40300.png');
    expect(queried.documentKeys.values, everyElement(startsWith('death/')));
  });

  test('still birth', () async {
    final repository = StillBirthRepositoryImpl(
      client: demoBackend().client,
      storage: signedInUserStorage(),
    );
    ok(await repository.referenceData());
    ok(await repository.count());
    final items = ok(await repository.registrations());
    expect(items, isNotEmpty);
    for (final item in items) {
      final record = ok(await repository.details(item.id));
      // `single` doesn't return the id; the one asked for stands.
      expect(record.summary.id, item.id);
      final m = record.mother;
      final data = ok(
        await repository.referenceData(
          withLgasOf: stillBirthStates(mother: m, informant: record.informant),
        ),
      );
      expect(
        data.lgasOf(m[still.MotherField.state]).map((o) => o.id),
        contains(m[still.MotherField.lga]),
      );
    }
    final first = ok(await repository.details(items.first.id));
    expect(first.summary.status, ApplicationStatus.approved);
  });

  test('surrogacy birth', () async {
    final repository = SurrogacyBirthRepositoryImpl(
      client: demoBackend().client,
      storage: signedInUserStorage(),
    );
    ok(await repository.referenceData());
    ok(await repository.drafts());
    await readsEverything(
      repository,
      (id) async => ok(await repository.details(id)),
    );
  });

  test('dashboard', () async {
    final repository = DashboardRepositoryImpl(demoBackend().client);
    ok(await repository.summary(year: 2026));
  });
}
