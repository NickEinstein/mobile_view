import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_dialog.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/surrogacy_birth_repository.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/nin/cubit/child_nin_cubit.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "Child's National Identity Number", the first step of a new surrogacy
/// birth registration. [onDone] (from the router) moves on to payment.
class ChildNinPage extends StatelessWidget {
  const ChildNinPage({required this.onDone, this.repository, super.key});

  final VoidCallback onDone;

  /// Defaults to the registered one; tests pass a fake.
  final SurrogacyBirthRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChildNinCubit(
        repository ?? GetIt.instance<SurrogacyBirthRepository>(),
      )..load().ignore(),
      child: ChildNinView(onDone: onDone),
    );
  }
}

class ChildNinView extends StatelessWidget {
  const ChildNinView({required this.onDone, super.key});

  final VoidCallback onDone;

  Future<void> _confirmSkip(BuildContext context) async {
    final cubit = context.read<ChildNinCubit>();
    final skip = await showDialog<bool>(
      context: context,
      builder: (_) => const _SkipDialog(),
    );
    if (skip ?? false) await cubit.skip();
  }

  Future<void> _done(BuildContext context, ChildNinState state) async {
    if (state.decision == ChildNinDecision.verified) {
      final l10n = context.l10n;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _ProgressDialog(
          title: l10n.srNinValidated,
          actionLabel: l10n.brProceed,
          onAction: () => Navigator.of(dialogContext).pop(),
        ),
      );
    }
    onDone();
  }

  void _onChange(BuildContext context, ChildNinState state) {
    switch (state.step) {
      case ChildNinStep.ready when state.justCreated:
        unawaited(
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _ReferenceCreatedDialog(state.referenceId!),
          ),
        );
      case ChildNinStep.done:
        unawaited(_done(context, state));
      case _:
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<ChildNinCubit>().state;
    final cubit = context.read<ChildNinCubit>();
    final error = switch (state.failure) {
      NotFoundFailure() => l10n.baNinNotFound,
      final failure? => failure.localize(l10n),
      null => null,
    };

    return BlocListener<ChildNinCubit, ChildNinState>(
      listenWhen: (previous, current) =>
          previous.step != current.step &&
          (current.step == ChildNinStep.done ||
              (current.justCreated && !previous.justCreated)),
      listener: _onChange,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: switch (state.step) {
            ChildNinStep.starting => const Center(
              child: CircularProgressIndicator(),
            ),
            ChildNinStep.startFailed => Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error ?? l10n.errorUnexpected,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => unawaited(cubit.load()),
                      child: Text(l10n.tryAgain),
                    ),
                  ],
                ),
              ),
            ),
            _ => Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                0,
                Spacing.md,
                Spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.srChildNinTitle,
                    style: textTheme.titleLarge?.copyWith(
                      color: AppPalette.inkStrong,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  Expanded(
                    child: ListView(
                      children: [
                        AppTextField(
                          label: l10n.srChildNinLabel,
                          hintText: l10n.srChildNinHint,
                          initialValue: state.nin,
                          enabled: !state.isBusy,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          errorText: error,
                          onChanged: cubit.ninChanged,
                          onSubmitted: (_) => unawaited(cubit.validate()),
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    label: l10n.brValidate,
                    isLoading: state.step == ChildNinStep.validating,
                    onPressed: state.canValidate ? cubit.validate : null,
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppPalette.inkStrong,
                    ),
                    onPressed: state.step == ChildNinStep.ready
                        ? () => unawaited(_confirmSkip(context))
                        : null,
                    child: state.step == ChildNinStep.skipping
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.srSkip),
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
  }
}

/// "Application Reference ID Created", with the id the server gave.
class _ReferenceCreatedDialog extends StatelessWidget {
  const _ReferenceCreatedDialog(this.referenceId);

  final String referenceId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: AppDialog(
        children: [
          Text(
            l10n.srReferenceCreatedTitle,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              color: AppPalette.inkStrong,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.srReferenceCreatedMessage,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: AppPalette.ink),
          ),
          const SizedBox(height: Spacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppPalette.fieldFill,
              borderRadius: BorderRadius.circular(Spacing.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.sm + Spacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.srReferenceLabel,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppPalette.muted,
                    ),
                  ),
                  SelectableText(
                    referenceId,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppPalette.inkStrong,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          AppButton(
            label: l10n.brProceed,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// "Skip Child NIN Verification": pops true to skip.
class _SkipDialog extends StatelessWidget {
  const _SkipDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final error = Theme.of(context).colorScheme.error;
    return AppDialog(
      children: [
        Icon(Icons.error_outline, color: error, size: 28),
        const SizedBox(height: Spacing.sm),
        Text(
          l10n.srSkipTitle,
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(
            color: AppPalette.inkStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          l10n.srSkipMessage,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppPalette.ink),
        ),
        const SizedBox(height: Spacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.brand,
                  side: const BorderSide(color: AppPalette.brand),
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.srDontSkip),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: AppButton(
                label: l10n.brProceed,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A green tick and title with one action, as the design's "NIN
/// Validated" card.
class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AppDialog(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 48,
          color: AppPalette.brand,
        ),
        const SizedBox(height: Spacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppPalette.brand,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Spacing.xl),
        AppButton(label: actionLabel, onPressed: onAction),
      ],
    ),
  );
}
