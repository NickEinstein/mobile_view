part of 'adoption_form_page.dart';

/// Step 4, "Adoption Details": the adoption order, which must match the
/// order exactly.
class _AdoptionDetailsStep extends StatelessWidget {
  const _AdoptionDetailsStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AdoptionFormCubit>();
    final state = context.watch<AdoptionFormCubit>().state;
    final details = state.draft!.details;
    final today = cubit.today;
    final f = _Fields<AdoptionDetailsField>(
      l10n: l10n,
      valueOf: (field) => details[field],
      errorOf: (field) => _errorText(
        l10n,
        details.errorOf(field, today: today),
        showRequired: state.showErrors,
      ),
      onChanged: cubit.detailsChanged,
    );

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.acStepAdoptionDetails,
        hint: l10n.acAdoptionDetailsHint,
      ),
      fields: [
        f.text(
          AdoptionDetailsField.courtName,
          l10n.srCourtName,
          l10n.srCourtNameHint,
          inputFormatters: _Fields.plain,
        ),
        f.text(
          AdoptionDetailsField.orderReference,
          l10n.srOrderReference,
          l10n.srOrderReferenceHint,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: _Fields.plain,
        ),
        AppDateField(
          key: const ValueKey(AdoptionDetailsField.orderDate),
          label: l10n.acOrderDate,
          value: details.orderDate,
          firstDate: DateTime(today.year - 18),
          lastDate: today,
          errorText: f.errorOf(AdoptionDetailsField.orderDate),
          onChanged: cubit.orderDateChanged,
        ),
        // The backend accepts only these two values.
        f.select(AdoptionDetailsField.adoptionType, l10n.acAdoptionType, [
          Option(AdoptionCodes.domestic, l10n.acAdoptionDomestic),
          Option(AdoptionCodes.interCountry, l10n.acAdoptionInterCountry),
        ]),
      ],
    );
  }
}
