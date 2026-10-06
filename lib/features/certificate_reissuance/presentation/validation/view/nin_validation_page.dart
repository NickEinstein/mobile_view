import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_dialog.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/reissuance_labels.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/validation/cubit/nin_validation_cubit.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "Certificate Reissuance": mode of validation and NIN, after payment.
/// [onDone] (from the router) moves on to the face.
class NinValidationPage extends StatelessWidget {
  const NinValidationPage({required this.onDone, this.repository, super.key});

  final VoidCallback onDone;

  /// Defaults to the registered one; tests pass a fake.
  final ReissuanceRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NinValidationCubit(
        repository ?? GetIt.instance<ReissuanceRepository>(),
      ),
      child: NinValidationView(onDone: onDone),
    );
  }
}

class NinValidationView extends StatelessWidget {
  const NinValidationView({required this.onDone, super.key});

  final VoidCallback onDone;

  Future<void> _showDetails(
    BuildContext context,
    ApplicantNinRecord record,
  ) async {
    final cubit = context.read<NinValidationCubit>();
    final matchFace = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NinDetailsDialog(record: record),
    );
    if (matchFace ?? false) {
      await cubit.confirmed();
    } else {
      cubit.detailsDismissed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<NinValidationCubit>().state;
    final cubit = context.read<NinValidationCubit>();
    final error = state.notFound
        ? l10n.baNinNotFound
        : state.failure?.localize(l10n);

    return MultiBlocListener(
      listeners: [
        BlocListener<NinValidationCubit, NinValidationState>(
          listenWhen: (previous, current) =>
              previous.record == null && current.record != null,
          listener: (context, state) =>
              unawaited(_showDetails(context, state.record!)),
        ),
        BlocListener<NinValidationCubit, NinValidationState>(
          listenWhen: (previous, current) => !previous.isDone && current.isDone,
          listener: (_, _) => onDone(),
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Padding(
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
                  l10n.crTitle,
                  style: textTheme.titleLarge?.copyWith(
                    color: AppPalette.inkStrong,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                Expanded(
                  child: ListView(
                    children: [
                      AppSelectField<ValidationMode>(
                        label: l10n.crModeLabel,
                        hint: l10n.brSelectOption,
                        items: {
                          for (final mode in ValidationMode.values)
                            mode: mode.label(l10n),
                        },
                        value: state.mode,
                        onChanged: state.isChecking ? null : cubit.modeChanged,
                      ),
                      const SizedBox(height: Spacing.md),
                      AppTextField(
                        // A new mode clears the NIN, so rebuild the field.
                        key: ValueKey(state.mode),
                        label: l10n.crNinLabel,
                        hintText: l10n.brNinHint,
                        enabled: state.mode != null && !state.isChecking,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        onChanged: cubit.ninChanged,
                        onSubmitted: (_) => unawaited(cubit.validate()),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: Spacing.md),
                        Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AppButton(
                  label: l10n.brValidate,
                  isLoading: state.isChecking,
                  onPressed: state.canValidate ? cubit.validate : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "NIN Details": who the NIN belongs to, before the face match. Pops
/// true for "Face Match", false for "Cancel".
class NinDetailsDialog extends StatelessWidget {
  const NinDetailsDialog({required this.record, super.key});

  final ApplicantNinRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    Widget detail(String label, String? value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            color: AppPalette.inkStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value ?? '–',
          style: textTheme.bodySmall?.copyWith(color: AppPalette.ink),
        ),
      ],
    );
    Widget row(Widget left, Widget right) => Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: Spacing.sm),
          Expanded(child: right),
        ],
      ),
    );

    return AppDialog(
      children: [
        Text(
          l10n.crNinDetailsTitle,
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(
            color: AppPalette.inkStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Spacing.md),
        row(
          detail(l10n.brSurname, record.surname),
          detail(l10n.brFirstName, record.firstName),
        ),
        row(
          detail(
            l10n.brDateOfBirth,
            DateFormat('dd-MM-yyyy').format(record.dateOfBirth),
          ),
          detail(l10n.crGender, switch (record.sex) {
            Sex.male => l10n.modSexMale,
            Sex.female => l10n.modSexFemale,
            null => null,
          }),
        ),
        row(
          detail(l10n.crStateOfOrigin, record.stateOfOrigin),
          detail(l10n.crLgaOfOrigin, record.lgaOfOrigin),
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.accentRed,
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.baCancel),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.crFaceMatch),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
