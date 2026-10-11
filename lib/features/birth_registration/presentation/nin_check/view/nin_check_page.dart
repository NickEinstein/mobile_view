import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/nin_check/cubit/nin_check_cubit.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "New Birth Registration": asks whether the child has a NIN. [onDone]
/// (from the router) opens the form once the draft is started.
class NinCheckPage extends StatelessWidget {
  const NinCheckPage({required this.onDone, this.offline = false, super.key});

  final VoidCallback onDone;

  /// Offline mode is on.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NinCheckCubit(
        GetIt.instance<BirthRegistrationRepository>(),
        offline: offline,
      ),
      child: NinCheckView(onDone: onDone),
    );
  }
}

class NinCheckView extends StatelessWidget {
  const NinCheckView({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<NinCheckCubit>().state;
    final cubit = context.read<NinCheckCubit>();
    final failure = state.failure;

    return BlocListener<NinCheckCubit, NinCheckState>(
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
                  l10n.brNewTitle,
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
                        label: l10n.brHasNinQuestion,
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
                          label: l10n.brChildNin,
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
                        if (state.offline) ...[
                          const SizedBox(height: Spacing.sm),
                          Text(
                            l10n.brOfflineNinNote,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppPalette.muted,
                            ),
                          ),
                        ],
                      ],
                      if (failure != null) ...[
                        const SizedBox(height: Spacing.md),
                        Text(
                          failure.localize(l10n),
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
                    true when state.offline => l10n.brProceed,
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
