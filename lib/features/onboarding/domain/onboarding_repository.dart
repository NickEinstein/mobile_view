/// Whether this device has been through onboarding. Read synchronously by
/// the router, which also listens to [changes].
abstract interface class OnboardingRepository {
  bool get isCompleted;

  /// Emits when [isCompleted] changes.
  Stream<bool> get changes;

  /// Idempotent. Called from Skip or from the last page.
  Future<void> markCompleted();
}
