part of 'birth_reissuance_form_page.dart';

/// Step 4, "Supporting Documents": one optional
/// document and the parent's signature (required).
class _DocumentsStep extends StatelessWidget {
  const _DocumentsStep({required this.pickPhoto});

  final PickPhoto pickPhoto;

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<BirthReissuanceFormCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final image = await pickPhoto(context);
      if (image == null) return;
      final error = await cubit.documentPicked(
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

  Future<void> _saveSignature(BuildContext context, Uint8List png) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.brSignatureFailed;
    try {
      await context.read<BirthReissuanceFormCubit>().signatureDrawn(png);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BirthReissuanceFormCubit>();
    final state = context.watch<BirthReissuanceFormCubit>().state;
    final form = state.form!;
    final document = form.document;
    final signature = form.signature;

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.crStepDocuments,
        hint: l10n.crStepDocumentsHint,
      ),
      fields: [
        AppUploadTile(
          label: l10n.crSupportingDocument,
          uploadLabel: l10n.crUploadDocument,
          note: l10n.crDocumentNote,
          removeLabel: l10n.brRemoveDocument(l10n.crSupportingDocument),
          fileName:
              document?.name ??
              (form.keptDocument == null ? null : l10n.crSupportingDocument),
          fileDetail: document == null
              ? (form.keptDocument == null ? null : l10n.crKeptDocument)
              : '${document.name} · ${fileSize(document.sizeBytes)}',
          onPick: () => unawaited(_pick(context)),
          onRemove: form.hasDocument
              ? () => unawaited(cubit.documentRemoved())
              : null,
        ),
        AppSignaturePad(
          key: const ValueKey('signature'),
          label: l10n.crParentSignature,
          hint: l10n.brSignHere,
          clearTooltip: l10n.brClearSignature,
          saved: signature == null ? null : FileImage(File(signature)),
          onSigned: (png) => unawaited(_saveSignature(context, png)),
          onCleared: () => unawaited(cubit.signatureCleared()),
          errorText: state.showErrors && !form.hasSignature
              ? l10n.crSignatureRequired
              : null,
        ),
        if (signature == null && form.keptSignature != null)
          Text(
            l10n.crKeptSignature,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppPalette.muted),
          ),
      ],
    );
  }
}
