import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/features/dashboard/data/dashboard_repository_impl.dart';

import '../../helpers/demo_backend.dart';

/// Every screen's read path through the real repositories and decoders,
/// against the demo backend, so the two can't drift apart.
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('dashboard', () async {
    final repository = DashboardRepositoryImpl(demoBackend().client);
    ok(await repository.summary(year: 2026));
  });
}
