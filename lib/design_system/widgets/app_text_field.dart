import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Labelled text field; with [obscureText], a password field with a toggle.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    required this.onChanged,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;
  bool _hasText = false;

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
        Text(
          widget.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppPalette.inkStrong,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        TextField(
          onChanged: _onChanged,
          onSubmitted: widget.onSubmitted,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
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
