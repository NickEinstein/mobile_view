import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/nin/cubit/applicant_nin_cubit.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "New Birth Attestation": the NIN question.
class ApplicantNinPage extends StatelessWidget {
  const ApplicantNinPage({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ApplicantNinCubit(GetIt.instance<BirthAttestationRepository>()),
      child: ApplicantNinView(onDone: onDone),
    );
  }
}

class ApplicantNinView extends StatelessWidget {
  const ApplicantNinView({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<ApplicantNinCubit>().state;
    final cubit = context.read<ApplicantNinCubit>();
    final error = state.isUnderAge
        ? l10n.baApplicantUnderAge
        : switch (state.failure) {
            NotFoundFailure() => l10n.baNinNotFound,
            final failure? => failure.localize(l10n),
            null => null,
          };

    return BlocListener<ApplicantNinCubit, ApplicantNinState>(
      listenWhen: (previous, current) => !previous.isDone && current.isDone,
      listener: (_, _) => onDone(),
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
                  l10n.baNewTitle,
                  style: textTheme.titleLarge?.copyWith(
                    color: AppPalette.inkStrong,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                Expanded(
                  child: ListView(
                    children: [
                      AppSelectField<bool>(
                        label: l10n.baHasNinQuestion,
                        hint: l10n.brSelect,
                        items: {true: l10n.yes, false: l10n.no},
                        value: state.hasNin,
                        onChanged: (value) {
                          if (value != null) cubit.answered(value);
                        },
                      ),
                      if (state.hasNin ?? false) ...[
                        const SizedBox(height: Spacing.lg),
                        AppTextField(
                          label: l10n.baApplicantNin,
                          hintText: l10n.brNinHint,
                          initialValue: state.nin,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          onChanged: cubit.ninChanged,
                          onSubmitted: (_) => unawaited(cubit.proceed()),
                        ),
                      ],
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
                  label: switch (state.hasNin) {
                    null => l10n.brValidate,
                    true => l10n.brValidateNin,
                    false => l10n.brProceed,
                  },
                  isLoading: state.isSubmitting,
                  onPressed: state.canProceed ? cubit.proceed : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
