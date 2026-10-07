import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_form_layout.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_review.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/shared/application_status_style.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_record.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/surrogacy_birth_repository.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/details/cubit/surrogacy_details_cubit.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/shared/surrogacy_sections.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "Certificate Details" for one surrogacy application, read-only. A
/// queried one offers "Respond to Query"; a draft offers "Continue".
class SurrogacyDetailsPage extends StatelessWidget {
  const SurrogacyDetailsPage({
    required this.id,
    required this.onRespondToQuery,
    required this.onContinue,
    this.repository,
    super.key,
  });

  final String id;

  /// Opens the correction of this queried application.
  final VoidCallback onRespondToQuery;

  /// The draft is now on the device; opens [stage].
  final void Function(SurrogacyStage stage) onContinue;

  /// Defaults to the registered one; tests pass a fake.
  final SurrogacyBirthRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SurrogacyDetailsCubit(
        repository ?? GetIt.instance<SurrogacyBirthRepository>(),
        id: id,
      )..load().ignore(),
      child: SurrogacyDetailsView(
        onRespondToQuery: onRespondToQuery,
        onContinue: onContinue,
      ),
    );
  }
}

class SurrogacyDetailsView extends StatelessWidget {
  const SurrogacyDetailsView({
    required this.onRespondToQuery,
    required this.onContinue,
    super.key,
  });

  final VoidCallback onRespondToQuery;
  final void Function(SurrogacyStage stage) onContinue;

  Future<void> _continue(BuildContext context) async {
    final cubit = context.read<SurrogacyDetailsCubit>();
    final l10n = context.l10n;
    if (await cubit.wouldReplaceDraft()) {
      if (!context.mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.brResumeTitle),
          content: Text(l10n.srReplaceDraftMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.no),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.yes),
            ),
          ],
        ),
      );
      if (!(replace ?? false)) return;
    }
    await cubit.continueDraft();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<SurrogacyDetailsCubit>();
    final state = context.watch<SurrogacyDetailsCubit>().state;
    final record = state.record;
    final data = state.referenceData;

    return BlocListener<SurrogacyDetailsCubit, SurrogacyDetailsState>(
      listenWhen: (previous, current) =>
          previous.resumedAt != current.resumedAt ||
          previous.resumeFailure != current.resumeFailure,
      listener: (context, state) {
        if (state.resumedAt case final stage?) {
          onContinue(stage);
        } else if (state.resumeFailure case final failure?) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.localize(l10n))));
        }
      },
      child: Scaffold(
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
                            _StatusBar(record: record),
                            const SizedBox(height: Spacing.sm),
                            Text(
                              record.referenceId,
                              style: textTheme.labelSmall?.copyWith(
                                color: AppPalette.muted,
                              ),
                            ),
                            if (record.certificateNumber case final number?)
                              AppReviewEntry(l10n.srCertificateNumber, number),
                            if (record.status ==
                                    SurrogacyRecordStatus.queried &&
                                record.remarks != null) ...[
                              const SizedBox(height: Spacing.sm),
                              _QueryReason(record.remarks!),
                            ],
                            const SizedBox(height: Spacing.md),
                            AppStepTitle(
                              title: l10n.brReviewTitle,
                              hint: l10n.srDetailsHint,
                            ),
                            const SizedBox(height: Spacing.md),
                            SurrogacySections(
                              draft: record.draft.withRegistrationLocation(
                                data.locationOfCenter,
                              ),
                              data: data,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (record.status == SurrogacyRecordStatus.queried)
                      _BottomAction(
                        label: l10n.srRespondToQuery,
                        onPressed: onRespondToQuery,
                      )
                    else if (record.status == SurrogacyRecordStatus.drafted)
                      _BottomAction(
                        label: l10n.srContinueDraft,
                        isLoading: state.isResuming,
                        onPressed: () => unawaited(_continue(context)),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// The design's green "Certificate Details · status" bar.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.record});

  final SurrogacyRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final status = record.status.applicationStatus;
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
                l10n.brCertificateDetails,
                style: textTheme.titleSmall?.copyWith(
                  color: AppPalette.inkStrong,
                ),
              ),
            ),
            if (status != null)
              StatusChip(status: status, fontSize: 11)
            else
              Text(
                l10n.srDrafted,
                style: textTheme.labelSmall?.copyWith(color: AppPalette.muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// Why the registrar's supervisor queried it, in red.
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
              context.l10n.srQueryReason,
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

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Spacing.md,
      Spacing.sm,
      Spacing.md,
      Spacing.md,
    ),
    child: SizedBox(
      width: double.infinity,
      child: AppButton(
        label: label,
        isLoading: isLoading,
        onPressed: onPressed,
      ),
    ),
  );
}
