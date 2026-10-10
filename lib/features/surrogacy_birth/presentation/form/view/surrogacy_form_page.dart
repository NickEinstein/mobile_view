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
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart'
    show RegistrarLocation;
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_form.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/surrogacy_birth_repository.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/form/cubit/surrogacy_form_cubit.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/shared/surrogacy_sections.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'child_step.dart';
part 'documents_step.dart';
part 'face_field.dart';
part 'form_fields.dart';
part 'informant_step.dart';
part 'nin_field.dart';
part 'parent_step.dart';
part 'review_step.dart';
part 'submitted_dialog.dart';
part 'surrogacy_step.dart';
part 'surrogate_mother_step.dart';

/// The eight-step Surrogacy Birth Registration form. [onExit] (from the
/// router) leaves it; progress is already saved.
class SurrogacyFormPage extends StatelessWidget {
  const SurrogacyFormPage({
    required this.onExit,
    this.registrarLocation,
    this.queriedId,
    this.repository,
    super.key,
  });

  final VoidCallback onExit;

  /// Corrects this queried application instead of the one on the device.
  final String? queriedId;

  /// The signed-in registrar's state and LGA (from the router), which the
  /// registration state and LGA are fixed to.
  final RegistrarLocation? registrarLocation;

  /// Defaults to the registered one; tests pass a fake.
  final SurrogacyBirthRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SurrogacyFormCubit(
        repository ?? GetIt.instance<SurrogacyBirthRepository>(),
        queriedId: queriedId,
        registrarLocation: registrarLocation,
      )..load().ignore(),
      child: SurrogacyFormView(onExit: onExit),
    );
  }
}

class SurrogacyFormView extends StatelessWidget {
  const SurrogacyFormView({required this.onExit, super.key});

  final VoidCallback onExit;

  /// "Exit Application?" — progress is saved either way.
  Future<void> _confirmExit(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<SurrogacyFormCubit>();
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
            cubit.isQueried ? l10n.srExitCorrectionMessage : l10n.brExitMessage,
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
    final state = context.watch<SurrogacyFormCubit>().state;

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
          BlocListener<SurrogacyFormCubit, SurrogacyFormState>(
            listenWhen: (previous, current) =>
                current.saveFailure != null &&
                previous.saveFailure != current.saveFailure,
            listener: (context, state) =>
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.saveFailure!.localize(l10n))),
                ),
          ),
          BlocListener<SurrogacyFormCubit, SurrogacyFormState>(
            listenWhen: (previous, current) =>
                previous.submitStatus != SubmitStatus.submitted &&
                current.submitStatus == SubmitStatus.submitted,
            listener: (context, state) async {
              await _showSubmittedDialog(
                context,
                trackingId: state.trackingId!,
                corrected: context.read<SurrogacyFormCubit>().isQueried,
              );
              onExit();
            },
          ),
          BlocListener<SurrogacyFormCubit, SurrogacyFormState>(
            listenWhen: (previous, current) =>
                current.ninValidations > previous.ninValidations,
            listener: (context, _) => unawaited(
              showDialog<void>(
                context: context,
                builder: (dialogContext) => AppStatusDialog(
                  title: l10n.srNinValidated,
                  message: l10n.srNinValidatedMessage,
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
                  unawaited(context.read<SurrogacyFormCubit>().load()),
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
    final cubit = context.read<SurrogacyFormCubit>();
    final state = context.watch<SurrogacyFormCubit>().state;
    final step = state.step;
    final first = step == SurrogacyStep.child;
    final review = step == SurrogacyStep.review;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          AppFormHeader(
            title: l10n.moduleSurrogacyBirthRegistration,
            startedOn: state.draft!.startedOn,
            step: step.number,
            stepCount: SurrogacyStep.count,
            stepOf: l10n.brStepOf(step.number, SurrogacyStep.count),
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
                  SurrogacyStep.child => const _ChildStep(),
                  SurrogacyStep.surrogacy => const _SurrogacyStep(),
                  SurrogacyStep.legalMother => const _LegalParentStep(
                    SurrogacyPerson.legalMother,
                  ),
                  SurrogacyStep.legalFather => const _LegalParentStep(
                    SurrogacyPerson.legalFather,
                  ),
                  SurrogacyStep.surrogateMother => const _SurrogateMotherStep(),
                  SurrogacyStep.informant => const _InformantStep(),
                  SurrogacyStep.documents => const _DocumentsStep(),
                  SurrogacyStep.review => const _ReviewStep(),
                },
              ],
            ),
          ),
          // Grey until the step can go on; a tap before then shows what's
          // missing.
          AppFormActions(
            primaryLabel: switch (step) {
              SurrogacyStep.child => l10n.brSaveContinue,
              SurrogacyStep.review => l10n.brSubmit,
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

extension on SurrogacyStep {
  String title(AppLocalizations l10n) => switch (this) {
    SurrogacyStep.child => l10n.brStepChild,
    SurrogacyStep.surrogacy => l10n.srStepSurrogacy,
    SurrogacyStep.legalMother ||
    SurrogacyStep.legalFather ||
    SurrogacyStep.surrogateMother => l10n.srStepLegalParents,
    SurrogacyStep.informant => l10n.brStepInformant,
    SurrogacyStep.documents => l10n.brStepDocuments,
    SurrogacyStep.review => l10n.brStepReview,
  };
}
