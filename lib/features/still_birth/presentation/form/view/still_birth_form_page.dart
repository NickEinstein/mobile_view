import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_date_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_dialog.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_signature_pad.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_form_layout.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_upload_tile.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_form.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/still_birth_repository.dart';
import 'package:vital_reg_mobile/features/still_birth/presentation/form/cubit/still_birth_form_cubit.dart';
import 'package:vital_reg_mobile/features/still_birth/presentation/shared/still_birth_sections.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'deceased_step.dart';
part 'form_fields.dart';
part 'informant_step.dart';
part 'mother_step.dart';
part 'review_step.dart';
part 'submitted_dialog.dart';

/// The four-step Still Birth Registration form. [onExit] (from the router)
/// leaves it; progress is already saved.
class StillBirthFormPage extends StatelessWidget {
  const StillBirthFormPage({required this.onExit, this.repository, super.key});

  final VoidCallback onExit;

  /// Defaults to the registered one; tests pass a fake.
  final StillBirthRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StillBirthFormCubit(
        repository ?? GetIt.instance<StillBirthRepository>(),
      )..load().ignore(),
      child: StillBirthFormView(onExit: onExit),
    );
  }
}

class StillBirthFormView extends StatelessWidget {
  const StillBirthFormView({required this.onExit, super.key});

  final VoidCallback onExit;

  /// "Exit Application?" — progress is saved either way.
  Future<void> _confirmExit(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<StillBirthFormCubit>();
    if (cubit.state.status != FormStatus.ready) {
      onExit();
      return;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        children: [
          Text(
            l10n.brExitTitle,
            textAlign: TextAlign.center,
            style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
              color: AppPalette.inkStrong,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(l10n.brExitMessage, textAlign: TextAlign.center),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.no),
                ),
              ),
              Expanded(
                child: AppButton(
                  label: l10n.yes,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (exit ?? false) {
      await cubit.flush();
      onExit();
    }
  }

  Future<void> _submitted(
    BuildContext context,
    StillBirthFormState state,
  ) async {
    await _showSubmittedDialog(context, trackingId: state.trackingId);
    onExit();
  }

  void _onSubmitStatus(BuildContext context, StillBirthFormState state) {
    switch (state.submitStatus) {
      case SubmitStatus.submitted:
        unawaited(_submitted(context, state));
      case SubmitStatus.failed:
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.submitFailure?.localize(l10n) ?? l10n.errorUnexpected,
            ),
          ),
        );
      case SubmitStatus.idle || SubmitStatus.submitting:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<StillBirthFormCubit>().state;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit(context));
      },
      child: BlocListener<StillBirthFormCubit, StillBirthFormState>(
        listenWhen: (previous, current) =>
            previous.submitStatus != current.submitStatus,
        listener: _onSubmitStatus,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            leading: BackButton(
              onPressed: () => unawaited(_confirmExit(context)),
            ),
          ),
          body: switch (state.status) {
            FormStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            FormStatus.failure => Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.failure?.localize(l10n) ?? l10n.brLoadFailed,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () =>
                          unawaited(context.read<StillBirthFormCubit>().load()),
                      child: Text(l10n.tryAgain),
                    ),
                  ],
                ),
              ),
            ),
            FormStatus.ready => _FormBody(
              onExit: () => unawaited(_confirmExit(context)),
            ),
          },
        ),
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<StillBirthFormCubit>().state;
    final step = state.step;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          AppFormHeader(
            title: l10n.moduleStillBirthRegistration,
            startedOn: state.draft!.startedOn,
            step: step.number,
            stepCount: StillBirthStep.count,
            stepOf: l10n.brStepOf(step.number, StillBirthStep.count),
            stepName: step.title(l10n),
          ),
          Expanded(
            child: ListView(
              // A new step starts at the top.
              key: ValueKey(step),
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.md,
                Spacing.md,
                Spacing.lg,
              ),
              children: [
                switch (step) {
                  StillBirthStep.deceased => const _DeceasedStep(),
                  StillBirthStep.mother => const _MotherStep(),
                  StillBirthStep.informant => const _InformantStep(),
                  StillBirthStep.review => const _ReviewStep(),
                },
              ],
            ),
          ),
          _FormActions(onExit: onExit),
        ],
      ),
    );
  }
}

/// "Next" (or "Submit" on the preview), then "Back": the step before, or
/// leaving the form on the first.
class _FormActions extends StatelessWidget {
  const _FormActions({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<StillBirthFormCubit>();
    final state = context.watch<StillBirthFormCubit>().state;
    final step = state.step;
    final review = step == StillBirthStep.review;
    final submitting = state.submitStatus == SubmitStatus.submitting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grey until the step can go on; a tap before then shows what's
          // missing.
          AppButton(
            label: review ? l10n.brSubmit : l10n.brNext,
            muted: review
                ? !state.canSubmit(cubit.today)
                : !state.isStepComplete(cubit.today),
            isLoading: submitting,
            onPressed: review ? () => unawaited(cubit.submit()) : cubit.next,
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppPalette.inkStrong),
            onPressed: submitting
                ? null
                : step == StillBirthStep.deceased
                ? onExit
                : cubit.previous,
            child: Text(l10n.back),
          ),
        ],
      ),
    );
  }
}

extension on StillBirthStep {
  String title(AppLocalizations l10n) => switch (this) {
    StillBirthStep.deceased => l10n.sbStepDeceased,
    StillBirthStep.mother => l10n.brStepMother,
    StillBirthStep.informant => l10n.brStepInformant,
    StillBirthStep.review => l10n.brReviewTitle,
  };
}
