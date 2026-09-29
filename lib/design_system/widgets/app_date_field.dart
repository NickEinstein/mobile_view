import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';

/// Labelled date picker shown as DD/MM/YYYY with a calendar icon.
class AppDateField extends StatelessWidget {
  const AppDateField({
    required this.label,
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final String label;
  final DateTime? value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;

  /// False shows the date without letting it change.
  final bool enabled;

  static final _format = DateFormat('dd/MM/yyyy');

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? lastDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = this.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label: label),
        const SizedBox(height: Spacing.sm),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? () => unawaited(_pick(context)) : null,
          child: InputDecorator(
            isEmpty: value == null,
            decoration: InputDecoration(
              enabled: enabled,
              hintText: 'DD/MM/YYYY',
              errorText: errorText,
              suffixIcon: const Icon(
                Icons.calendar_month_outlined,
                color: AppPalette.muted,
              ),
              enabledBorder: value != null && enabled
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    )
                  : null,
            ),
            child: value == null ? null : Text(_format.format(value)),
          ),
        ),
      ],
    );
  }
}
