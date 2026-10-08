import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/home/view/queried_record_dialog.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/cubit/applications_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/view/birth_registration_home_page.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Birth Attestation home: the Birth Registration home over attestation
/// applications. A queried one opens the "Queried Record" dialog first.
/// Navigation comes from the router.
class BirthAttestationHomePage extends StatefulWidget {
  const BirthAttestationHomePage({
    required this.onStartApplication,
    required this.onResumeAtFace,
    required this.onResumeAtForm,
    required this.onOpenApplication,
    required this.onUpdateQueried,
    this.repository,
    super.key,
  });

  final OpenScreen onStartApplication;

  /// An unfinished application still needs the applicant's face.
  final OpenScreen onResumeAtFace;
  final OpenScreen onResumeAtForm;

  /// "Certificate Details".
  final OpenApplication onOpenApplication;

  /// Corrects a queried record.
  final OpenApplication onUpdateQueried;

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

  Future<void> _open(String id) async {
    BirthApplicationSummary? item;
    for (final candidate in _cubit.state.items) {
      if (candidate.id == id) item = candidate;
    }
    if (item?.status != ApplicationStatus.queried) {
      return widget.onOpenApplication(id);
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
