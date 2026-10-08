import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/cubit/applications_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/view/birth_registration_home_page.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_draft.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/foreign_birth_repository.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Foreign Birth Notification home: the Birth Registration home over
/// foreign birth notifications. Navigation comes from the router.
class ForeignBirthHomePage extends StatefulWidget {
  const ForeignBirthHomePage({
    required this.onStart,
    required this.onResumeAt,
    required this.onOpenApplication,
    this.repository,
    super.key,
  });

  /// Starts a new notification: the payment comes first.
  final OpenScreen onStart;

  /// Continues the unfinished notification where it stopped.
  final Future<void> Function(ForeignBirthStage stage) onResumeAt;

  /// "Certificate Details".
  final OpenApplication onOpenApplication;

  /// Defaults to the registered one; tests pass a fake.
  final ForeignBirthRepository? repository;

  @override
  State<ForeignBirthHomePage> createState() => _ForeignBirthHomePageState();
}

class _ForeignBirthHomePageState extends State<ForeignBirthHomePage> {
  late final ForeignBirthRepository _repository =
      widget.repository ?? GetIt.instance<ForeignBirthRepository>();
  late final ApplicationsCubit _cubit = ApplicationsCubit(_repository)
    ..load().ignore();

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocProvider.value(
      value: _cubit,
      child: BirthRegistrationHomeView(
        title: l10n.moduleForeignBirthNotification,
        resumeMessage: l10n.fbResumeMessage,
        onStartApplication: widget.onStart,
        onResumeApplication: () async {
          final draft = await _repository.loadDraft();
          await widget.onResumeAt(draft?.stage ?? ForeignBirthStage.payment);
        },
        onOpenApplication: (id) async {
          await widget.onOpenApplication(id);
          // Back from the details: a query response may have moved it.
          if (!_cubit.isClosed) await _cubit.load();
        },
      ),
    );
  }
}
