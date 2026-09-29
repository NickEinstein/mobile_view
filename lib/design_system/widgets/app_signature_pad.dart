import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';

/// A signature pad. Each stroke hands the signature to [onSigned] as a PNG.
class AppSignaturePad extends StatefulWidget {
  const AppSignaturePad({
    required this.label,
    required this.hint,
    required this.clearTooltip,
    required this.saved,
    required this.onSigned,
    required this.onCleared,
    this.errorText,
    super.key,
  });

  final String label;

  /// Shown in the empty box, e.g. "Sign here".
  final String hint;
  final String clearTooltip;
  final ImageProvider? saved;
  final ValueChanged<Uint8List> onSigned;
  final VoidCallback onCleared;
  final String? errorText;

  @override
  State<AppSignaturePad> createState() => _AppSignaturePadState();
}

class _AppSignaturePadState extends State<AppSignaturePad> {
  static const _height = 140.0;
  static const _strokeWidth = 2.5;

  /// Strokes drawn since the pad was last cleared.
  final _strokes = <List<Offset>>[];
  Size _size = Size.zero;

  bool get _showsSaved => _strokes.isEmpty && widget.saved != null;

  void _clear() {
    setState(_strokes.clear);
    widget.onCleared();
  }

  Offset _clamp(Offset point) =>
      Offset(point.dx.clamp(0, _size.width), point.dy.clamp(0, _size.height));

  Future<void> _export(double pixelRatio) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    _SignaturePainter(_strokes).paint(canvas, _size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (_size.width * pixelRatio).ceil(),
      (_size.height * pixelRatio).ceil(),
    );
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes != null && mounted) {
      widget.onSigned(bytes.buffer.asUint8List());
    }
  }

  void Function(_ImmediatePanRecognizer) _configure(double pixelRatio) =>
      (recognizer) => recognizer
        ..onStart = _startStroke
        ..onUpdate = _continueStroke
        ..onEnd = (_) => unawaited(_export(pixelRatio));

  void _startStroke(DragStartDetails details) =>
      setState(() => _strokes.add([_clamp(details.localPosition)]));

  void _continueStroke(DragUpdateDetails details) =>
      setState(() => _strokes.last.add(_clamp(details.localPosition)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorText = widget.errorText;
    final saved = widget.saved;
    final signed = _strokes.isNotEmpty || saved != null;
    final pixelRatio = MediaQuery.devicePixelRatioOf(
      context,
    ).clamp(1.0, 3.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FieldLabel(label: widget.label, markRequired: true),
            ),
            IconButton(
              tooltip: widget.clearTooltip,
              visualDensity: VisualDensity.compact,
              color: AppPalette.inkStrong,
              onPressed: signed ? _clear : null,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
        Container(
          height: _height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppPalette.fieldFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: errorText != null
                  ? theme.colorScheme.error
                  : signed
                  ? AppPalette.brand
                  : Colors.transparent,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _size = constraints.biggest;
              if (_showsSaved && saved != null) {
                return Semantics(
                  label: widget.label,
                  image: true,
                  child: Image(image: saved, fit: BoxFit.contain),
                );
              }
              return Semantics(
                label: widget.label,
                hint: widget.hint,
                child: RawGestureDetector(
                  // Claim the pointer at once, so drawing doesn't scroll
                  // the form.
                  gestures: {
                    _ImmediatePanRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          _ImmediatePanRecognizer
                        >(_ImmediatePanRecognizer.new, _configure(pixelRatio)),
                  },
                  child: CustomPaint(
                    painter: _SignaturePainter(_strokes),
                    child: _strokes.isEmpty
                        ? Center(
                            child: Text(
                              widget.hint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppPalette.muted,
                              ),
                            ),
                          )
                        : const SizedBox.expand(),
                  ),
                ),
              );
            },
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

/// Wins the gesture arena as soon as a finger touches the pad.
class _ImmediatePanRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppPalette.inkStrong
      ..strokeWidth = _AppSignaturePadState._strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke, paint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  // The strokes list grows in place, so always repaint.
  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
