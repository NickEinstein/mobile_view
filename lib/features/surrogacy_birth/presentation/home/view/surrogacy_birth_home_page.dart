import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/cubit/applications_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/view/birth_registration_home_page.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/surrogacy_birth_repository.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Surrogacy Birth Registration home: the Birth Registration home over
/// surrogacy applications. Navigation comes from the router.
class SurrogacyBirthHomePage extends StatefulWidget {
  const SurrogacyBirthHomePage({
    required this.onStart,
    required this.onResumeAt,
    required this.onOpenApplication,
    this.repository,
    super.key,
  });

  /// Starts a new registration: the server creates it, then the child's
  /// NIN.
  final OpenScreen onStart;

  /// Continues the unfinished registration where it stopped.
  final Future<void> Function(SurrogacyStage stage) onResumeAt;

  /// "Certificate Details" (also how a saved draft is continued).
  final OpenApplication onOpenApplication;

  /// Defaults to the registered one; tests pass a fake.
  final SurrogacyBirthRepository? repository;

  @override
  State<SurrogacyBirthHomePage> createState() => _SurrogacyBirthHomePageState();
}

class _SurrogacyBirthHomePageState extends State<SurrogacyBirthHomePage> {
  late final SurrogacyBirthRepository _repository =
      widget.repository ?? GetIt.instance<SurrogacyBirthRepository>();
  late final ApplicationsCubit _cubit = ApplicationsCubit(_repository)
    ..load().ignore();

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  /// Applications started but not submitted, on any device. Picking one
  /// opens its details, which offers "Continue".
  Future<void> _showDrafts(BuildContext context) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DraftsSheet(drafts: _repository.drafts()),
    );
    if (id != null) await widget.onOpenApplication(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocProvider.value(
      value: _cubit,
      child: BirthRegistrationHomeView(
        title: l10n.moduleSurrogacyBirthRegistration,
        resumeMessage: l10n.srResumeMessage,
        onStartApplication: widget.onStart,
        onResumeApplication: () async {
          final draft = await _repository.loadDraft();
          await widget.onResumeAt(draft?.stage ?? SurrogacyStage.nin);
        },
        onOpenApplication: (id) async {
          await widget.onOpenApplication(id);
          // Back from the details: a query response may have moved it.
          if (!_cubit.isClosed) await _cubit.load();
        },
        actions: [
          IconButton(
            tooltip: l10n.srSavedDrafts,
            icon: const Icon(Icons.drafts_outlined),
            onPressed: () => unawaited(_showDrafts(context)),
          ),
        ],
      ),
    );
  }
}

/// "Saved Drafts": pops the chosen draft's id.
class _DraftsSheet extends StatelessWidget {
  const _DraftsSheet({required this.drafts});

  final Future<Result<List<BirthApplicationSummary>>> drafts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: FutureBuilder(
        future: drafts,
        builder: (context, snapshot) {
          final Widget body = switch (snapshot.data) {
            null => const Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            Err(:final failure) => Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text(failure.localize(l10n), textAlign: TextAlign.center),
            ),
            Ok(value: final items) when items.isEmpty => Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text(l10n.srNoDrafts, textAlign: TextAlign.center),
            ),
            Ok(value: final items) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items)
                  ListTile(
                    title: Text(item.childName),
                    subtitle: Text(item.trackingId),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(item.id),
                  ),
              ],
            ),
          };
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                child: Text(
                  l10n.srSavedDrafts,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppPalette.inkStrong,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(child: SingleChildScrollView(child: body)),
              const SizedBox(height: Spacing.md),
            ],
          );
        },
      ),
    );
  }
}
