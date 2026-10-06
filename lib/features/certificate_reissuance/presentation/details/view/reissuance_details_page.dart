import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/details/cubit/reissuance_details_cubit.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/attestation_reissuance_sections.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/birth_reissuance_sections.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/certificate_viewer.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/reissuance_labels.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "Certificate Details" for a reissuance request, with Update (queried)
/// or Download (approved).
class ReissuanceDetailsPage extends StatelessWidget {
  const ReissuanceDetailsPage({
    required this.kind,
    required this.id,
    required this.onUpdate,
    this.repository,
    super.key,
  });

  final ReissuanceKind kind;
  final String id;
  final VoidCallback onUpdate;

  /// Defaults to the registered one; tests pass a fake.
  final ReissuanceRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repository =
        this.repository ?? GetIt.instance<ReissuanceRepository>();
    return BlocProvider(
      create: (_) =>
          ReissuanceDetailsCubit(repository, kind: kind, id: id)
            ..load().ignore(),
      child: _DetailsView(
        kind: kind,
        repository: repository,
        onUpdate: onUpdate,
      ),
    );
  }
}

class _DetailsView extends StatelessWidget {
  const _DetailsView({
    required this.kind,
    required this.repository,
    required this.onUpdate,
  });

  final ReissuanceKind kind;
  final ReissuanceRepository repository;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<ReissuanceDetailsCubit>().state;
    final record = state.record;
    final failure = state.failure;
    final face = switch (record?.faceUrl) {
      final url? => NetworkImage(url.toString()),
      null => null,
    };

    Widget sections() {
      if (state.birth case final birth?) {
        return BirthReissuanceSections(
          certificate: (
            kind: ReissuanceKind.birth,
            number: birth.certificateNumber,
            issuedOn: birth.issuedOn,
            nin: birth.nin,
          ),
          form: birth.form,
          options: state.options!,
          statesOf: state.statesOf,
          lgasOf: state.lgasOf,
          face: face,
        );
      }
      final attestation = state.attestation!;
      return AttestationReissuanceSections(
        certificate: (
          kind: ReissuanceKind.attestation,
          number: attestation.certificateNumber,
          issuedOn: attestation.issuedOn,
          nin: attestation.nin,
        ),
        form: attestation.form,
        options: state.options!,
        nigeria: state.statesOf(ReissuanceCodes.nigeria),
        lgasOf: state.lgasOf,
        today: DateTime.now(),
        face: face,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : record == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        failure?.localize(l10n) ?? l10n.errorUnexpected,
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => unawaited(
                          context.read<ReissuanceDetailsCubit>().load(),
                        ),
                        child: Text(l10n.tryAgain),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.md,
                        0,
                        Spacing.md,
                        Spacing.lg,
                      ),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.crDetailsTitle,
                                style: textTheme.titleLarge?.copyWith(
                                  color: AppPalette.inkStrong,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ReissuanceStatusChip(status: record.status),
                          ],
                        ),
                        const SizedBox(height: Spacing.md),
                        if (record.query case final query?) ...[
                          ReissuanceQueryNote(query: query),
                          const SizedBox(height: Spacing.md),
                        ],
                        sections(),
                      ],
                    ),
                  ),
                  if (record.status == ReissuanceStatus.queried)
                    Padding(
                      padding: const EdgeInsets.all(Spacing.md),
                      child: AppButton(
                        label: l10n.crUpdate,
                        onPressed: onUpdate,
                      ),
                    )
                  else if (record.status == ReissuanceStatus.approved &&
                      record.reference.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(Spacing.md),
                      child: AppButton(
                        label: l10n.crDownload,
                        onPressed: () => unawaited(
                          showCertificate(
                            context,
                            image: repository.download(kind, record.reference),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
