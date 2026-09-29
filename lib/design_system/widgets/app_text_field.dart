import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Labelled text field; with [obscureText], a password field with a toggle.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    required this.onChanged,
    this.optionalLabel,
    this.initialValue,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.onSubmitted,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    super.key,
  });

  final String label;

  /// Small grey note after the label, e.g. "(Optional)".
  final String? optionalLabel;

  /// Starting text, e.g. from a saved draft. Read once.
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  /// More than 1 makes a comment box.
  final int maxLines;
  final int? maxLength;

  /// False shows the value read-only, e.g. a name taken from a NIN record.
  final bool enabled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  late bool _obscured = widget.obscureText;
  late bool _hasText = _controller.text.isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_hasText != value.isNotEmpty) {
      setState(() => _hasText = value.isNotEmpty);
    }
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final filledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.primary),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label: widget.label, note: widget.optionalLabel),
        const SizedBox(height: Spacing.sm),
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          onChanged: _onChanged,
          onSubmitted: widget.onSubmitted,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          inputFormatters: widget.inputFormatters,
          autofillHints: widget.autofillHints,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            hintText: widget.hintText,
            errorText: widget.errorText,
            enabledBorder: _hasText ? filledBorder : null,
            suffixIcon: widget.obscureText
                ? IconButton(
                    tooltip: _obscured ? l10n.showPassword : l10n.hidePassword,
                    color: AppPalette.muted,
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
