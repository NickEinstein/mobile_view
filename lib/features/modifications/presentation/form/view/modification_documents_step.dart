part of 'modification_form_page.dart';

/// "Supporting Documents", for a date of birth change.
class _DocumentsStep extends StatelessWidget {
  const _DocumentsStep({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<ModificationFormCubit>();
    final state = context.watch<ModificationFormCubit>().state;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.lg),
      children: [
        Text(
          cubit.request.kind.title(l10n),
          style: textTheme.titleLarge?.copyWith(
            color: AppPalette.inkStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Spacing.md),
        Text(
          l10n.modDocumentsTitle,
          style: textTheme.titleSmall?.copyWith(
            color: AppPalette.inkStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          l10n.modDocumentsHint,
          style: textTheme.bodySmall?.copyWith(color: AppPalette.muted),
        ),
        const SizedBox(height: Spacing.md),
        for (final type in ModificationDocument.values) ...[
          _DocumentTile(type: type),
          const SizedBox(height: Spacing.sm),
        ],
        ..._submitMessages(context, state),
      ],
    );
  }
}

class _DocumentsActions extends StatelessWidget {
  const _DocumentsActions({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ModificationFormCubit>();
    final state = context.watch<ModificationFormCubit>().state;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.inkStrong,
                ),
                onPressed: state.isSubmitting ? null : cubit.backToForm,
                child: Text(l10n.brPrevious),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: AppButton(
                label: l10n.brSubmit,
                isLoading: state.isSubmitting,
                // Looks off until the required documents are in; a tap
                // then points out what's missing.
                muted: !state.documents.isComplete,
                onPressed: () => unawaited(cubit.submitDocuments()),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: state.isSubmitting ? null : onExit,
          child: Text(l10n.brExitApplication),
        ),
      ],
    );
  }
}

extension on ModificationDocument {
  String label(AppLocalizations l10n) => switch (this) {
    ModificationDocument.dateOfBirthAffidavit =>
      l10n.modDocDateOfBirthAffidavit,
    ModificationDocument.requestLetter => l10n.modDocRequestLetter,
    ModificationDocument.medicalRecord => l10n.modDocMedicalRecord,
    ModificationDocument.schoolRecord => l10n.modDocSchoolRecord,
    ModificationDocument.credibleWitnessAffidavit =>
      l10n.modDocCredibleWitnessAffidavit,
  };
}

/// "60 KB", "1.2 MB".
String _fileSize(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).ceil()} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.type});

  final ModificationDocument type;

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<ModificationFormCubit>();
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
    final state = context.watch<ModificationFormCubit>().state;
    final file = state.documents[type];
    final kept = file == null && state.documents.uploaded.containsKey(type);
    final attached = file != null || kept;
    final missing = state.showErrors && state.documents.isMissing(type);
    final label = type.label(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Spacing.sm),
            side: BorderSide(
              color: missing
                  ? theme.colorScheme.error
                  : attached
                  ? AppPalette.selectedCardBorder
                  : AppPalette.cardBorder,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Spacing.sm),
            onTap: state.isSubmitting ? null : () => unawaited(_pick(context)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Icon(
                    attached
                        ? Icons.image_outlined
                        : Icons.file_upload_outlined,
                    color: attached ? AppPalette.brand : AppPalette.muted,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attached ? label : l10n.brUploadDocument(label),
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppPalette.inkStrong,
                          ),
                        ),
                        Text(
                          file != null
                              ? '${file.name} · ${_fileSize(file.sizeBytes)}'
                              : kept
                              ? l10n.modPreviouslySent
                              : type.isRequired
                              ? l10n.brDocRequiredNote
                              : l10n.brDocOptionalNote,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppPalette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (attached)
                    IconButton(
                      tooltip: l10n.brRemoveDocument(label),
                      color: AppPalette.ink,
                      onPressed: state.isSubmitting
                          ? null
                          : () => unawaited(
                              context
                                  .read<ModificationFormCubit>()
                                  .documentRemoved(type),
                            ),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (missing) _ErrorText(l10n.brRequired),
      ],
    );
  }
}
