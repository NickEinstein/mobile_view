import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_reg_mobile/features/onboarding/data/onboarding_repository_impl.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<OnboardingRepositoryImpl> build() async =>
      OnboardingRepositoryImpl(await SharedPreferences.getInstance());

  test('is not completed on a fresh install', () async {
    final repository = await build();

    expect(repository.isCompleted, isFalse);
    await repository.dispose();
  });

  test('markCompleted persists across launches and notifies once', () async {
    final repository = await build();
    final emitted = <bool>[];
    final subscription = repository.changes.listen(emitted.add);

    await repository.markCompleted();
    await repository.markCompleted();
    await Future<void>.delayed(Duration.zero);

    expect(repository.isCompleted, isTrue);
    expect(emitted, [true]);

    final nextLaunch = await build();
    expect(nextLaunch.isCompleted, isTrue);

    await subscription.cancel();
    await repository.dispose();
    await nextLaunch.dispose();
  });
}
