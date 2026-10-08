import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_date_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_upload_tile.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/certificate/cubit/legacy_certificate_cubit.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/pick_photo.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/reissuance_labels.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// The old certificate, after the face match. [onDone] (from the router)
/// moves on to the form for its type.
class LegacyCertificatePage extends StatelessWidget {
  const LegacyCertificatePage({
    required this.onDone,
    this.repository,
    super.key,
  });

  final ValueChanged<ReissuanceKind> onDone;

  /// Defaults to the registered one; tests pass a fake.
  final ReissuanceRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LegacyCertificateCubit(
        repository ?? GetIt.instance<ReissuanceRepository>(),
      )..load().ignore(),
      child: LegacyCertificateView(onDone: onDone),
    );
  }
}

class LegacyCertificateView extends StatelessWidget {
  const LegacyCertificateView({
    required this.onDone,
    this.pickCertificate = pickPhotoFromDevice,
    super.key,
  });

  final ValueChanged<ReissuanceKind> onDone;
  final PickPhoto pickCertificate;

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<LegacyCertificateCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final image = await pickCertificate(context);
      if (image == null) return;
      final error = await cubit.filePicked(
        path: image.path,
        name: image.name,
        sizeBytes: await image.length(),
      );
      if (error != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(switch (error) {
              DocumentError.tooLarge => l10n.brDocTooLarge,
              DocumentError.unsupportedType => l10n.brDocUnsupported,
            }),
          ),
        );
      }
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.brCameraFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<LegacyCertificateCubit>().state;
    final cubit = context.read<LegacyCertificateCubit>();
    final errors = state.showErrors ? state.errors : const <CertificateError>{};
    String? errorFor(CertificateError error) => errors.contains(error)
        ? switch (error) {
            CertificateError.typeRequired => l10n.crTypeRequired,
            CertificateError.numberRequired => l10n.crNumberRequired,
            CertificateError.numberInvalid => l10n.crNumberInvalid,
            CertificateError.issuedDateRequired => l10n.crIssuedDateRequired,
            CertificateError.issuedDateTooLate => l10n.crIssuedDateTooLate(
              DateFormat.yMMMMd(
                Localizations.localeOf(context).toString(),
              ).format(LegacyCertificateCubit.latestIssueDate),
            ),
            CertificateError.fileRequired => l10n.crCertificateRequired,
          }
        : null;
    final file = state.file;

    return BlocListener<LegacyCertificateCubit, LegacyCertificateState>(
      listenWhen: (previous, current) => !previous.isDone && current.isDone,
      listener: (_, state) => onDone(state.kind!),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              0,
              Spacing.md,
              Spacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.crTitle,
                  style: textTheme.titleLarge?.copyWith(
                    color: AppPalette.inkStrong,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : state.missingApplication
                      ? Center(
                          child: Text(
                            l10n.crNoApplication,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView(
                          children: [
                            AppSelectField<ReissuanceKind>(
                              label: l10n.crCertificateType,
                              hint: l10n.brSelectOption,
                              items: {
                                for (final kind in ReissuanceKind.values)
                                  kind: kind.certificate(l10n),
                              },
                              value: state.kind,
                              errorText: errorFor(
                                CertificateError.typeRequired,
                              ),
                              onChanged: cubit.kindChanged,
                            ),
                            const SizedBox(height: Spacing.md),
                            AppTextField(
                              label: l10n.crCertificateNumber,
                              hintText: l10n.crCertificateNumberHint,
                              initialValue: state.number,
                              textCapitalization: TextCapitalization.characters,
                              errorText:
                                  errorFor(CertificateError.numberRequired) ??
                                  errorFor(CertificateError.numberInvalid),
                              onChanged: cubit.numberChanged,
                            ),
                            const SizedBox(height: Spacing.md),
                            AppDateField(
                              label: l10n.crIssuedDate,
                              value: state.issuedOn,
                              firstDate: DateTime(1900),
                              lastDate: LegacyCertificateCubit.latestIssueDate,
                              errorText:
                                  errorFor(
                                    CertificateError.issuedDateRequired,
                                  ) ??
                                  errorFor(CertificateError.issuedDateTooLate),
                              onChanged: cubit.issuedOnChanged,
                            ),
                            const SizedBox(height: Spacing.md),
                            AppUploadTile(
                              label: l10n.crOldCertificate,
                              uploadLabel: l10n.crUploadCertificate,
                              note: l10n.crUploadNote,
                              removeLabel: l10n.brRemoveDocument(
                                l10n.crOldCertificate,
                              ),
                              fileName: file?.name,
                              fileDetail: file == null
                                  ? null
                                  : '${file.name} · '
                                        '${fileSize(file.sizeBytes)}',
                              onPick: () => unawaited(_pick(context)),
                              onRemove: file == null
                                  ? null
                                  : () => unawaited(cubit.fileRemoved()),
                              errorText: errorFor(
                                CertificateError.fileRequired,
                              ),
                            ),
                          ],
                        ),
                ),
                AppButton(
                  label: l10n.brValidate,
                  isLoading: state.isSaving,
                  // Like the design: grey until everything is filled in.
                  muted: state.errors.isNotEmpty,
                  onPressed: state.isLoading || state.missingApplication
                      ? null
                      : cubit.validate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
