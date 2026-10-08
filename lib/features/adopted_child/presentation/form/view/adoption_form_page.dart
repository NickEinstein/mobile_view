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
import 'package:vital_reg_mobile/design_system/widgets/form/app_review.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_upload_tile.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/adopted_child_repository.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_form.dart';
import 'package:vital_reg_mobile/features/adopted_child/presentation/form/cubit/adoption_form_cubit.dart';
import 'package:vital_reg_mobile/features/adopted_child/presentation/shared/adoption_sections.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'adopter_step.dart';
part 'adoption_details_step.dart';
part 'child_step.dart';
part 'documents_step.dart';
part 'face_field.dart';
part 'form_fields.dart';
part 'informant_step.dart';
part 'nin_field.dart';
part 'review_step.dart';
part 'submitted_dialog.dart';

/// The seven-step Adopted Child Registration form. [onExit] (from the
/// router) leaves it; progress is already saved.
class AdoptionFormPage extends StatelessWidget {
  const AdoptionFormPage({
    required this.onExit,
    this.queriedId,
    this.repository,
    super.key,
  });

  final VoidCallback onExit;

  /// Corrects this queried application instead of the one on the device.
  final String? queriedId;

  /// Defaults to the registered one; tests pass a fake.
  final AdoptedChildRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdoptionFormCubit(
        repository ?? GetIt.instance<AdoptedChildRepository>(),
        queriedId: queriedId,
      )..load().ignore(),
      child: AdoptionFormView(onExit: onExit),
    );
  }
}

class AdoptionFormView extends StatelessWidget {
  const AdoptionFormView({required this.onExit, super.key});

  final VoidCallback onExit;

  /// "Exit Application?" — progress is saved either way.
  Future<void> _confirmExit(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<AdoptionFormCubit>();
    if (cubit.state.status != FormStatus.ready) {
      onExit();
      return;
    }
    if (cubit.state.isSaving) return;
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
          Text(
            cubit.isQueried ? l10n.acExitCorrectionMessage : l10n.brExitMessage,
            textAlign: TextAlign.center,
          ),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AdoptionFormCubit>().state;

    Widget message(String text, {VoidCallback? onRetry}) => Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            TextButton(
              onPressed: onRetry ?? onExit,
              child: Text(onRetry == null ? l10n.back : l10n.tryAgain),
            ),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit(context));
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<AdoptionFormCubit, AdoptionFormState>(
            listenWhen: (previous, current) =>
                previous.submitStatus != SubmitStatus.submitted &&
                current.submitStatus == SubmitStatus.submitted,
            listener: (context, state) async {
              await _showSubmittedDialog(
                context,
                trackingId: state.trackingId!,
                corrected: context.read<AdoptionFormCubit>().isQueried,
              );
              onExit();
            },
          ),
          BlocListener<AdoptionFormCubit, AdoptionFormState>(
            listenWhen: (previous, current) =>
                current.saveFailure != null &&
                previous.saveFailure != current.saveFailure,
            listener: (context, state) =>
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.saveFailure!.localize(l10n))),
                ),
          ),
          BlocListener<AdoptionFormCubit, AdoptionFormState>(
            listenWhen: (previous, current) =>
                current.ninValidations > previous.ninValidations,
            listener: (context, _) => unawaited(
              showDialog<void>(
                context: context,
                builder: (dialogContext) => AppStatusDialog(
                  title: l10n.srNinValidated,
                  message: l10n.acNinValidatedMessage,
                  actionLabel: l10n.brProceed,
                  onAction: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ),
          ),
        ],
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
                  unawaited(context.read<AdoptionFormCubit>().load()),
            ),
            FormStatus.notStarted => message(l10n.srNotStarted),
            FormStatus.notPaid => message(l10n.srNotPaid),
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
    final cubit = context.read<AdoptionFormCubit>();
    final state = context.watch<AdoptionFormCubit>().state;
    final step = state.step;
    final first = step == AdoptionStep.child;
    final review = step == AdoptionStep.review;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          AppFormHeader(
            title: l10n.moduleAdoptedChildRegistration,
            startedOn: state.draft!.startedOn,
            step: step.number,
            stepCount: AdoptionStep.count,
            stepOf: l10n.brStepOf(step.number, AdoptionStep.count),
            stepName: step.title(l10n),
          ),
          Expanded(
            child: ListView(
              key: ValueKey(step),
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.md,
                Spacing.md,
                Spacing.lg,
              ),
              children: [
                switch (step) {
                  AdoptionStep.child => const _ChildStep(),
                  AdoptionStep.adopter1 => const _AdopterStep(Adopter.first),
                  AdoptionStep.adopter2 => const _AdopterStep(Adopter.second),
                  AdoptionStep.adoptionDetails => const _AdoptionDetailsStep(),
                  AdoptionStep.informant => const _InformantStep(),
                  AdoptionStep.documents => const _DocumentsStep(),
                  AdoptionStep.review => const _ReviewStep(),
                },
              ],
            ),
          ),
          // Grey until the step can go on; a tap before then shows what's
          // missing.
          AppFormActions(
            primaryLabel: switch (step) {
              AdoptionStep.child => l10n.brSaveContinue,
              AdoptionStep.review => l10n.brSubmit,
              _ => l10n.brNext,
            },
            primaryMuted: review
                ? !state.canSubmit(cubit.today)
                : !state.isStepComplete(cubit.today),
            isLoading:
                state.isSaving || state.submitStatus == SubmitStatus.submitting,
            onPrimary: () => unawaited(review ? cubit.submit() : cubit.next()),
            previousLabel: first ? null : l10n.brPrevious,
            onPrevious: cubit.previous,
            exitLabel: l10n.brExitApplication,
            onExit: onExit,
          ),
        ],
      ),
    );
  }
}

extension on AdoptionStep {
  /// The step name the header shows, as the designs label them.
  String title(AppLocalizations l10n) => switch (this) {
    AdoptionStep.child => l10n.brStepChild,
    AdoptionStep.adopter1 || AdoptionStep.adopter2 => l10n.acStepAdopters,
    AdoptionStep.adoptionDetails => l10n.acStepAdoptionDetails,
    AdoptionStep.informant => l10n.brStepInformant,
    AdoptionStep.documents => l10n.brStepDocuments,
    AdoptionStep.review => l10n.brStepReview,
  };
}
