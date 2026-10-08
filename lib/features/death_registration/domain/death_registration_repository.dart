import 'dart:typed_data';

import 'package:vital_reg_mobile/core/network/cancellation.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/applications_source.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_draft.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_record.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_reference_data.dart';

/// Death Registration: the deceased, the informant, documents, then the
/// preview, where the informant signs. No payment.
abstract interface class DeathRegistrationRepository
    implements ApplicationsSource {
  /// Looks a NIN up with the identity service.
  Future<Result<ApplicantNinRecord>> verifyNin(String nin);

  /// One registration, with everything recorded for it.
  Future<Result<DeathRecord>> details(String id);

  /// Sends the corrections to a queried record ([DeathDraft.queried]),
  /// uploading only the replaced files.
  Future<Result<void>> updateQueried(DeathDraft draft);

  /// The form's lists, with the LGAs of the states in [withLgasOf].
  Future<Result<DeathReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  });

  /// The registration in progress on this device, if any.
  Future<DeathDraft?> loadDraft();

  Future<void> saveDraft(DeathDraft draft);

  /// Stores a drawn signature (PNG) privately and returns its path.
  /// [replacing] is deleted.
  Future<String> keepSignature(Uint8List png, {String? replacing});

  /// Moves a picked document into private storage and returns its new
  /// path. [replacing] is deleted.
  Future<String> keepDocument(String pickedPath, {String? replacing});

  Future<void> deleteFile(String path);

  /// Uploads the files, then sends the registration. Returns its tracking
  /// ID, if given.
  Future<Result<String?>> submit(
    DeathDraft draft, {
    void Function(int done, int total)? onProgress,
    Cancellation? cancellation,
  });
}
