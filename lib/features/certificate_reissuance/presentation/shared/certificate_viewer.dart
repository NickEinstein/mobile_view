import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "Download": the reissued certificate, full screen, with pinch to zoom.
Future<void> showCertificate(
  BuildContext context, {
  required Future<Result<Uint8List>> image,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _CertificateViewer(image: image),
  ),
);

class _CertificateViewer extends StatelessWidget {
  const _CertificateViewer({required this.image});

  final Future<Result<Uint8List>> image;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.crCertificateImage)),
      body: FutureBuilder(
        future: image,
        builder: (context, snapshot) => switch (snapshot.data) {
          null => const Center(child: CircularProgressIndicator()),
          Ok(:final value) => InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Image.memory(
                value,
                semanticLabel: l10n.crCertificateImage,
                errorBuilder: (_, _, _) => Text(l10n.errorUnexpected),
              ),
            ),
          ),
          Err(:final failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text(failure.localize(l10n), textAlign: TextAlign.center),
            ),
          ),
        },
      ),
    );
  }
}
