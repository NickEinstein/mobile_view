import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_radio_group.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/request/cubit/modification_request_cubit.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/shared/modification_labels.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "Birth Modifications": what to correct and why. [onProceed] receives
/// the completed answers.
class ModificationRequestPage extends StatelessWidget {
  const ModificationRequestPage({
    required this.kind,
    required this.onProceed,
    super.key,
  });

  final ModificationKind kind;
  final ValueChanged<ModificationRequest> onProceed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ModificationRequestCubit(kind),
      child: ModificationRequestView(onProceed: onProceed),
    );
  }
}

class ModificationRequestView extends StatelessWidget {
  const ModificationRequestView({required this.onProceed, super.key});

  final ValueChanged<ModificationRequest> onProceed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<ModificationRequestCubit>();
    final request = context.watch<ModificationRequestCubit>().state;
    final type = request.type;
    final reasons = request.reasons;

    return Scaffold(
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
            request.kind.title(l10n),
            style: textTheme.titleLarge?.copyWith(
              color: AppPalette.inkStrong,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            l10n.modRequestIntro,
            style: textTheme.bodySmall?.copyWith(color: AppPalette.muted),
          ),
          const SizedBox(height: Spacing.lg),
          AppSelectField<ModificationType>(
            label: l10n.modTypeLabel,
            hint: l10n.brSelectOption,
            items: {
              for (final option in request.kind.types)
                option: option.label(l10n),
            },
            value: type,
            onChanged: (value) {
              if (value != null) cubit.typeSelected(value);
            },
          ),
          if (type != null && request.needsField) ...[
            const SizedBox(height: Spacing.md),
            AppSelectField<ModificationField>(
              label: l10n.modFieldLabel,
              hint: l10n.brSelectOption,
              items: {
                for (final option in type.fields) option: option.label(l10n),
              },
              value: request.field,
              onChanged: (value) {
                if (value != null) cubit.fieldSelected(value);
              },
            ),
          ],
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: Spacing.md),
            AppRadioGroup<ModificationReason>(
              // Rebuilt when the choices change, so none stays selected.
              key: ValueKey(reasons),
              label: l10n.modReasonLabel,
              vertical: true,
              options: {
                for (final reason in reasons) reason: reason.label(l10n),
              },
              value: request.reason,
              onChanged: cubit.reasonSelected,
            ),
          ],
          if (type != null) ...[
            const SizedBox(height: Spacing.md),
            AppTextField(
              label: l10n.modCommentLabel,
              optionalLabel: l10n.brOptional,
              hintText: l10n.modCommentHint,
              initialValue: request.comment,
              maxLines: 4,
              maxLength: ModificationRequest.commentMaxLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: cubit.commentChanged,
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(Spacing.md),
        child: AppButton(
          label: l10n.proceed,
          onPressed: request.isComplete ? () => onProceed(request) : null,
        ),
      ),
    );
  }
}
