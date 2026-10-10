import 'dart:typed_data';

import 'package:vital_reg_mobile/core/network/cancellation.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/storage/outbox.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/applications_source.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/application_details.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

/// A surname and first name, as an identity record has them.
typedef PersonName = ({String surname, String firstName});

abstract interface class BirthRegistrationRepository
    implements ApplicationsSource {
  /// One submitted application, with everything recorded for it.
  Future<Result<ApplicationDetails>> details(String id);

  /// Looks up the child's 11-digit NIN with the identity service (through
  /// our API). A `NotFoundFailure` when it has no record.
  Future<Result<ApplicantNinRecord>> verifyNin(String nin);

  /// The name registered under an informant's 15-character NIN tracking ID.
  /// A `NotFoundFailure` when it has none.
  Future<Result<PersonName>> verifyTrackingId(String trackingId);

  /// The registration fee, due from age 5 (see
  /// `ChildParticulars.needsPaymentOn`).
  PaymentSource get payments;

  /// The form's lists, with the LGAs of the states in [withLgasOf].
  Future<Result<ReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  });

  /// The application in progress on this device, if any.
  Future<RegistrationDraft?> loadDraft();

  Future<void> saveDraft(RegistrationDraft draft);

  /// Moves a captured photo into private storage; deletes [replacing].
  Future<String> keepPhoto(String capturedPath, {String? replacing});

  /// Stores a drawn signature (PNG) privately and returns its path.
  /// [replacing] is the previous signature, which is deleted.
  Future<String> keepSignature(Uint8List png, {String? replacing});

  /// Moves a picked document into private storage; deletes [replacing].
  Future<String> keepDocument(String pickedPath, {String? replacing});

  /// Uploads the files, then sends the application. Returns its certificate
  /// number, if given. Files in [uploaded] (storage keys by local path) are
  /// sent by key; each new upload is reported to [onUploaded].
  Future<Result<String?>> submit(
    RegistrationDraft draft, {
    void Function(int sent, int total)? onProgress,
    Cancellation? cancellation,
    Map<String, String> uploaded = const {},
    void Function(String path, String key)? onUploaded,
  });

  /// Sends a queried record's correction; only replaced files are uploaded.
  Future<Result<void>> updateQueried(
    RegistrationDraft draft, {
    void Function(int sent, int total)? onProgress,
    Cancellation? cancellation,
  });

  /// Deletes a photo, signature or document the draft no longer uses.
  Future<void> deleteFile(String path);

  /// Offline mode: moves the finished draft, with its files, to the
  /// outbox to be sent later.
  Future<void> saveForLater(RegistrationDraft draft);

  /// Applications saved to send later, oldest first.
  Future<List<OutboxEntry<RegistrationDraft>>> outbox();

  /// Saves an edited outbox application, ready to be sent again. Files
  /// it no longer uses are deleted.
  Future<void> replaceInOutbox(String id, RegistrationDraft draft);

  /// Saves an outbox entry's new status or progress.
  Future<void> updateOutbox(OutboxEntry<RegistrationDraft> entry);

  /// Deletes an outbox entry and its files.
  Future<void> removeFromOutbox(String id);
}
