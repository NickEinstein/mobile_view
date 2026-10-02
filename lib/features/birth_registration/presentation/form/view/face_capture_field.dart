part of 'registration_form_page.dart';

/// "Capture Applicant Face": opens the front camera. After a capture it
/// reads "Face captured successfully" with a Recapture action.
class _FaceCaptureField extends StatelessWidget {
  const _FaceCaptureField({
    required this.photoPath,
    required this.onCaptured,
    this.errorText,
    super.key,
  });

  final String? photoPath;

  /// Receives the camera's temporary file, to store privately.
  final Future<void> Function(String capturedPath) onCaptured;
  final String? errorText;

  Future<void> _capture(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
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
    final errorText = this.errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label: l10n.brCaptureFace),
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
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: Spacing.xs),
            child: Text(
              errorText,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
