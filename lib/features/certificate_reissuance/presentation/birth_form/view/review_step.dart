part of 'birth_reissuance_form_page.dart';

/// Step 5, "Information Preview", then the recipient's email (confirmed
/// by code).
class _ReviewStep extends StatelessWidget {
  const _ReviewStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BirthReissuanceFormCubit>();
    final state = context.watch<BirthReissuanceFormCubit>().state;
    final facePhoto = state.draft?.facePhoto;
    final faceUrl = state.record?.faceUrl;
    final query = state.record?.query;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppStepTitle(title: l10n.brReviewTitle, hint: l10n.brReviewHint),
        const SizedBox(height: Spacing.lg),
        if (query != null) ...[
          ReissuanceQueryNote(query: query),
          const SizedBox(height: Spacing.md),
        ],
        BirthReissuanceSections(
          certificate: state.certificate!,
          form: state.form!,
          options: state.options!,
          statesOf: state.statesOf,
          lgasOf: state.lgasOf,
          face: facePhoto != null
              ? FileImage(File(facePhoto))
              : faceUrl != null
              ? NetworkImage(faceUrl.toString())
              : null,
          onEdit: cubit.editStep,
          showErrors: state.showErrors,
        ),
        const SizedBox(height: Spacing.md),
        EmailCodeField(
          title: l10n.crRecipientEmail,
          note: l10n.crRecipientEmailNote,
          label: l10n.crEmailHint,
          showErrors: state.showErrors,
        ),
      ],
    );
  }
}
