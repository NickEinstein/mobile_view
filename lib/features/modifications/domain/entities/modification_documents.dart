import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

/// Supporting documents for a date of birth change. [apiValue] is the
/// document's `type` in the request.
enum ModificationDocument {
  dateOfBirthAffidavit('date-of-birth-affidavit'),
  requestLetter('request-letter'),
  medicalRecord('medical-record'),
  schoolRecord('school-record'),
  credibleWitnessAffidavit('affidavit-from-credible-witness');

  const ModificationDocument(this.apiValue);

  final String apiValue;

  bool get isRequired => this == dateOfBirthAffidavit || this == requestLetter;
}

/// A document sent with an earlier request (a queried one), already in
/// storage under [key].
final class UploadedFile extends Equatable {
  const UploadedFile({required this.key, required this.mimeType});

  final String key;
  final String mimeType;

  @override
  List<Object?> get props => [key, mimeType];
}

/// The documents: new photos ([files], JPEG/PNG up to 5 MB) and a queried
/// request's earlier ones ([uploaded]).
final class ModificationDocuments extends Equatable {
  const ModificationDocuments([
    this.files = const {},
    this.uploaded = const {},
  ]);

  final Map<ModificationDocument, AttachedFile> files;
  final Map<ModificationDocument, UploadedFile> uploaded;

  AttachedFile? operator [](ModificationDocument type) => files[type];

  bool has(ModificationDocument type) =>
      files.containsKey(type) || uploaded.containsKey(type);

  bool get isComplete => ModificationDocument.values.every(
    (type) => !type.isRequired || has(type),
  );

  bool isMissing(ModificationDocument type) => type.isRequired && !has(type);

  /// Why [file] can't be attached, or null.
  static DocumentError? check(AttachedFile file) {
    final dot = file.name.lastIndexOf('.');
    final extension = dot < 0 ? '' : file.name.substring(dot + 1);
    if (!SupportingDocuments.allowedExtensions.contains(
      extension.toLowerCase(),
    )) {
      return DocumentError.unsupportedType;
    }
    if (file.sizeBytes > SupportingDocuments.maxBytes) {
      return DocumentError.tooLarge;
    }
    return null;
  }

  /// [file] in place of whatever [type] had (null removes it).
  ModificationDocuments withFile(
    ModificationDocument type,
    AttachedFile? file,
  ) => ModificationDocuments(
    {
      for (final entry in files.entries)
        if (entry.key != type) entry.key: entry.value,
      type: ?file,
    },
    {
      for (final entry in uploaded.entries)
        if (entry.key != type) entry.key: entry.value,
    },
  );

  @override
  List<Object?> get props => [files, uploaded];
}
