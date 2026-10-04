import 'dart:async';

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
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_documents.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/record_edit.dart';
import 'package:vital_reg_mobile/features/modifications/domain/modifications_repository.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/form/cubit/modification_form_cubit.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/shared/modification_labels.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'modification_documents_step.dart';
part 'modification_form_fields.dart';

/// The record's form with only [request]'s change editable.
class ModificationFormPage extends StatelessWidget {
  const ModificationFormPage({
    required this.request,
    required this.record,
    required this.onDone,
    required this.onExit,
    super.key,
  });

  final ModificationRequest request;
  final ModificationRecord record;
  final VoidCallback onDone;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ModificationFormCubit(
        GetIt.instance<ModificationsRepository>(),
        request: request,
        record: record,
      )..load().ignore(),
      child: ModificationFormView(onDone: onDone, onExit: onExit),
    );
  }
}

class ModificationFormView extends StatelessWidget {
  const ModificationFormView({
    required this.onDone,
    required this.onExit,
    super.key,
  });

  final VoidCallback onDone;
  final VoidCallback onExit;

  Future<void> _submitted(BuildContext context) async {
    await _showSubmittedDialog(
      context,
      queried: context.read<ModificationFormCubit>().isQueried,
    );
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ModificationFormCubit>();
    final step = context.select(
      (ModificationFormCubit cubit) => cubit.state.step,
    );
    final onDocuments = step == ModificationFormStep.documents;

    return BlocListener<ModificationFormCubit, ModificationFormState>(
      listenWhen: (previous, current) =>
          current.submitted && !previous.submitted,
      listener: (context, state) => unawaited(_submitted(context)),
      child: PopScope(
        // Back from the documents returns to the form.
        canPop: !onDocuments,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && onDocuments) cubit.backToForm();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          body: onDocuments
              ? _DocumentsStep(onExit: onExit)
              : const _FormStep(),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(Spacing.md),
            child: onDocuments
                ? _DocumentsActions(onExit: onExit)
                : const _FormActions(),
          ),
        ),
      ),
    );
  }
}

class _FormStep extends StatelessWidget {
  const _FormStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<ModificationFormCubit>();
    final state = context.watch<ModificationFormCubit>().state;
    final request = cubit.request;
    final optionsFailure = state.optionsFailure;
    final unchanged =
        state.showErrors && !cubit.isQueried && !state.edit.isChanged;
    final queried = cubit.queried;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.lg),
      children: [
        Text(
          request.kind.title(l10n),
          style: textTheme.titleLarge?.copyWith(
            color: AppPalette.inkStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          DateFormat.yMMMMd(
            Localizations.localeOf(context).toString(),
          ).format(cubit.today),
          style: textTheme.bodySmall?.copyWith(color: AppPalette.muted),
        ),
        const SizedBox(height: Spacing.md),
        if (queried != null) ...[
          _QueryBanner(
            type: request.type?.label(l10n) ?? '',
            reason: queried.queryReason,
          ),
          const SizedBox(height: Spacing.sm),
        ],
        _OnlyBanner(request: request),
        if (unchanged) _ErrorText(l10n.modUnchanged),
        if (optionsFailure != null)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm),
            child: Row(
              children: [
                Expanded(child: _ErrorText(l10n.modOptionsFailed)),
                TextButton(
                  onPressed: () => unawaited(cubit.load()),
                  child: Text(l10n.tryAgain),
                ),
              ],
            ),
          ),
        const SizedBox(height: Spacing.lg),
        const _RecordFields(),
        const SizedBox(height: Spacing.lg),
        _Declaration(
          declared: state.declared,
          showError: state.showErrors && !state.declared,
          onChanged: cubit.declaredChanged,
        ),
        ..._submitMessages(context, state),
      ],
    );
  }
}

class _FormActions extends StatelessWidget {
  const _FormActions();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ModificationFormCubit>();
    final state = context.watch<ModificationFormCubit>().state;
    return AppButton(
      label: context.l10n.modModify,
      isLoading: state.isSubmitting,
      // Greyed until declared, as in the designs.
      onPressed: state.declared ? () => unawaited(cubit.modify()) : null,
    );
  }
}

/// Why sending failed, under the form or the documents.
List<Widget> _submitMessages(
  BuildContext context,
  ModificationFormState state,
) {
  final l10n = context.l10n;
  final message = state.paymentMissing
      ? l10n.modPaymentMissing
      : state.failure?.localize(l10n);
  return [
    if (message != null) ...[
      const SizedBox(height: Spacing.md),
      _ErrorText(message),
    ],
  ];
}

/// The red "Only … can be modified." banner.
class _OnlyBanner extends StatelessWidget {
  const _OnlyBanner({required this.request});

  final ModificationRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = switch ((request.type, request.field)) {
      (_, ModificationField.childName) => l10n.modOnlyChildName,
      (_, ModificationField.childDateOfBirth) => l10n.modOnlyChildDateOfBirth,
      (_, ModificationField.childSex) => l10n.modOnlyChildSex,
      (_, ModificationField.childPlaceOfBirth) => l10n.modOnlyChildPlaceOfBirth,
      (_, ModificationField.applicantName) => l10n.modOnlyApplicantName,
      (_, ModificationField.applicantSex) => l10n.modOnlyApplicantSex,
      (_, ModificationField.applicantDateOfBirth) =>
        l10n.modOnlyApplicantDateOfBirth,
      (_, ModificationField.applicantPlaceOfBirth) =>
        l10n.modOnlyApplicantPlaceOfBirth,
      (_, ModificationField.applicantStateOfOrigin) =>
        l10n.modOnlyApplicantStateOfOrigin,
      (
        ModificationType.motherName || ModificationType.applicantMotherName,
        _,
      ) =>
        l10n.modOnlyMotherName,
      (ModificationType.fatherName, _) => l10n.modOnlyFatherName,
      (ModificationType.applicantFatherName, _) =>
        l10n.modOnlyAttestationFatherName,
      (ModificationType.deceasedName, _) => l10n.modOnlyDeceasedName,
      (ModificationType.deceasedSex, _) => l10n.modOnlyDeceasedSex,
      (ModificationType.deceasedAgeAtDeath, _) =>
        l10n.modOnlyDeceasedAgeAtDeath,
      (ModificationType.deceasedDateOfDeath, _) =>
        l10n.modOnlyDeceasedDateOfDeath,
      _ => null,
    };
    if (text == null) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.danger.withValues(alpha: 0.08),
        border: Border.all(color: AppPalette.danger),
        borderRadius: BorderRadius.circular(Spacing.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.sm,
        ),
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.danger),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Spacing.xs),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}

/// "I hereby certify…".
class _Declaration extends StatelessWidget {
  const _Declaration({
    required this.declared,
    required this.showError,
    required this.onChanged,
  });

  final bool declared;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppPalette.warningContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: showError
                  ? theme.colorScheme.error
                  : AppPalette.accentYellow,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(!declared),
            child: MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: declared,
                      visualDensity: VisualDensity.compact,
                      onChanged: (value) => onChanged(value ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: Spacing.sm),
                        child: Text(
                          l10n.brDeclaration,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppPalette.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Queried Record": the request type and the reviewer's reason.
class _QueryBanner extends StatelessWidget {
  const _QueryBanner({required this.type, required this.reason});

  final String type;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.warningContainer,
        border: Border.all(color: AppPalette.accentYellow),
        borderRadius: BorderRadius.circular(Spacing.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sm + Spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.modQueriedTitle,
              style: textTheme.titleSmall?.copyWith(
                color: AppPalette.onWarningContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (type.isNotEmpty)
              Text(
                type,
                style: textTheme.bodySmall?.copyWith(
                  color: AppPalette.onWarningContainer,
                ),
              ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: Spacing.xs),
              Text(
                l10n.modQueryReason(reason),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppPalette.inkStrong,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Modification Request Submitted" (or, for a queried request,
/// "Correction Submitted"). Completes when the user taps Ok.
Future<void> _showSubmittedDialog(
  BuildContext context, {
  required bool queried,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) {
    final l10n = dialogContext.l10n;
    final textTheme = Theme.of(dialogContext).textTheme;
    return PopScope(
      canPop: false,
      child: AppDialog(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppPalette.brand,
            size: 48,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            queried ? l10n.modResubmittedTitle : l10n.modSubmittedTitle,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              color: AppPalette.brand,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            queried ? l10n.modResubmittedMessage : l10n.modSubmittedMessage,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppPalette.ink),
          ),
          const SizedBox(height: Spacing.lg),
          AppButton(
            label: l10n.brOk,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  },
);
