part of 'death_form_page.dart';

/// Step 3, "Upload Documents": a photo of each. Which are required
/// depends on where the death happened (see [DeathDocument.isRequired]).
class _DocumentsStep extends StatelessWidget {
  const _DocumentsStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.brStepDocuments,
        hint: l10n.drStepDocumentsHint,
      ),
      fields: [
        for (final document in DeathDocument.values)
          _DocumentTile(key: ValueKey(document), document: document),
      ],
    );
  }
}

/// "60 KB", "1.2 MB".
String _fileSize(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).ceil()} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, super.key});

  final DeathDocument document;

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<DeathFormCubit>();
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
      final error = await cubit.documentPicked(
        document,
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
    final state = context.watch<DeathFormCubit>().state;
    final draft = state.draft!;
    final file = draft.documents[document];
    // A recorded document stays on file unless replaced.
    final onFile = file == null && draft.hasDocument(document);
    final label = document.label(l10n);
    final required = document.isRequired(
      placeOfDeath: draft.deceased[DeceasedField.placeOfDeath],
    );
    return AppUploadTile(
      label: label,
      uploadLabel: l10n.brUploadDocument(label),
      note: required ? l10n.brDocRequiredNote : l10n.brDocOptionalNote,
      removeLabel: l10n.brRemoveDocument(label),
      fileName: onFile ? label : file?.name,
      fileDetail: onFile
          ? l10n.baOnFile
          : file == null
          ? null
          : '${file.name} · ${_fileSize(file.sizeBytes)}',
      errorText: state.showErrors && required && !draft.hasDocument(document)
          ? l10n.brRequired
          : null,
      onPick: () => unawaited(_pick(context)),
      onRemove: file == null
          ? null
          : () => unawaited(
              context.read<DeathFormCubit>().documentRemoved(document),
            ),
    );
  }
}
