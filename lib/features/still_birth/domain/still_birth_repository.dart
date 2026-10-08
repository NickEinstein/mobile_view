import 'dart:typed_data';

import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_draft.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_record.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_reference_data.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_summary.dart';

/// Still Birth Registration: no payment, NIN or documents.
abstract interface class StillBirthRepository {
  /// "Total Registration".
  Future<Result<int>> count();

  /// Registered still births, optionally filtered by name.
  Future<Result<List<StillBirthSummary>>> registrations({String query = ''});

  /// One registration, with everything recorded for it.
  Future<Result<StillBirthRecord>> details(String id);

  /// The form's lists, with the LGAs of the states in [withLgasOf].
  Future<Result<StillBirthReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  });

  /// The registration in progress on this device, if any.
  Future<StillBirthDraft?> loadDraft();

  Future<void> saveDraft(StillBirthDraft draft);

  /// Whether an unfinished registration is worth resuming.
  Future<bool> hasResumableDraft();

  /// Deletes the unfinished registration and its signature.
  Future<void> discardDraft();

  /// Stores a drawn signature (PNG) privately and returns its path.
  /// [replacing] is deleted.
  Future<String> keepSignature(Uint8List png, {String? replacing});

  Future<void> deleteFile(String path);

  /// Uploads the signature and sends the registration. Returns its
  /// tracking ID when the server gives one.
  Future<Result<String?>> submit(StillBirthDraft draft);
}
