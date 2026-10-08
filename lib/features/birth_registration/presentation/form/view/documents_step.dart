part of 'registration_form_page.dart';

/// Step 5 "Upload Documents": a photo of each supporting document.
class _DocumentsStep extends StatelessWidget {
  const _DocumentsStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _FieldColumn(
      header: _StepTitle(
        title: l10n.brStepDocuments,
        hint: l10n.brStepDocumentsHint,
      ),
      fields: [
        for (final type in context.select(
          (RegistrationFormCubit cubit) => cubit.state.draft!.documentTypes,
        ))
          _DocumentTile(type: type),
      ],
    );
  }
}

/// "60 KB", "1.2 MB".
String _fileSize(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).ceil()} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.type});

  final DocumentType type;

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<RegistrationFormCubit>();
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
        type,
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final formState = context.watch<RegistrationFormCubit>().state;
    final draft = formState.draft!;
    final file = draft.documents[type];
    final missing = formState.showErrors && draft.isDocumentMissing(type);
    final label = type.label(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: missing
                  ? theme.colorScheme.error
                  : file != null
                  ? AppPalette.selectedCardBorder
                  : AppPalette.cardBorder,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => unawaited(_pick(context)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: 14,
              ),
              child: file == null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.file_upload_outlined,
                          color: AppPalette.muted,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Flexible(
                          child: Column(
                            children: [
                              Text(
                                l10n.brUploadDocument(label),
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppPalette.ink,
                                ),
                              ),
                              Text(
                                draft.isDocumentRequired(type)
                                    ? l10n.brDocRequiredNote
                                    : l10n.brDocOptionalNote,
                                textAlign: TextAlign.center,
                                style: textTheme.labelSmall?.copyWith(
                                  color: AppPalette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          color: AppPalette.brand,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppPalette.inkStrong,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${file.name} · ${_fileSize(file.sizeBytes)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.labelSmall?.copyWith(
                                  color: AppPalette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.brRemoveDocument(label),
                          color: AppPalette.ink,
                          onPressed: () => unawaited(
                            context
                                .read<RegistrationFormCubit>()
                                .documentRemoved(type),
                          ),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (missing)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: Spacing.xs),
            child: Text(
              l10n.brRequired,
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
