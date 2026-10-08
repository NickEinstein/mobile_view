import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';

/// One-time code input drawn as boxes over one hidden field, so paste and
/// autofill work.
class AppCodeField extends StatefulWidget {
  const AppCodeField({
    required this.length,
    required this.semanticLabel,
    required this.onChanged,
    this.onSubmitted,
    this.hasError = false,
    super.key,
  });

  final int length;
  final String semanticLabel;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool hasError;

  @override
  State<AppCodeField> createState() => _AppCodeFieldState();
}

class _AppCodeFieldState extends State<AppCodeField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final digitStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: AppPalette.inkStrong,
      fontWeight: FontWeight.w500,
    );

    return Stack(
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([_controller, _focusNode]),
          builder: (context, _) {
            final code = _controller.text;
            return Row(
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: Spacing.sm + Spacing.xs),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppPalette.fieldFill,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.hasError
                                ? scheme.error
                                : i < code.length ||
                                      (_focusNode.hasFocus && i == code.length)
                                ? scheme.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            i < code.length ? code[i] : '',
                            style: digitStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        Positioned.fill(
          child: Semantics(
            label: widget.semanticLabel,
            child: Opacity(
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                // Fill the boxes so a tap anywhere on them opens the keyboard.
                expands: true,
                maxLines: null,
                showCursor: false,
                enableInteractiveSelection: false,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                decoration: const InputDecoration.collapsed(hintText: null),
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
