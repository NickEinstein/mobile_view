import 'dart:typed_data';

import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_draft.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_form.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_record.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_reference_data.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/applications_source.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

/// Adopted Child Registration: the server creates the application, and
/// each step is saved there as the registrar goes.
abstract interface class AdoptedChildRepository implements ApplicationsSource {
  /// Creates the application on the server; returns its reference id.
  Future<Result<String>> initiate();

  /// What the identity service holds for [nin]. `NotFoundFailure` when it
  /// has no record.
  Future<Result<ApplicantNinRecord>> lookupNin(String nin);

  /// Records the verified child NIN against the application.
  Future<Result<void>> verifyChildNin({
    required String referenceId,
    required String nin,
  });

  /// Records that the child has no NIN yet (a temporary birth
  /// notification follows).
  Future<Result<void>> skipChildNin(String referenceId);

  /// The adopted child registration fee.
  PaymentSource get payments;

  /// Attaches a paid [reference] to the application.
  Future<Result<void>> attachPayment({
    required String referenceId,
    required String reference,
  });

  /// The form's lists, with the LGAs of the states in [withLgasOf].
  Future<Result<AdoptionReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  });

  /// Saves [section] on the server, uploading any file not yet uploaded.
  /// Returns the draft with those uploads recorded.
  Future<Result<AdoptionDraft>> saveSection(
    AdoptionDraft draft,
    AdoptionSection section,
  );

  /// The registration in progress on this device, if any.
  Future<AdoptionDraft?> loadDraft();

  Future<void> saveDraft(AdoptionDraft draft);

  /// Stores a camera photo privately and returns its path. [replacing] is
  /// deleted.
  Future<String> keepPhoto(String capturedPath, {String? replacing});

  /// Stores a drawn signature (PNG) privately and returns its path.
  Future<String> keepSignature(Uint8List png, {String? replacing});

  /// Stores a picked document privately and returns its path.
  Future<String> keepDocument(String pickedPath, {String? replacing});

  Future<void> deleteFile(String path);

  /// One application, for "Certificate Details" or a query response.
  Future<Result<AdoptionRecord>> details(String id);

  /// Applications started but not submitted (on any device).
  Future<Result<List<BirthApplicationSummary>>> drafts();

  /// A saved draft, with how far it got.
  Future<Result<AdoptionRecord>> resume(String referenceId);

  /// Resends a queried application, corrected. Uploads any new file first.
  Future<Result<void>> amend(AdoptionDraft draft);

  /// Finalises the application; every section is already saved. Returns
  /// a tracking number when the server gives one.
  Future<Result<String?>> submit(String referenceId);
}
