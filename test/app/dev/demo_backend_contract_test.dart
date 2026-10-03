import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/birth_registration_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/applications_source.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/dashboard/data/dashboard_repository_impl.dart';

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

  test('dashboard', () async {
    final repository = DashboardRepositoryImpl(demoBackend().client);
    ok(await repository.summary(year: 2026));
  });
}
