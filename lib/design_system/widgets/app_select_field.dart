import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';

/// Labelled dropdown, styled like [AppTextField]: label above, filled box,
/// green outline once chosen. [items] maps value → shown text.
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    required this.label,
    required this.hint,
    required this.items,
    required this.value,
    required this.onChanged,
    this.optionalLabel,
    this.errorText,
    super.key,
  });

  final String label;

  /// Small grey note after the label, e.g. "(Optional)".
  final String? optionalLabel;
  final String hint;
  final Map<T, String> items;
  final T? value;

  /// Null disables the field (e.g. no state chosen yet for an LGA).
  final ValueChanged<T?>? onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = value != null && items.containsKey(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label: label, note: optionalLabel),
        const SizedBox(height: Spacing.sm),
        DropdownButtonFormField<T>(
          key: ValueKey(value),
          initialValue: chosen ? value : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppPalette.ink),
          hint: Text(hint, style: const TextStyle(color: AppPalette.muted)),
          items: [
            for (final MapEntry(:key, value: text) in items.entries)
              DropdownMenuItem(value: key, child: Text(text)),
          ],
          onChanged: onChanged,
          decoration: InputDecoration(
            errorText: errorText,
            enabledBorder: chosen
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Field label with an optional small grey note, as used across the forms.
class FieldLabel extends StatelessWidget {
  const FieldLabel({
    required this.label,
    this.note,
    this.markRequired = false,
    super.key,
  });

  final String label;
  final String? note;

  /// Adds a red asterisk, where the designs show one.
  final bool markRequired;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final note = this.note;
    return Text.rich(
      TextSpan(
        text: label,
        children: [
          if (markRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppPalette.danger),
            ),
          if (note != null)
            TextSpan(
              text: ' $note',
              style: textTheme.labelSmall?.copyWith(color: AppPalette.muted),
            ),
        ],
      ),
      style: textTheme.bodyMedium?.copyWith(
        color: AppPalette.inkStrong,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
