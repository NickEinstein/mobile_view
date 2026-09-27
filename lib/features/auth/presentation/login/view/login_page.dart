import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/core/session/session_manager.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/auth/domain/auth_repository.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vital_reg_mobile/features/auth/presentation/login/cubit/login_cubit.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'login_form_fields.dart';

// Layout measured from the Figma "Auth Screen" frame (375pt wide).
const _headerImage = 'assets/images/auth/login_header.jpg';
const _logo = 'assets/images/branding/logo_full.png';
const _headerHeight = 120.0;
const _cardRadius = 32.0;

/// Product name in the heading. Not translated.
const _brand = 'VitalReg';

/// Composition only: provides the cubit. All UI lives in [LoginView], which
/// tests pump with a mock cubit.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(GetIt.instance<AuthRepository>()),
      child: const LoginView(),
    );
  }
}

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, current) =>
          current is AuthUnauthenticated &&
          current.reason == SessionEndReason.invalid,
      listener: (context, _) => context.read<LoginCubit>().sessionRejected(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Photo behind the top of the card. Until it is added, a light
            // brand tint shows instead.
            Positioned(
              top: topInset,
              left: 0,
              right: 0,
              height: _headerHeight + _cardRadius,
              child: Image.asset(
                _headerImage,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: AppPalette.brand.withValues(alpha: 0.12)),
              ),
            ),
            const SafeArea(
              bottom: false,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: _headerHeight)),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(_cardRadius),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            Spacing.md,
                            Spacing.xl + Spacing.sm,
                            Spacing.md,
                            Spacing.lg,
                          ),
                          child: _LoginForm(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm();

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final endReason = authState is AuthUnauthenticated
        ? authState.reason
        : null;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading(),
          const SizedBox(height: Spacing.xl),
          if (endReason case final reason?
              when reason != SessionEndReason.userInitiated) ...[
            _SessionEndedBanner(reason: reason),
            const SizedBox(height: Spacing.md),
          ],
          const _EmailField(),
          const SizedBox(height: Spacing.lg),
          const _PasswordField(),
          const _ForgotPassword(),
          const _FailureText(),
          const Spacer(),
          const SizedBox(height: Spacing.lg),
          const _SubmitButton(),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final title = l10n.loginWelcome(_brand);
    final brandStart = title.indexOf(_brand);

    return Column(
      children: [
        Image.asset(_logo, height: 24, semanticLabel: l10n.appTitle),
        const SizedBox(height: Spacing.md),
        Text.rich(
          TextSpan(
            children: [
              if (brandStart < 0)
                TextSpan(text: title)
              else ...[
                TextSpan(text: title.substring(0, brandStart)),
                const TextSpan(
                  text: _brand,
                  style: TextStyle(color: AppPalette.brand),
                ),
                TextSpan(text: title.substring(brandStart + _brand.length)),
              ],
            ],
          ),
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            color: AppPalette.inkStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          l10n.loginSubtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: AppPalette.muted),
        ),
      ],
    );
  }
}
