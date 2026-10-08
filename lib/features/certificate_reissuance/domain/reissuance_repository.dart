import 'dart:typed_data';

import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/face_source.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/attestation_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_options.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

abstract interface class ReissuanceRepository {
  Future<Result<ReissuanceCounts>> counts(ReissuanceKind kind);

  /// Requests for [kind]; [status] null is all of them. Optionally
  /// filtered by name or reference.
  Future<Result<List<ReissuanceSummary>>> requests({
    required ReissuanceKind kind,
    ReissuanceStatus? status,
    String query = '',
  });

  /// The reissuance fee. One payment covers either kind.
  PaymentSource get payments;

  /// The face of the request in progress, matched against its NIN photo.
  FaceSource get face;

  /// A `NotFoundFailure` when the NIN has no record.
  Future<Result<ApplicantNinRecord>> verifyNin(String nin);

  /// The form's fixed lists, countries and registration centres.
  Future<Result<ReissuanceOptions>> options();

  /// The states (or provinces) of the country with [countryCode].
  Future<Result<List<Option>>> states(String countryCode);

  Future<Result<List<Option>>> lgas(String stateId);

  Future<ReissuanceDraft?> loadDraft();

  Future<void> saveDraft(ReissuanceDraft draft);

  /// Deletes the draft and its files. The payment is kept.
  Future<void> discardDraft();

  /// Moves a picked certificate copy into private storage and returns its
  /// new path. [replacing] is deleted.
  Future<String> keepDocument(String pickedPath, {String? replacing});

  Future<void> deleteFile(String path);

  /// Stores a drawn signature (PNG) and returns its path. [replacing] is
  /// deleted.
  Future<String> keepSignature(Uint8List png, {String? replacing});

  /// Emails a one-time code to the recipient's address, which the preview
  /// confirms before it allows sending.
  Future<Result<void>> sendEmailCode(String email);

  Future<Result<void>> resendEmailCode(String email);

  Future<Result<void>> confirmEmailCode({
    required String email,
    required String code,
  });

  /// Uploads the files, then sends the request to [email]; clears the
  /// payment and draft once accepted.
  Future<Result<String?>> submitBirth(
    ReissuanceDraft draft, {
    required String email,
  });

  /// A birth request as it was sent, with why it was queried (if it was).
  Future<Result<BirthReissuanceRecord>> birthRecord(String id);

  /// Resends a queried request corrected in [form], with its payment
  /// reference (no new payment). Only new files are uploaded.
  Future<Result<String?>> updateBirth(
    BirthReissuanceRecord record,
    BirthReissuanceForm form, {
    required String email,
  });

  /// As [submitBirth], for an attestation; it goes to the applicant's own
  /// email.
  Future<Result<String?>> submitAttestation(ReissuanceDraft draft);

  Future<Result<AttestationReissuanceRecord>> attestationRecord(String id);

  /// As [updateBirth], for an attestation.
  Future<Result<String?>> updateAttestation(
    AttestationReissuanceRecord record,
    AttestationReissuanceForm form,
  );

  /// The reissued certificate (a JPEG), by the request's payment
  /// reference.
  Future<Result<Uint8List>> download(ReissuanceKind kind, String reference);
}
