import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_dialog.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_record.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "Queried Record": certificate number, names and the reason, with
/// Cancel and Update. Completes with true when the user taps Update.
Future<bool> showQueriedRecordDialog(
  BuildContext context, {
  required Future<Result<AttestationRecord>> record,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _QueriedRecordDialog(record: record),
    ) ??
    false;

class _QueriedRecordDialog extends StatelessWidget {
  const _QueriedRecordDialog({required this.record});

  final Future<Result<AttestationRecord>> record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final danger = Theme.of(context).colorScheme.error;

    Widget row(String label, String value, {bool alert = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: MergeSemantics(
        child: Text.rich(
          TextSpan(
            text: '$label:  ',
            style: textTheme.bodySmall?.copyWith(
              color: alert ? danger : AppPalette.muted,
            ),
            children: [
              TextSpan(
                text: value,
                style: textTheme.bodySmall?.copyWith(
                  color: alert ? danger : AppPalette.inkStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return FutureBuilder(
      future: record,
      builder: (context, snapshot) {
        final result = snapshot.data;
        final loaded = result is Ok<AttestationRecord> ? result.value : null;
        return AppDialog(
          children: [
            Text(
              l10n.baQueriedRecordTitle,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: AppPalette.inkStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.md),
            switch (result) {
              null => const Padding(
                padding: EdgeInsets.all(Spacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
              Err(:final failure) => Text(
                failure.localize(l10n),
                textAlign: TextAlign.center,
                style: TextStyle(color: danger),
              ),
              Ok(value: final r) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row(l10n.baCertNo, r.summary.trackingId),
                  row(
                    l10n.baQuerySurname,
                    (r.applicant[ApplicantField.surname] ?? '-').toUpperCase(),
                  ),
                  row(
                    l10n.baQueryFirstName,
                    (r.applicant[ApplicantField.firstName] ?? '-')
                        .toUpperCase(),
                  ),
                  row(l10n.baQueryReason, r.queryReason ?? '-', alert: true),
                ],
              ),
            },
            const SizedBox(height: Spacing.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.danger.withValues(
                        alpha: 0.85,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.baCancel),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: AppButton(
                    label: l10n.baUpdate,
                    onPressed: loaded == null
                        ? null
                        : () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
