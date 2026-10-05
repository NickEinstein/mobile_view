import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_form_layout.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/shared/application_status_style.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/still_birth_repository.dart';
import 'package:vital_reg_mobile/features/still_birth/presentation/details/cubit/still_birth_details_cubit.dart';
import 'package:vital_reg_mobile/features/still_birth/presentation/shared/still_birth_sections.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "Certificate Details" for a still birth, read-only.
class StillBirthDetailsPage extends StatelessWidget {
  const StillBirthDetailsPage({required this.id, this.repository, super.key});

  final String id;

  /// Defaults to the registered one; tests pass a fake.
  final StillBirthRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StillBirthDetailsCubit(
        repository ?? GetIt.instance<StillBirthRepository>(),
        id: id,
      )..load().ignore(),
      child: const StillBirthDetailsView(),
    );
  }
}

class StillBirthDetailsView extends StatelessWidget {
  const StillBirthDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<StillBirthDetailsCubit>();
    final state = context.watch<StillBirthDetailsCubit>().state;
    final record = state.record;
    final data = state.referenceData;

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
          : RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  0,
                  Spacing.md,
                  Spacing.lg,
                ),
                children: [
                  // The design's green "Certificate Details · Approved" bar.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppPalette.selectedCardFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.sm + Spacing.xs),
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
                  const SizedBox(height: Spacing.md),
                  AppStepTitle(
                    title: l10n.brReviewTitle,
                    hint: l10n.sbDetailsHint,
                  ),
                  const SizedBox(height: Spacing.md),
                  StillBirthSections(draft: record.toDraft(), data: data),
                ],
              ),
            ),
    );
  }
}
