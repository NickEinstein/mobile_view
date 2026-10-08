import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_date_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_dialog.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_radio_group.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_signature_pad.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_form_layout.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_upload_tile.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/death_registration_repository.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_form.dart';
import 'package:vital_reg_mobile/features/death_registration/presentation/form/cubit/death_form_cubit.dart';
import 'package:vital_reg_mobile/features/death_registration/presentation/shared/death_sections.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'deceased_step.dart';
part 'documents_step.dart';
part 'form_fields.dart';
part 'informant_step.dart';
part 'review_step.dart';
part 'submitted_dialog.dart';

/// The four-step Death Registration form. [onExit] (from the router)
/// leaves it; progress is already saved.
class DeathFormPage extends StatelessWidget {
  const DeathFormPage({
    required this.onExit,
    this.queriedRecordId,
    this.repository,
    super.key,
  });

  final VoidCallback onExit;

  /// Corrects this queried record instead of registering a new death.
  final String? queriedRecordId;

  /// Defaults to the registered one; tests pass a fake.
  final DeathRegistrationRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DeathFormCubit(
        repository ?? GetIt.instance<DeathRegistrationRepository>(),
        queriedRecordId: queriedRecordId,
      )..load().ignore(),
      child: DeathFormView(onExit: onExit),
    );
  }
}

class DeathFormView extends StatelessWidget {
  const DeathFormView({required this.onExit, super.key});

  final VoidCallback onExit;

  /// "Exit Application?" — progress is saved either way.
  Future<void> _confirmExit(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<DeathFormCubit>();
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

  Future<void> _submitted(BuildContext context, DeathFormState state) async {
    await _showSubmittedDialog(
      context,
      trackingId: state.trackingId,
      correction: state.isCorrection,
    );
    onExit();
  }

  void _onSubmitStatus(BuildContext context, DeathFormState state) {
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
    final state = context.watch<DeathFormCubit>().state;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit(context));
      },
      child: BlocListener<DeathFormCubit, DeathFormState>(
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
                          unawaited(context.read<DeathFormCubit>().load()),
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
    final cubit = context.read<DeathFormCubit>();
    final state = context.watch<DeathFormCubit>().state;
    final step = state.step;
    final review = step == DeathStep.review;
    final submitting = state.submitStatus == SubmitStatus.submitting;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          AppFormHeader(
            title: l10n.moduleDeathRegistration,
            startedOn: state.draft!.startedOn,
            step: step.number,
            stepCount: DeathStep.count,
            stepOf: l10n.brStepOf(step.number, DeathStep.count),
            stepName: step.title(l10n),
          ),
          if (state.draft!.queried?.queryReason case final reason?)
            _QueryBanner(reason: reason),
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
                  DeathStep.deceased => const _DeceasedStep(),
                  DeathStep.informant => const _InformantStep(),
                  DeathStep.documents => const _DocumentsStep(),
                  DeathStep.review => const _ReviewStep(),
                },
              ],
            ),
          ),
          // The design's buttons: "Next" then "Back" on the form steps;
          // Previous/Next and "Exit Application" on the documents.
          if (step == DeathStep.documents)
            AppFormActions(
              primaryLabel: l10n.brNext,
              primaryMuted: !state.isStepComplete(cubit.today),
              onPrimary: cubit.next,
              previousLabel: l10n.brPrevious,
              onPrevious: cubit.previous,
              exitLabel: l10n.brExitApplication,
              onExit: onExit,
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (submitting) ...[
                    LinearProgressIndicator(
                      value: state.progress,
                      semanticsLabel: l10n.brSubmitting,
                    ),
                    const SizedBox(height: Spacing.sm),
                  ],
                  // Grey until the step can go on; a tap before then shows
                  // what's missing.
                  AppButton(
                    label: review ? l10n.brSubmit : l10n.brNext,
                    muted: review
                        ? !state.canSubmit(cubit.today)
                        : !state.isStepComplete(cubit.today),
                    isLoading: submitting,
                    onPressed: review
                        ? () => unawaited(cubit.submit())
                        : cubit.next,
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppPalette.inkStrong,
                    ),
                    onPressed: submitting
                        ? null
                        : step == DeathStep.deceased
                        ? onExit
                        : cubit.previous,
                    child: Text(l10n.back),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The registrar's reason, in red as the designs mark what to correct.
class _QueryBanner extends StatelessWidget {
  const _QueryBanner({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: error.withValues(alpha: 0.08),
          border: Border.all(color: error),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm + Spacing.xs),
          child: Text(
            context.l10n.baQueriedBanner(reason),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: error),
          ),
        ),
      ),
    );
  }
}

extension on DeathStep {
  String title(AppLocalizations l10n) => switch (this) {
    DeathStep.deceased => l10n.sbStepDeceased,
    DeathStep.informant => l10n.brStepInformant,
    DeathStep.documents => l10n.brStepDocuments,
    DeathStep.review => l10n.brReviewTitle,
  };
}
