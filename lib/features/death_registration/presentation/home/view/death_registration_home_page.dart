import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/cubit/applications_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/view/birth_registration_home_page.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/death_registration_repository.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Death Registration home: the Birth Registration home over deaths.
class DeathRegistrationHomePage extends StatefulWidget {
  const DeathRegistrationHomePage({
    required this.onOpenForm,
    required this.onOpenRegistration,
    this.repository,
    super.key,
  });

  /// Opens the form, which continues the draft on the device if there is
  /// one.
  final OpenScreen onOpenForm;

  /// "Certificate Details".
  final OpenApplication onOpenRegistration;

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

  /// Every record opens its details; a queried one shows the reason
  /// and "Update" there.
  Future<void> _open(String id) => widget.onOpenRegistration(id);

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
