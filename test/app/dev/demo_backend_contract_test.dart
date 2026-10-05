import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/birth_attestation_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/face_verifier.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/birth_registration_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/applications_source.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:vital_reg_mobile/features/still_birth/data/still_birth_repository_impl.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_draft.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_form.dart'
    as still;

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

  test('dashboard', () async {
    final repository = DashboardRepositoryImpl(demoBackend().client);
    ok(await repository.summary(year: 2026));
  });
}
