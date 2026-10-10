import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';

/// Radio choices; [options] maps value → shown text.
class AppRadioGroup<T> extends StatelessWidget {
  const AppRadioGroup({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.inline = false,
    this.vertical = false,
    this.errorText,
    super.key,
  });

  final String label;
  final Map<T, String> options;
  final T? value;

  /// Null shows the choice without letting it change.
  final ValueChanged<T>? onChanged;
  final bool inline;
  final bool vertical;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final errorText = this.errorText;
    final onChanged = this.onChanged;
    final group = RadioGroup<T>(
      groupValue: value,
      onChanged: (choice) {
        if (choice != null) onChanged?.call(choice);
      },
      child: Wrap(
        direction: vertical ? Axis.vertical : Axis.horizontal,
        spacing: vertical ? 0 : Spacing.sm,
        crossAxisAlignment: vertical
            ? WrapCrossAlignment.start
            : WrapCrossAlignment.center,
        children: [
          for (final MapEntry(:key, value: text) in options.entries)
            InkWell(
              borderRadius: BorderRadius.circular(Spacing.sm),
              onTap: onChanged == null ? null : () => onChanged(key),
              child: Padding(
                padding: const EdgeInsets.only(right: Spacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<T>(
                      value: key,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Text(
                      text,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppPalette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    final choices = onChanged == null
        ? IgnorePointer(child: Opacity(opacity: 0.6, child: group))
        : group;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inline)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Spacing.sm,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: AppPalette.inkStrong,
                ),
              ),
              choices,
            ],
          )
        else ...[
          FieldLabel(label: label),
          const SizedBox(height: Spacing.xs),
          choices,
        ],
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
