import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/cubit/applications_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/view/birth_registration_home_page.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Birth Attestation home: the Birth Registration home over attestations.
class BirthAttestationHomePage extends StatefulWidget {
  const BirthAttestationHomePage({
    required this.onStartApplication,
    required this.onResumeAtFace,
    required this.onResumeAtForm,
    required this.onOpenApplication,
    this.repository,
    super.key,
  });

  final OpenScreen onStartApplication;

  /// An unfinished application still needs the applicant's face.
  final OpenScreen onResumeAtFace;
  final OpenScreen onResumeAtForm;

  /// "Certificate Details".
  final OpenApplication onOpenApplication;

  /// Defaults to the registered one; tests pass a fake.
  final BirthAttestationRepository? repository;

  @override
  State<BirthAttestationHomePage> createState() =>
      _BirthAttestationHomePageState();
}

class _BirthAttestationHomePageState extends State<BirthAttestationHomePage> {
  late final BirthAttestationRepository _repository =
      widget.repository ?? GetIt.instance<BirthAttestationRepository>();
  late final ApplicationsCubit _cubit = ApplicationsCubit(_repository)
    ..load().ignore();

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  /// Every record opens its details; a queried one shows the reason
  /// and "Update" there.
  Future<void> _open(String id) => widget.onOpenApplication(id);

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BirthRegistrationHomeView(
        title: context.l10n.moduleBirthAttestation,
        onStartApplication: widget.onStartApplication,
        onResumeApplication: () async {
          final draft = await _repository.loadDraft();
          await (draft?.facePhoto == null
              ? widget.onResumeAtFace()
              : widget.onResumeAtForm());
        },
        onOpenApplication: _open,
      ),
    );
  }
}
