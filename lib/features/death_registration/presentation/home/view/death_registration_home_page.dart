import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/cubit/applications_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/view/birth_registration_home_page.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/death_registration_repository.dart';
import 'package:vital_reg_mobile/features/death_registration/presentation/home/view/queried_record_dialog.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Death Registration home: the Birth Registration home over deaths.
class DeathRegistrationHomePage extends StatefulWidget {
  const DeathRegistrationHomePage({
    required this.onOpenForm,
    required this.onOpenRegistration,
    required this.onUpdateQueried,
    this.repository,
    super.key,
  });

  /// Opens the form, which continues the draft on the device if there is
  /// one.
  final OpenScreen onOpenForm;

  /// "Certificate Details".
  final OpenApplication onOpenRegistration;

  /// Corrects a queried record.
  final OpenApplication onUpdateQueried;

  /// Defaults to the registered one; tests pass a fake.
  final DeathRegistrationRepository? repository;

  @override
  State<DeathRegistrationHomePage> createState() =>
      _DeathRegistrationHomePageState();
}

class _DeathRegistrationHomePageState extends State<DeathRegistrationHomePage> {
  late final DeathRegistrationRepository _repository =
      widget.repository ?? GetIt.instance<DeathRegistrationRepository>();
  late final _cubit = ApplicationsCubit(_repository)..load().ignore();

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  /// A queried record opens the "Queried Record" dialog first; the rest
  /// open Certificate Details.
  Future<void> _open(String id) async {
    BirthApplicationSummary? item;
    for (final candidate in _cubit.state.items) {
      if (candidate.id == id) item = candidate;
    }
    if (item?.status != ApplicationStatus.queried) {
      return widget.onOpenRegistration(id);
    }
    final update = await showQueriedRecordDialog(
      context,
      record: _repository.details(id),
    );
    if (!update) return;
    await widget.onUpdateQueried(id);
    // Back from the correction: it may have left the queried list.
    if (!_cubit.isClosed) await _cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BirthRegistrationHomeView(
        title: context.l10n.moduleDeathRegistration,
        resumeMessage: context.l10n.drResumeMessage,
        onStartApplication: widget.onOpenForm,
        onResumeApplication: widget.onOpenForm,
        onOpenApplication: _open,
      ),
    );
  }
}
