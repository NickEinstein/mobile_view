part of 'surrogacy_form_page.dart';

/// Step 7, "Upload Documents": a photo of each document asked for. The
/// father's identity document only when he is named.
class _DocumentsStep extends StatelessWidget {
  const _DocumentsStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SurrogacyFormCubit>();
    final state = context.watch<SurrogacyFormCubit>().state;
    final draft = state.draft!;

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.brStepDocuments,
        hint: l10n.srDocumentsHint,
      ),
      fields: [
        for (final document in draft.documentsAsked)
          _PhotoUpload(
            key: ValueKey(document),
            label: document.label(l10n),
            required: true,
            file: draft.documents[document],
            missing: state.showErrors && draft.isMissing(document),
            onPicked:
                ({
                  required String path,
                  required String name,
                  required int sizeBytes,
                }) => cubit.documentPicked(
                  document,
                  path: path,
                  name: name,
                  sizeBytes: sizeBytes,
                ),
            onRemove: () => unawaited(cubit.documentRemoved(document)),
          ),
      ],
    );
  }
}

typedef _OnPicked =
    Future<DocumentError?> Function({
      required String path,
      required String name,
      required int sizeBytes,
    });

/// "60 KB", "1.2 MB".
String _fileSize(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).ceil()} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// An upload box for a photo of a document, taken or chosen from the
/// gallery.
class _PhotoUpload extends StatelessWidget {
  const _PhotoUpload({
    required this.label,
    required this.required,
    required this.file,
    required this.onPicked,
    required this.onRemove,
    this.missing = false,
    super.key,
  });

  final String label;
  final bool required;
  final AttachedFile? file;
  final _OnPicked onPicked;
  final VoidCallback onRemove;
  final bool missing;

  Future<void> _pick(BuildContext context) async {
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
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (image == null) return;
      final error = await onPicked(
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
    final file = this.file;
    return AppUploadTile(
      label: label,
      uploadLabel: label,
      note: required ? l10n.brDocRequiredNote : l10n.brDocOptionalNote,
      onPick: () => unawaited(_pick(context)),
      removeLabel: l10n.brRemoveDocument(label),
      fileName: file?.name,
      fileDetail: file == null ? null : _fileSize(file.sizeBytes),
      onRemove: onRemove,
      errorText: missing ? l10n.brRequired : null,
    );
  }
}
