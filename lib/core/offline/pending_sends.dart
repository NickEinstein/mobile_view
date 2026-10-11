/// Work kept on the device that hasn't reached the server yet (e.g.
/// registrations saved offline). Logging out deletes it.
abstract interface class PendingSends {
  /// How many items are still on the device, whatever their state.
  Future<int> count();

  /// Tries to send everything now; completes when done.
  Future<void> sendNow();
}
