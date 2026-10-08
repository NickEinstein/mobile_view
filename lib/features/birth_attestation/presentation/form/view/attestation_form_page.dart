import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_date_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_dialog.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_form_layout.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_upload_tile.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/form/cubit/attestation_form_cubit.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/shared/attestation_sections.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'additional_step.dart';
part 'applicant_step.dart';
part 'document_tile.dart';
part 'form_fields.dart';
part 'parents_step.dart';
part 'review_step.dart';
part 'submitted_dialog.dart';

/// The Birth Attestation form; with [queriedRecordId], a correction.
class AttestationFormPage extends StatelessWidget {
  const AttestationFormPage({
    required this.onExit,
    this.queriedRecordId,
    super.key,
  });

  final VoidCallback onExit;
  final String? queriedRecordId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AttestationFormCubit(
        GetIt.instance<BirthAttestationRepository>(),
        queriedRecordId: queriedRecordId,
      )..load().ignore(),
      child: AttestationFormView(onExit: onExit),
    );
  }
}

class AttestationFormView extends StatelessWidget {
  const AttestationFormView({required this.onExit, super.key});

  final VoidCallback onExit;

  /// "Exit Application?" — progress is saved either way.
  Future<void> _confirmExit(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<AttestationFormCubit>();
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
    AttestationFormState state,
  ) async {
    await _showSubmittedDialog(
      context,
      trackingId: state.trackingId ?? '',
      correction: state.isCorrection,
      remindNin: state.ninRecord == null && !state.isCorrection,
    );
    onExit();
  }

  void _onSubmitStatus(BuildContext context, AttestationFormState state) {
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
    final state = context.watch<AttestationFormCubit>().state;

    Widget message(String text, {VoidCallback? onRetry}) => Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit(context));
      },
      child: BlocListener<AttestationFormCubit, AttestationFormState>(
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
            FormStatus.failure => message(
              state.failure?.localize(l10n) ?? l10n.brLoadFailed,
              onRetry: () =>
                  unawaited(context.read<AttestationFormCubit>().load()),
            ),
            FormStatus.missingPayment => message(l10n.baMissingPayment),
            FormStatus.missingIdentity => message(l10n.baMissingIdentity),
            FormStatus.ready when state.draft != null => _FormBody(
              onExit: () => unawaited(_confirmExit(context)),
            ),
            FormStatus.ready => const Center(
              child: CircularProgressIndicator(),
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
    final cubit = context.read<AttestationFormCubit>();
    final state = context.watch<AttestationFormCubit>().state;
    final step = state.step;
    final submitting = state.submitStatus == SubmitStatus.submitting;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          AppFormHeader(
            title: l10n.moduleBirthAttestation,
            startedOn: state.draft!.startedOn,
            step: step.number,
            stepCount: AttestationStep.count,
            stepOf: l10n.brStepOf(step.number, AttestationStep.count),
            stepName: step.title(l10n),
          ),
          if (state.queryReason case final reason?)
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
                  AttestationStep.applicant => const _ApplicantStep(),
                  AttestationStep.additional => const _AdditionalStep(),
                  AttestationStep.parents => const _ParentsStep(),
                  AttestationStep.review => const _ReviewStep(),
                },
              ],
            ),
          ),
          // Grey until the step can go on; a tap before then shows what's
          // missing.
          AppFormActions(
            primaryLabel: switch (step) {
              AttestationStep.applicant => l10n.brSaveContinue,
              AttestationStep.review => l10n.brSubmit,
              _ => l10n.brNext,
            },
            primaryMuted: step == AttestationStep.review
                ? !state.canSubmit(cubit.today)
                : !state.isStepComplete(cubit.today),
            isLoading: submitting,
            onPrimary: step == AttestationStep.review
                ? () => unawaited(cubit.submit())
                : cubit.next,
            previousLabel: step == AttestationStep.applicant
                ? null
                : l10n.brPrevious,
            onPrevious: cubit.previous,
            exitLabel: l10n.brExitApplication,
            onExit: onExit,
            progress: state.progress,
            progressLabel: l10n.brSubmitting,
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

extension on AttestationStep {
  String title(AppLocalizations l10n) => switch (this) {
    AttestationStep.applicant => l10n.baStepApplicant,
    AttestationStep.additional => l10n.baStepAdditional,
    AttestationStep.parents => l10n.baStepParents,
    AttestationStep.review => l10n.brReviewTitle,
  };
}
