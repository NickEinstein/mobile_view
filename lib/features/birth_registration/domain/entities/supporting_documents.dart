import 'package:equatable/equatable.dart';

/// Step 5 uploads, in form order. [apiType] is the document type the
/// API stores.
enum DocumentType {
  immunizationCard('immunization-card'),
  birthNotification('notification-of-birth'),
  lgaBirthCertificate('lga-birth-certificate'),
  // Sic: the API spells it so.
  baptismalCard('baptisim-card'),
  idCard('valid-id'),

  /// Asked only when that parent isn't Nigerian, and then required.
  fatherPassport('father-national-passport'),
  motherPassport('mother-national-passport');

  const DocumentType(this.apiType);

  final String apiType;

  /// Required whoever the parents are.
  bool get isRequired => this == immunizationCard || this == birthNotification;

  bool get isPassport => this == fatherPassport || this == motherPassport;
}

enum DocumentError { tooLarge, unsupportedType }

/// A file kept in app-private storage for the draft.
final class AttachedFile extends Equatable {
  const AttachedFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  static AttachedFile? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final (path, name, size) = (json['path'], json['name'], json['sizeBytes']);
    if (path is! String || name is! String || size is! int) return null;
    return AttachedFile(path: path, name: name, sizeBytes: size);
  }

  final String path;

  /// As the user's device named it, for display.
  final String name;
  final int sizeBytes;

  Map<String, Object?> toJson() => {
    'path': path,
    'name': name,
    'sizeBytes': sizeBytes,
  };

  @override
  List<Object?> get props => [path, name, sizeBytes];
}

/// "Upload Documents".
final class SupportingDocuments extends Equatable {
  const SupportingDocuments([this.files = const {}]);

  factory SupportingDocuments.fromJson(Object? json) => SupportingDocuments({
    if (json is Map<String, Object?>)
      for (final type in DocumentType.values)
        type: ?AttachedFile.fromJson(json[type.name]),
  });

  static const maxBytes = 5 * 1024 * 1024;
  static const allowedExtensions = {'jpg', 'jpeg', 'png'};

  final Map<DocumentType, AttachedFile> files;

  AttachedFile? operator [](DocumentType type) => files[type];

  /// Why a file named [name] of [sizeBytes] can't be attached, if it can't.
  static DocumentError? check(String name, int sizeBytes) {
    final dot = name.lastIndexOf('.');
    final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      return DocumentError.unsupportedType;
    }
    if (sizeBytes > maxBytes) return DocumentError.tooLarge;
    return null;
  }

  SupportingDocuments set(DocumentType type, AttachedFile? file) {
    final next = Map<DocumentType, AttachedFile>.of(files);
    if (file == null) {
      next.remove(type);
    } else {
      next[type] = file;
    }
    return SupportingDocuments(next);
  }

  bool isMissing(DocumentType type) => type.isRequired && files[type] == null;

  bool get isComplete => !DocumentType.values.any(isMissing);

  Map<String, Object?> toJson() => {
    for (final MapEntry(:key, :value) in files.entries)
      key.name: value.toJson(),
  };

  @override
  List<Object?> get props => [files];
}
