part of 'foreign_birth_form_page.dart';

/// Step 5, "Upload Documents": the foreign birth certificate.
class _DocumentsStep extends StatelessWidget {
  const _DocumentsStep();

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<ForeignBirthFormCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.brTakePhoto),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.brChooseFromGallery),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        // Readable when printed, and well under the size limit.
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (image == null) return;
      final error = await cubit.certificatePicked(
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
      messenger.showSnackBar(SnackBar(content: Text(l10n.brPickFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ForeignBirthFormCubit>();
    final state = context.watch<ForeignBirthFormCubit>().state;
    final file = state.draft!.certificate;
    final label = l10n.fbDocCertificate;

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.brStepDocuments,
        hint: l10n.fbDocumentsHint,
      ),
      fields: [
        AppUploadTile(
          label: label,
          uploadLabel: label,
          note: l10n.brDocRequiredNote,
          onPick: () => unawaited(_pick(context)),
          removeLabel: l10n.brRemoveDocument(label),
          fileName: file?.name,
          fileDetail: file == null ? null : _fileSize(file.sizeBytes),
          onRemove: () => unawaited(cubit.certificateRemoved()),
          errorText: state.showErrors && file == null ? l10n.brRequired : null,
        ),
      ],
    );
  }
}

/// "60 KB", "1.2 MB".
String _fileSize(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).ceil()} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
