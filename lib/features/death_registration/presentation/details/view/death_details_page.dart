import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_form_layout.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/shared/application_status_style.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/death_registration_repository.dart';
import 'package:vital_reg_mobile/features/death_registration/presentation/details/cubit/death_details_cubit.dart';
import 'package:vital_reg_mobile/features/death_registration/presentation/shared/death_sections.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "Certificate Details" for a death registration; a queried one offers
/// "Update".
class DeathDetailsPage extends StatelessWidget {
  const DeathDetailsPage({
    required this.id,
    required this.onUpdate,
    this.repository,
    super.key,
  });

  final String id;
  final VoidCallback onUpdate;

  /// Defaults to the registered one; tests pass a fake.
  final DeathRegistrationRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DeathDetailsCubit(
        repository ?? GetIt.instance<DeathRegistrationRepository>(),
        id: id,
      )..load().ignore(),
      child: DeathDetailsView(onUpdate: onUpdate),
    );
  }
}

class DeathDetailsView extends StatelessWidget {
  const DeathDetailsView({required this.onUpdate, super.key});

  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<DeathDetailsCubit>();
    final state = context.watch<DeathDetailsCubit>().state;
    final record = state.record;
    final data = state.referenceData;
    final queried = record?.summary.status == ApplicationStatus.queried;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: record == null || data == null
          ? Center(
              child: state.isLoading
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.failure?.localize(l10n) ??
                                l10n.errorUnexpected,
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: cubit.load,
                            child: Text(l10n.tryAgain),
                          ),
                        ],
                      ),
                    ),
            )
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: cubit.load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          Spacing.md,
                          0,
                          Spacing.md,
                          Spacing.lg,
                        ),
                        children: [
                          // The design's green "Certificate Details ·
                          // Approved" bar.
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppPalette.selectedCardFill,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(
                                Spacing.sm + Spacing.xs,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l10n.brCertificateDetails,
                                      style: textTheme.titleSmall?.copyWith(
                                        color: AppPalette.inkStrong,
                                      ),
                                    ),
                                  ),
                                  StatusChip(
                                    status: record.summary.status,
                                    fontSize: 11,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            record.summary.trackingId,
                            style: textTheme.labelSmall?.copyWith(
                              color: AppPalette.muted,
                            ),
                          ),
                          if (record.queryReason case final reason?
                              when queried) ...[
                            const SizedBox(height: Spacing.sm),
                            Text(
                              l10n.baQueriedBanner(reason),
                              style: textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: Spacing.md),
                          AppStepTitle(
                            title: l10n.brReviewTitle,
                            hint: l10n.drDetailsHint,
                          ),
                          const SizedBox(height: Spacing.md),
                          DeathSections(
                            draft: record.toQueriedDraft(),
                            data: data,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (queried)
                    Padding(
                      padding: const EdgeInsets.all(Spacing.md),
                      child: AppButton(
                        label: l10n.baUpdate,
                        onPressed: onUpdate,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
