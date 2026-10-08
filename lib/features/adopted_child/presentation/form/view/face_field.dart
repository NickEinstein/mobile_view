part of 'adoption_form_page.dart';

/// "Capture Applicant Face", with the front camera.
class _FaceField extends StatelessWidget {
  const _FaceField({
    required this.photoPath,
    required this.onCaptured,
    this.label,
    this.optional = true,
    this.errorText,
  });

  final String? photoPath;

  /// Defaults to "Capture Applicant Face".
  final String? label;
  final bool optional;
  final String? errorText;

  /// Receives the camera's temporary file, to store privately.
  final Future<void> Function(String capturedPath) onCaptured;

  Future<void> _capture(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        // Enough for identification; keeps uploads small.
        maxWidth: 1080,
        imageQuality: 85,
      );
      if (photo != null) await onCaptured(photo.path);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.brCameraFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final captured = photoPath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(
          label: label ?? l10n.brCaptureFace,
          note: optional ? l10n.brOptional : null,
        ),
        const SizedBox(height: Spacing.sm),
        Material(
          color: captured ? AppPalette.selectedCardFill : AppPalette.fieldFill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: errorText != null
                  ? Theme.of(context).colorScheme.error
                  : captured
                  ? AppPalette.brand
                  : Colors.transparent,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => unawaited(_capture(context)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      captured ? l10n.brFaceCaptured : l10n.brCapture,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppPalette.brand,
                      ),
                    ),
                  ),
                  if (captured) ...[
                    Text(
                      l10n.brRecapture,
                      style: textTheme.labelSmall?.copyWith(
                        color: AppPalette.brand,
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    const Icon(
                      Icons.refresh,
                      size: 18,
                      color: AppPalette.brand,
                    ),
                  ] else
                    const Icon(Icons.photo_camera, color: AppPalette.brand),
                ],
              ),
            ),
          ),
        ),
        if (errorText case final error?)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: Spacing.xs),
            child: Text(
              error,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
