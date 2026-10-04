import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/modifications_repository.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/lookup/cubit/record_lookup_cubit.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/shared/modification_labels.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// After payment: the certificate number of the record to correct.
/// [onFound] (from the router) moves on with the record.
class RecordLookupPage extends StatelessWidget {
  const RecordLookupPage({
    required this.kind,
    required this.onFound,
    super.key,
  });

  final ModificationKind kind;
  final ValueChanged<ModificationRecord> onFound;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          RecordLookupCubit(GetIt.instance<ModificationsRepository>(), kind),
      child: RecordLookupView(onFound: onFound),
    );
  }
}

class RecordLookupView extends StatelessWidget {
  const RecordLookupView({required this.onFound, super.key});

  final ValueChanged<ModificationRecord> onFound;

  static final _upperCase = TextInputFormatter.withFunction(
    (_, value) => value.copyWith(text: value.text.toUpperCase()),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<RecordLookupCubit>();
    final state = context.watch<RecordLookupCubit>().state;
    final failure = state.failure;

    return BlocListener<RecordLookupCubit, RecordLookupState>(
      listenWhen: (previous, current) =>
          current.record != null && previous.record != current.record,
      listener: (_, state) => onFound(state.record!),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            0,
            Spacing.md,
            Spacing.lg,
          ),
          children: [
            Text(
              cubit.kind.title(l10n),
              style: textTheme.titleLarge?.copyWith(
                color: AppPalette.inkStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              l10n.modLookupIntro,
              style: textTheme.bodySmall?.copyWith(color: AppPalette.muted),
            ),
            const SizedBox(height: Spacing.lg),
            AppTextField(
              label: l10n.modCertificateNumberLabel,
              hintText: l10n.modCertificateNumberHint,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                _upperCase,
              ],
              errorText: failure == null
                  ? null
                  : state.notFound
                  ? l10n.modRecordNotFound
                  : failure.localize(l10n),
              onChanged: cubit.numberChanged,
              onSubmitted: (_) => unawaited(cubit.lookUp()),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(Spacing.md),
          child: AppButton(
            label: l10n.modContinue,
            isLoading: state.isLoading,
            onPressed: state.number.isEmpty ? null : cubit.lookUp,
          ),
        ),
      ),
    );
  }
}
