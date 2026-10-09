import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/application_details.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/details/cubit/application_details_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/shared/application_sections.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/shared/application_status_style.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/shared/query_reason_card.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "Certificate Details": a submitted application, read-only. A queried
/// one also shows the reason and, with [onUpdate], "Update record".
class ApplicationDetailsPage extends StatelessWidget {
  const ApplicationDetailsPage({required this.id, this.onUpdate, super.key});

  final String id;

  /// Opens the correction of this queried record (from the router).
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ApplicationDetailsCubit(
        GetIt.instance<BirthRegistrationRepository>(),
        id: id,
      )..load().ignore(),
      child: ApplicationDetailsView(onUpdate: onUpdate),
    );
  }
}

class ApplicationDetailsView extends StatelessWidget {
  const ApplicationDetailsView({this.onUpdate, super.key});

  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ApplicationDetailsCubit>();
    final state = context.watch<ApplicationDetailsCubit>().state;
    final details = state.details;
    final referenceData = state.referenceData;

    final onUpdate = this.onUpdate;
    final canUpdate =
        onUpdate != null &&
        details?.summary.status == ApplicationStatus.queried;
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: canUpdate
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: AppButton(
                  label: l10n.brUpdateRecord,
                  onPressed: onUpdate,
                ),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: details == null || referenceData == null
          ? switch (state.status) {
              DetailsStatus.failure => Center(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.failure?.localize(l10n) ?? l10n.errorUnexpected,
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: cubit.load,
                        child: Text(l10n.tryAgain),
                      ),
                    ],
                  ),
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            }
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
                  _Header(details: details),
                  const SizedBox(height: Spacing.md),
                  if (details.summary.status == ApplicationStatus.queried) ...[
                    QueryReasonCard(reason: details.queryReason ?? '-'),
                    const SizedBox(height: Spacing.md),
                  ],
                  ApplicationSections(
                    referenceData: referenceData,
                    child: details.child,
                    childNin: details.childNin,
                    mother: details.mother,
                    father: details.father,
                    informant: details.informant,
                    documents: details.documents,
                  ),
                ],
              ),
            ),
    );
  }
}

/// "Certificate Details · Approved", then the tracking ID and date.
class _Header extends StatelessWidget {
  const _Header({required this.details});

  final ApplicationDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final summary = details.summary;
    final issued =
        summary.status == ApplicationStatus.approved ||
        summary.status == ApplicationStatus.printed;
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(summary.submittedOn);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.selectedCardFill,
            borderRadius: BorderRadius.circular(Spacing.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      issued
                          ? l10n.brCertificateDetails
                          : l10n.brApplicationDetails,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppPalette.inkStrong,
                      ),
                    ),
                  ),
                ),
                StatusChip(status: summary.status, fontSize: 11),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          '${summary.childName} · ${summary.trackingId} · $date',
          style: textTheme.labelSmall?.copyWith(color: AppPalette.muted),
        ),
      ],
    );
  }
}
