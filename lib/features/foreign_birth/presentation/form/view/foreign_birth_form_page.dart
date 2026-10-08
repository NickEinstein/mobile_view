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
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_form.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/foreign_birth_repository.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/form/cubit/foreign_birth_form_cubit.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/shared/foreign_birth_sections.dart';
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

/// The Foreign Birth Notification form. [onExit] (from the router) leaves
/// it; progress is already saved on the device.
class ForeignBirthFormPage extends StatelessWidget {
  const ForeignBirthFormPage({
    required this.onExit,
    this.queriedId,
    this.repository,
    super.key,
  });

  final VoidCallback onExit;

  /// Corrects this queried notification instead of the one on the device.
  final String? queriedId;

  /// Defaults to the registered one; tests pass a fake.
  final ForeignBirthRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ForeignBirthFormCubit(
        repository ?? GetIt.instance<ForeignBirthRepository>(),
        queriedId: queriedId,
      )..load().ignore(),
      child: ForeignBirthFormView(onExit: onExit),
    );
  }
}

class ForeignBirthFormView extends StatelessWidget {
  const ForeignBirthFormView({required this.onExit, super.key});

  final VoidCallback onExit;

  /// "Exit Application?" — progress is saved either way.
  Future<void> _confirmExit(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<ForeignBirthFormCubit>();
    if (cubit.state.status != FormStatus.ready) {
      onExit();
      return;
    }
    if (cubit.state.submitStatus == SubmitStatus.submitting) return;
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
    final state = context.watch<ForeignBirthFormCubit>().state;

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
          BlocListener<ForeignBirthFormCubit, ForeignBirthFormState>(
            listenWhen: (previous, current) =>
                previous.submitStatus != SubmitStatus.submitted &&
                current.submitStatus == SubmitStatus.submitted,
            listener: (context, state) async {
              await _showSubmittedDialog(
                context,
                trackingId: state.trackingId ?? '',
                corrected: context.read<ForeignBirthFormCubit>().isQueried,
              );
              onExit();
            },
          ),
          BlocListener<ForeignBirthFormCubit, ForeignBirthFormState>(
            listenWhen: (previous, current) =>
                current.submitFailure != null &&
                previous.submitFailure != current.submitFailure,
            listener: (context, state) =>
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.submitFailure!.localize(l10n))),
                ),
          ),
          BlocListener<ForeignBirthFormCubit, ForeignBirthFormState>(
            listenWhen: (previous, current) =>
                current.placesFailure != null &&
                previous.placesFailure != current.placesFailure,
            listener: (context, state) => ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.fbPlacesFailed))),
          ),
          BlocListener<ForeignBirthFormCubit, ForeignBirthFormState>(
            listenWhen: (previous, current) =>
                current.ninValidations > previous.ninValidations,
            listener: (context, _) => unawaited(
              showDialog<void>(
                context: context,
                builder: (dialogContext) => AppStatusDialog(
                  title: l10n.srNinValidated,
                  message: l10n.fbNinValidatedMessage,
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
                  unawaited(context.read<ForeignBirthFormCubit>().load()),
            ),
            FormStatus.notPaid => message(l10n.fbNotPaid),
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
    final cubit = context.read<ForeignBirthFormCubit>();
    final state = context.watch<ForeignBirthFormCubit>().state;
    final step = state.step;
    final review = step == ForeignBirthStep.review;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          AppFormHeader(
            title: l10n.moduleForeignBirthNotification,
            startedOn: state.draft!.startedOn,
            step: step.number,
            stepCount: ForeignBirthStep.count,
            stepOf: l10n.brStepOf(step.number, ForeignBirthStep.count),
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
                  ForeignBirthStep.child => const _ChildStep(),
                  ForeignBirthStep.mother => const _ParentStep(Parent.mother),
                  ForeignBirthStep.father => const _ParentStep(Parent.father),
                  ForeignBirthStep.informant => const _InformantStep(),
                  ForeignBirthStep.documents => const _DocumentsStep(),
                  ForeignBirthStep.review => const _ReviewStep(),
                },
              ],
            ),
          ),
          // Grey until the step can go on; a tap before then shows what's
          // missing.
          AppFormActions(
            primaryLabel: switch (step) {
              ForeignBirthStep.child => l10n.brSaveContinue,
              ForeignBirthStep.review => l10n.brSubmit,
              _ => l10n.brNext,
            },
            primaryMuted: review
                ? !state.canSubmit(cubit.today)
                : !state.isStepComplete(cubit.today),
            isLoading: state.submitStatus == SubmitStatus.submitting,
            onPrimary: review ? () => unawaited(cubit.submit()) : cubit.next,
            previousLabel: step == ForeignBirthStep.child
                ? null
                : l10n.brPrevious,
            onPrevious: cubit.previous,
            exitLabel: l10n.brExitApplication,
            onExit: onExit,
          ),
        ],
      ),
    );
  }
}

extension on ForeignBirthStep {
  /// The step name the header shows, as the designs label them.
  String title(AppLocalizations l10n) => switch (this) {
    ForeignBirthStep.child => l10n.brStepChild,
    ForeignBirthStep.mother => l10n.brStepMother,
    ForeignBirthStep.father => l10n.brStepFather,
    ForeignBirthStep.informant => l10n.brStepInformant,
    ForeignBirthStep.documents => l10n.brStepDocuments,
    ForeignBirthStep.review => l10n.brStepReview,
  };
}
