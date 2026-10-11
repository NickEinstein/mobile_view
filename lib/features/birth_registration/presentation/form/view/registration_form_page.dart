import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_date_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_dialog.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_radio_group.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_signature_pad.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/person_fields.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/form/cubit/registration_form_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/shared/application_sections.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/shared/query_reason_card.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'child_step.dart';
part 'declaration.dart';
part 'documents_step.dart';
part 'face_capture_field.dart';
part 'form_actions.dart';
part 'informant_step.dart';
part 'parent_step.dart';
part 'review_step.dart';
part 'step_fields.dart';
part 'step_header.dart';
part 'submitted_dialog.dart';

/// The Birth Registration form. [onPayment] opens the payment for the fee.
class RegistrationFormPage extends StatelessWidget {
  const RegistrationFormPage({
    required this.onExit,
    required this.onPayment,
    this.registrarLocation,
    this.queriedRecordId,
    this.outboxId,
    this.offline = false,
    super.key,
  });

  final VoidCallback onExit;
  final Future<void> Function() onPayment;

  /// The signed-in registrar's state and LGA (from the router).
  final RegistrarLocation? registrarLocation;

  /// Corrects this queried record instead of starting an application.
  final String? queriedRecordId;

  /// Edits this application saved offline instead.
  final String? outboxId;

  /// Offline mode is on.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RegistrationFormCubit(
        GetIt.instance<BirthRegistrationRepository>(),
        registrarLocation: registrarLocation,
        queriedRecordId: queriedRecordId,
        outboxId: outboxId,
        offline: offline,
      )..load().ignore(),
      child: RegistrationFormView(onExit: onExit, onPayment: onPayment),
    );
  }
}

class RegistrationFormView extends StatelessWidget {
  const RegistrationFormView({
    required this.onExit,
    required this.onPayment,
    super.key,
  });

  final VoidCallback onExit;
  final Future<void> Function() onPayment;

  Future<void> _takePayment(BuildContext context) async {
    final cubit = context.read<RegistrationFormCubit>();
    await onPayment();
    await cubit.paymentClosed();
  }

  /// "Exit Application?" — progress is saved either way.
  Future<void> _confirmExit(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<RegistrationFormCubit>();
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
            cubit.state.draft?.queried == null
                ? l10n.brExitMessage
                : l10n.brExitCorrectionMessage,
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

  Future<void> _submitted(
    BuildContext context,
    RegistrationFormState state,
  ) async {
    final correction = state.draft?.queried != null;
    await _showSubmittedDialog(
      context,
      trackingId: state.trackingId,
      remindNin: !correction && state.draft?.childHasNin == false,
      correction: correction,
    );
    onExit();
  }

  Future<void> _savedForLater(BuildContext context) async {
    await _showSavedForLaterDialog(context);
    onExit();
  }

  void _onSubmitStatus(BuildContext context, RegistrationFormState state) {
    switch (state.submitStatus) {
      case SubmitStatus.submitted:
        unawaited(_submitted(context, state));
      case SubmitStatus.savedForLater:
        unawaited(_savedForLater(context));
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
    final state = context.watch<RegistrationFormCubit>().state;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit(context));
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<RegistrationFormCubit, RegistrationFormState>(
            listenWhen: (previous, current) =>
                previous.submitStatus != current.submitStatus,
            listener: _onSubmitStatus,
          ),
          BlocListener<RegistrationFormCubit, RegistrationFormState>(
            listenWhen: (previous, current) =>
                !previous.askForPayment && current.askForPayment,
            listener: (context, _) => unawaited(_takePayment(context)),
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
                      onPressed: () => unawaited(
                        context.read<RegistrationFormCubit>().load(),
                      ),
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

/// The registrar's reason for the query, above every step of a
/// correction.
class _QueryReasonBanner extends StatelessWidget {
  const _QueryReasonBanner({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
      child: QueryReasonCard(reason: reason),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegistrationFormCubit>().state;
    final step = state.step;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          _StepHeader(step: step, startedOn: state.draft!.startedOn),
          if (state.draft!.queried case QueriedRecord(:final reason?))
            _QueryReasonBanner(reason: reason),
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
                  RegistrationStep.child => const _ChildStep(),
                  RegistrationStep.mother => const _ParentStep(
                    role: ParentRole.mother,
                  ),
                  RegistrationStep.father => const _ParentStep(
                    role: ParentRole.father,
                  ),
                  RegistrationStep.informant => const _InformantStep(),
                  RegistrationStep.documents => const _DocumentsStep(),
                  RegistrationStep.review => const _ReviewStep(),
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
