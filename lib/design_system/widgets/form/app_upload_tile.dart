import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';

/// "Upload …" box; once a file is attached, its name and size with a
/// remove button, outlined in green, as the designs draw it.
class AppUploadTile extends StatelessWidget {
  const AppUploadTile({
    required this.label,
    required this.uploadLabel,
    required this.note,
    required this.onPick,
    required this.removeLabel,
    this.fileName,
    this.fileDetail,
    this.onRemove,
    this.errorText,
    super.key,
  });

  /// The document's name, shown once attached.
  final String label;

  /// "Upload Court Affidavit".
  final String uploadLabel;

  /// "Required · jpeg/png only".
  final String note;
  final VoidCallback onPick;

  /// The remove button's tooltip.
  final String removeLabel;

  /// Null until a file is attached.
  final String? fileName;

  /// "my-affidavit.jpg · 60 KB".
  final String? fileDetail;

  /// Null hides the remove button (e.g. a file already on the server).
  final VoidCallback? onRemove;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final attached = fileName != null;
    final errorText = this.errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: errorText != null
                  ? theme.colorScheme.error
                  : attached
                  ? AppPalette.selectedCardBorder
                  : AppPalette.cardBorder,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPick,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: 14,
              ),
              child: !attached
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
                                uploadLabel,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppPalette.ink,
                                ),
                              ),
                              Text(
                                note,
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
                              if (fileDetail case final detail?)
                                Text(
                                  detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: AppPalette.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (onRemove != null)
                          IconButton(
                            tooltip: removeLabel,
                            color: AppPalette.ink,
                            onPressed: onRemove,
                            icon: const Icon(Icons.close),
                          ),
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
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// The yellow "I hereby certify…" box with its checkbox.
class AppDeclaration extends StatelessWidget {
  const AppDeclaration({
    required this.text,
    required this.declared,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  final String text;
  final bool declared;
  final ValueChanged<bool> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorText = this.errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppPalette.warningContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: errorText != null
                  ? theme.colorScheme.error
                  : AppPalette.accentYellow,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(!declared),
            child: MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: declared,
                      visualDensity: VisualDensity.compact,
                      onChanged: (value) => onChanged(value ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: Spacing.sm),
                        child: Text(
                          text,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppPalette.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: Spacing.xs),
            child: Text(
              errorText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
