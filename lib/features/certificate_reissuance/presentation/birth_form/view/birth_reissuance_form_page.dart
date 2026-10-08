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
import 'package:vital_reg_mobile/design_system/widgets/app_radio_group.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_signature_pad.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_form_layout.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_upload_tile.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/birth_form/cubit/birth_reissuance_form_cubit.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/birth_reissuance_sections.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/email_code.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/form_fields.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/pick_photo.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'child_step.dart';
part 'documents_step.dart';
part 'parent_step.dart';
part 'review_step.dart';

/// The birth certificate's reissuance form.
class BirthReissuanceFormPage extends StatelessWidget {
  const BirthReissuanceFormPage({
    required this.onExit,
    this.queriedId,
    this.repository,
    super.key,
  });

  final VoidCallback onExit;

  /// Corrects this queried request instead of the one in progress.
  final String? queriedId;

  /// Defaults to the registered one; tests pass a fake.
  final ReissuanceRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repository =
        this.repository ?? GetIt.instance<ReissuanceRepository>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              BirthReissuanceFormCubit(repository, queriedId: queriedId)
                ..load().ignore(),
        ),
        // The recipient's email, confirmed on the preview.
        BlocProvider(create: (_) => EmailCodeCubit(repository)),
      ],
      child: BirthReissuanceFormView(onExit: onExit),
    );
  }
}

class BirthReissuanceFormView extends StatelessWidget {
  const BirthReissuanceFormView({
    required this.onExit,
    this.pickPhoto = pickPhotoFromDevice,
    super.key,
  });

  final VoidCallback onExit;
  final PickPhoto pickPhoto;

  /// "Application Successfully Submitted", then back home.
  Future<void> _submitted(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return PopScope(
          canPop: false,
          child: AppStatusDialog(
            title: l10n.brSubmittedTitle,
            message: l10n.crSubmittedMessage,
            actionLabel: l10n.crClose,
            onAction: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
    onExit();
  }

  void _onChange(BuildContext context, BirthReissuanceFormState state) {
    switch (state.submitStatus) {
      case SubmitStatus.submitted:
        unawaited(_submitted(context));
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

  /// "Exit Application?" — progress is saved either way.
  Future<void> _confirmExit(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<BirthReissuanceFormCubit>();
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<BirthReissuanceFormCubit>().state;

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
        if (!didPop && state.submitStatus != SubmitStatus.submitting) {
          unawaited(_confirmExit(context));
        }
      },
      child: BlocListener<BirthReissuanceFormCubit, BirthReissuanceFormState>(
        listenWhen: (previous, current) =>
            previous.submitStatus != current.submitStatus,
        listener: _onChange,
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
            FormStatus.missing => message(l10n.crNoApplication),
            FormStatus.failure => message(
              state.failure?.localize(l10n) ?? l10n.brLoadFailed,
              onRetry: () =>
                  unawaited(context.read<BirthReissuanceFormCubit>().load()),
            ),
            FormStatus.ready => _FormBody(
              pickPhoto: pickPhoto,
              onExit: () => unawaited(_confirmExit(context)),
            ),
          },
        ),
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({required this.pickPhoto, required this.onExit});

  final PickPhoto pickPhoto;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BirthReissuanceFormCubit>();
    final state = context.watch<BirthReissuanceFormCubit>().state;
    final step = state.step;
    final first = step == BirthReissuanceStep.child;
    final review = step == BirthReissuanceStep.review;
    final submitting = state.submitStatus == SubmitStatus.submitting;
    final email = context.watch<EmailCodeCubit>().state.verifiedEmail;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          AppFormHeader(
            title: l10n.crTitle,
            startedOn: state.startedOn,
            step: step.number,
            stepCount: BirthReissuanceStep.count,
            stepOf: l10n.brStepOf(step.number, BirthReissuanceStep.count),
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
                  BirthReissuanceStep.child => const _ChildStep(),
                  BirthReissuanceStep.mother => const _ParentStep(
                    role: ParentRole.mother,
                  ),
                  BirthReissuanceStep.father => const _ParentStep(
                    role: ParentRole.father,
                  ),
                  BirthReissuanceStep.documents => _DocumentsStep(
                    pickPhoto: pickPhoto,
                  ),
                  BirthReissuanceStep.review => const _ReviewStep(),
                },
              ],
            ),
          ),
          // Grey until the step can go on; a tap before then shows what's
          // missing.
          AppFormActions(
            primaryLabel: review
                ? l10n.brSubmit
                : first
                ? l10n.crSaveAndContinue
                : l10n.brNext,
            primaryMuted: review
                ? !state.canSubmit || email == null
                : !state.isStepComplete,
            isLoading: submitting,
            progressLabel: l10n.brSubmitting,
            onPrimary: review
                ? () => unawaited(cubit.submit(email: email))
                : cubit.next,
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

extension on BirthReissuanceStep {
  String title(AppLocalizations l10n) => switch (this) {
    BirthReissuanceStep.child => l10n.brStepChild,
    BirthReissuanceStep.mother => l10n.brStepMother,
    BirthReissuanceStep.father => l10n.brStepFather,
    BirthReissuanceStep.documents => l10n.crStepDocuments,
    BirthReissuanceStep.review => l10n.brReviewTitle,
  };
}
