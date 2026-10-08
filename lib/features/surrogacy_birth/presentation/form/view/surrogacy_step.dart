part of 'surrogacy_form_page.dart';

/// Step 2, "Surrogacy Details": the court order, which must match the
/// surrogacy agreement exactly.
class _SurrogacyStep extends StatelessWidget {
  const _SurrogacyStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SurrogacyFormCubit>();
    final state = context.watch<SurrogacyFormCubit>().state;
    final data = state.referenceData!;
    final details = state.draft!.surrogacy;
    final today = cubit.today;
    final f = _Fields<SurrogacyDetailsField>(
      l10n: l10n,
      valueOf: (field) => details[field],
      errorOf: (field) => _errorText(
        l10n,
        details.errorOf(field, today: today),
        showRequired: state.showErrors,
      ),
      onChanged: cubit.surrogacyChanged,
    );

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.srStepSurrogacy,
        hint: l10n.srStepSurrogacyHint,
      ),
      fields: [
        f.select(
          SurrogacyDetailsField.arrangementType,
          l10n.srArrangementType,
          data.arrangementTypes,
        ),
        f.text(
          SurrogacyDetailsField.courtName,
          l10n.srCourtName,
          l10n.srCourtNameHint,
          inputFormatters: _Fields.plain,
        ),
        f.text(
          SurrogacyDetailsField.orderReference,
          l10n.srOrderReference,
          l10n.srOrderReferenceHint,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: _Fields.plain,
        ),
        AppDateField(
          key: const ValueKey(SurrogacyDetailsField.orderDate),
          label: l10n.srOrderDate,
          value: details.orderDate,
          firstDate: DateTime(today.year - 18),
          lastDate: today,
          errorText: f.errorOf(SurrogacyDetailsField.orderDate),
          onChanged: cubit.orderDateChanged,
        ),
      ],
    );
  }
}
