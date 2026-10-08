import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/session/inactivity_watcher.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';

/// Runs the [InactivityWatcher] while signed in; a timeout logs out through
/// [AuthBloc].
class SessionTimeoutScope extends StatelessWidget {
  const SessionTimeoutScope({
    required this.timeout,
    required this.child,
    super.key,
  });

  final Duration timeout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select(
      (AuthBloc bloc) => bloc.state is AuthAuthenticated,
    );
    return InactivityWatcher(
      enabled: isAuthenticated,
      timeout: timeout,
      onTimeout: () => context.read<AuthBloc>().add(
        const AuthLogoutRequested(reason: SessionEndReason.inactivity),
      ),
      child: child,
    );
  }
}
