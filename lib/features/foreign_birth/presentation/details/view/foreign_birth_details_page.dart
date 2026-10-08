import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_form_layout.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/shared/application_status_style.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/foreign_birth_repository.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/details/cubit/foreign_birth_details_cubit.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/shared/foreign_birth_sections.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "Certificate Details" for one foreign birth notification, read-only. A
/// queried one shows why and offers "Respond to Query".
class ForeignBirthDetailsPage extends StatelessWidget {
  const ForeignBirthDetailsPage({
    required this.id,
    required this.onRespondToQuery,
    this.repository,
    super.key,
  });

  /// The backend's numeric id.
  final String id;

  /// Opens the correction of this queried notification.
  final VoidCallback onRespondToQuery;

  /// Defaults to the registered one; tests pass a fake.
  final ForeignBirthRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ForeignBirthDetailsCubit(
        repository ?? GetIt.instance<ForeignBirthRepository>(),
        id: id,
      )..load().ignore(),
      child: ForeignBirthDetailsView(onRespondToQuery: onRespondToQuery),
    );
  }
}

class ForeignBirthDetailsView extends StatelessWidget {
  const ForeignBirthDetailsView({required this.onRespondToQuery, super.key});

  final VoidCallback onRespondToQuery;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<ForeignBirthDetailsCubit>();
    final state = context.watch<ForeignBirthDetailsCubit>().state;
    final record = state.record;
    final data = state.referenceData;
    final queried = record?.status == ApplicationStatus.queried;

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
                          _StatusBar(status: record.status),
                          const SizedBox(height: Spacing.sm),
                          if (record.notificationNumber case final number?)
                            Text(
                              number,
                              style: textTheme.labelSmall?.copyWith(
                                color: AppPalette.muted,
                              ),
                            ),
                          if (queried && record.queryReason != null) ...[
                            const SizedBox(height: Spacing.sm),
                            _QueryReason(record.queryReason!),
                          ],
                          const SizedBox(height: Spacing.md),
                          AppStepTitle(
                            title: l10n.brReviewTitle,
                            hint: l10n.acDetailsHint,
                          ),
                          const SizedBox(height: Spacing.md),
                          ForeignBirthSections(
                            draft: record.draft,
                            data: data,
                            stateName: state.stateName,
                            lgaName: state.lgaName,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (queried)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.md,
                        Spacing.sm,
                        Spacing.md,
                        Spacing.md,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: l10n.acRespondToQuery,
                          onPressed: onRespondToQuery,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// The design's green "Certificate Details · status" bar.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.status});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
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
                context.l10n.brCertificateDetails,
                style: textTheme.titleSmall?.copyWith(
                  color: AppPalette.inkStrong,
                ),
              ),
            ),
            StatusChip(status: status, fontSize: 11),
          ],
        ),
      ),
    );
  }
}

/// Why the notification was queried, in red.
class _QueryReason extends StatelessWidget {
  const _QueryReason(this.reason);

  final String reason;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: error),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sm + Spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.acQueryReason,
              style: textTheme.labelSmall?.copyWith(color: error),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              reason,
              style: textTheme.bodyMedium?.copyWith(
                color: AppPalette.inkStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
