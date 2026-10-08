import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/auth/domain/auth_repository.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repository) : super(const LoginState());

  final AuthRepository _repository;

  void emailChanged(String value) => emit(
    state.copyWith(email: Email.dirty(value), status: LoginStatus.editing),
  );

  void passwordChanged(String value) => emit(
    state.copyWith(
      password: Password.dirty(value),
      status: LoginStatus.editing,
    ),
  );

  Future<void> submit() async {
    if (state.status.isBusy) return;

    final email = Email.dirty(state.email.value);
    final password = Password.dirty(state.password.value);
    if (!Formz.validate([email, password])) {
      emit(state.copyWith(email: email, password: password));
      return;
    }

    emit(
      state.copyWith(
        email: email,
        password: password,
        status: LoginStatus.submitting,
      ),
    );
    final result = await _repository.signIn(email: email, password: password);
    if (isClosed) return;

    switch (result) {
      case Ok():
        // The session has started. AuthBloc and the router take it from here.
        emit(state.copyWith(status: LoginStatus.success));
      case Err(:final failure):
        emit(state.copyWith(status: LoginStatus.failure, failure: failure));
    }
  }

  /// Sign-in succeeded but the profile could not be loaded (AuthBloc ended
  /// the session). Stop the spinner and explain.
  void sessionRejected() {
    if (state.status != LoginStatus.success) return;
    emit(
      state.copyWith(
        status: LoginStatus.failure,
        failure: const UnauthorizedFailure(),
      ),
    );
  }
}
