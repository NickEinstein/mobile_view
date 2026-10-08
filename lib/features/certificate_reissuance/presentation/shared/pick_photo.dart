import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Picks a photo; null if cancelled. Tests pass their own.
typedef PickPhoto = Future<XFile?> Function(BuildContext context);

/// A photo of a document, from the camera or the gallery; null if
/// cancelled.
Future<XFile?> pickPhotoFromDevice(BuildContext context) async {
  final l10n = context.l10n;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.brTakePhoto),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.brChooseFromGallery),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  return ImagePicker().pickImage(
    source: source,
    // Readable when printed, and well under the size limit.
    maxWidth: 2000,
    imageQuality: 85,
  );
}

/// "60 KB", "1.2 MB".
String fileSize(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).ceil()} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
