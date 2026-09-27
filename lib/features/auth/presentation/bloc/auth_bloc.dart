import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';
import 'package:vital_reg_mobile/features/auth/domain/auth_repository.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/user.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// App-wide authentication state, mirrored from [SessionManager]; the
/// router redirects from it.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required SessionManager sessionManager,
    required AuthRepository repository,
  }) : _session = sessionManager,
       _repository = repository,
       super(const AuthUnknown()) {
    on<AuthStarted>(_onStarted);
    on<_AuthSessionChanged>(_onSessionChanged, transformer: restartable());
    on<AuthLogoutRequested>(_onLogoutRequested, transformer: droppable());
  }

  final SessionManager _session;
  final AuthRepository _repository;
  StreamSubscription<SessionStatus>? _subscription;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    await _session.restore();
    await _subscription?.cancel();
    _subscription = _session.changes.listen(
      (status) => add(_AuthSessionChanged(status)),
    );
    add(_AuthSessionChanged(_session.status));
  }

  Future<void> _onSessionChanged(
    _AuthSessionChanged event,
    Emitter<AuthState> emit,
  ) async {
    switch (event.status) {
      case SessionStatus.unknown:
        emit(const AuthUnknown());
      case SessionStatus.unauthenticated:
        emit(AuthUnauthenticated(reason: _session.lastEndReason));
      case SessionStatus.authenticated:
        final result = await _repository.currentUser();
        switch (result) {
          case Ok(value: final user):
            emit(AuthAuthenticated(user));
          case Err():
            await _session.end(reason: SessionEndReason.invalid);
        }
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) => _repository.signOut(reason: event.reason);

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
