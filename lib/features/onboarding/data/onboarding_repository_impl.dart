import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_reg_mobile/features/onboarding/domain/onboarding_repository.dart';

/// Stores the flag in SharedPreferences. It isn't sensitive, so it doesn't
/// belong in secure storage. A reinstall clears it and shows onboarding again.
class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl(this._preferences);

  final SharedPreferences _preferences;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  static const _key = 'onboarding_completed';

  @override
  bool get isCompleted => _preferences.getBool(_key) ?? false;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<void> markCompleted() async {
    if (isCompleted) return;
    await _preferences.setBool(_key, true);
    _changes.add(true);
  }

  Future<void> dispose() => _changes.close();
}
