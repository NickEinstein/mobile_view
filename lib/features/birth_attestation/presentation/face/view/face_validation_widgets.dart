part of 'face_validation_page.dart';

/// The green "Guidelines" card.
class _Guidelines extends StatelessWidget {
  const _Guidelines();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Colors.white);
    final guides = [
      (Icons.visibility_outlined, l10n.baGuideEyeLevel),
      (Icons.center_focus_strong_outlined, l10n.baGuideCentred),
      (Icons.wb_sunny_outlined, l10n.baGuideLit),
      (Icons.sentiment_neutral_outlined, l10n.baGuideNeutral),
      (Icons.masks_outlined, l10n.baGuideNoCover),
      (Icons.pan_tool_outlined, l10n.baGuideStill),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.brand,
        borderRadius: BorderRadius.circular(Spacing.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.baFaceGuidelines.toUpperCase(),
              textAlign: TextAlign.center,
              style: style?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.sm),
            for (final (icon, text) in guides)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: Spacing.md),
                    Expanded(child: Text(text, style: style)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The ringed circle: empty until a photo is taken (tap it to take one),
/// then the photo. Below it, what to do or what went wrong.
class _CaptureStage extends StatelessWidget {
  const _CaptureStage({required this.onCapture});

  final VoidCallback onCapture;

  static const _photoSize = 200.0;
  static const _ringSize = 260.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<FaceValidationCubit>().state;
    final photo = state.photoPath;
    final failure = state.failure;
    final error = state.missingApplication
        ? l10n.baNoApplication
        : state.notMatched
        ? l10n.baFaceNotMatched
        : failure?.localize(l10n);

    return ListView(
      children: [
        Center(
          child: SizedBox.square(
            dimension: _ringSize,
            child: CustomPaint(
              painter: const _TickRing(),
              child: Center(
                child: Semantics(
                  button: photo == null,
                  label: l10n.baTakePhoto,
                  child: GestureDetector(
                    onTap: photo == null ? onCapture : null,
                    child: Container(
                      width: _photoSize,
                      height: _photoSize,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppPalette.fieldFill,
                        border: Border.all(color: AppPalette.brand, width: 2),
                      ),
                      child: photo == null
                          ? const Icon(
                              Icons.photo_camera_outlined,
                              size: 40,
                              color: AppPalette.brand,
                            )
                          : Image.file(File(photo), fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        Text(
          l10n.baFacePosition,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppPalette.ink),
        ),
        if (error != null) ...[
          const SizedBox(height: Spacing.md),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

/// The short radial ticks around the photo, as in the design.
class _TickRing extends CustomPainter {
  const _TickRing();

  static const _ticks = 120;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer - 18;
    final paint = Paint()
      ..color = AppPalette.cardBorder
      ..strokeWidth = 1.5;
    for (var i = 0; i < _ticks; i++) {
      final angle = 2 * math.pi * i / _ticks;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * inner,
        center + direction * outer,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TickRing oldDelegate) => false;
}
