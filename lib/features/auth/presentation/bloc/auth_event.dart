part of 'auth_bloc.dart';

sealed class AuthEvent {
  const AuthEvent();
}

/// Dispatched once when the app starts.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested({this.reason = SessionEndReason.userInitiated});

  final SessionEndReason reason;
}

final class _AuthSessionChanged extends AuthEvent {
  const _AuthSessionChanged(this.status);

  final SessionStatus status;
}
