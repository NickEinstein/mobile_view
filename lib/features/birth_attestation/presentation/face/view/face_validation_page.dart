import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_dialog.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/face_source.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/face/cubit/face_validation_cubit.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'face_validation_widgets.dart';

/// Takes a photo; completes with its temporary path, or null if cancelled.
typedef TakePhoto = Future<String?> Function();

Future<String?> _frontCameraPhoto() async {
  final photo = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    // Enough for identification; keeps uploads small.
    maxWidth: 1080,
    imageQuality: 85,
  );
  return photo?.path;
}

/// "Face Validation"; [onValidated] runs once the face matches.
class FaceValidationPage extends StatelessWidget {
  const FaceValidationPage({required this.onValidated, this.source, super.key});

  final VoidCallback onValidated;

  /// Defaults to the Birth Attestation draft.
  final FaceSource? source;

  @override
  Widget build(BuildContext context) {
    final source = this.source;
    return BlocProvider(
      create: (_) =>
          (source == null
                ? FaceValidationCubit(
                    GetIt.instance<BirthAttestationRepository>(),
                  )
                : FaceValidationCubit.source(source))
            ..load().ignore(),
      child: FaceValidationView(onValidated: onValidated),
    );
  }
}

class FaceValidationView extends StatelessWidget {
  const FaceValidationView({
    required this.onValidated,
    this.takePhoto = _frontCameraPhoto,
    super.key,
  });

  final VoidCallback onValidated;
  final TakePhoto takePhoto;

  Future<void> _capture(BuildContext context) async {
    final cubit = context.read<FaceValidationCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final cameraFailed = context.l10n.brCameraFailed;
    try {
      final path = await takePhoto();
      if (path != null) await cubit.captured(path);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(cameraFailed)));
    }
  }

  Future<void> _confirmDone(
    BuildContext context, {
    required bool matched,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return PopScope(
          canPop: false,
          child: AppStatusDialog(
            title: matched ? l10n.baFaceMatchedTitle : l10n.baFaceCapturedTitle,
            message: l10n.baFaceMatchedMessage,
            actionLabel: l10n.proceed,
            onAction: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
    onValidated();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<FaceValidationCubit>().state;
    final cubit = context.read<FaceValidationCubit>();
    final onGuidelines = state.stage == FaceValidationStage.guidelines;

    return BlocListener<FaceValidationCubit, FaceValidationState>(
      listenWhen: (previous, current) => !previous.isDone && current.isDone,
      listener: (context, state) =>
          unawaited(_confirmDone(context, matched: state.matchesNin)),
      child: PopScope(
        // Back from the camera returns to the guidelines first.
        canPop: onGuidelines,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !state.isChecking) cubit.backToGuidelines();
        },
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
                    l10n.baFaceTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppPalette.inkStrong,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  Expanded(
                    child: onGuidelines
                        ? const SingleChildScrollView(child: _Guidelines())
                        : _CaptureStage(
                            onCapture: () => unawaited(_capture(context)),
                          ),
                  ),
                  if (onGuidelines)
                    AppButton(
                      label: l10n.baContinue,
                      onPressed: cubit.guidelinesRead,
                    )
                  else ...[
                    AppButton(
                      label: l10n.baContinue,
                      isLoading: state.isChecking,
                      onPressed: state.canContinue ? cubit.validate : null,
                    ),
                    TextButton(
                      onPressed: state.photoPath == null || state.isChecking
                          ? null
                          : () => unawaited(_capture(context)),
                      child: Text(l10n.baRetake),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
