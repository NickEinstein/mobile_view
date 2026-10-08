import 'package:vital_reg_mobile/core/network/cancellation.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/applications_source.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

/// Birth Attestation: an adult (18+) attests their own birth. Payment, the
/// NIN (optional), the face, then the form.
abstract interface class BirthAttestationRepository
    implements ApplicationsSource {
  /// The attestation fee, paid before anything else.
  PaymentSource get payments;

  /// Looks the applicant's NIN up with the identity service.
  Future<Result<ApplicantNinRecord>> verifyNin(String nin);

  /// Whether the face photo matches [nin]'s NIN photo (true if there is
  /// none to match).
  Future<Result<bool>> matchFace(String photoPath, {required String nin});

  /// The form's lists, with the LGAs of the states in [withLgasOf].
  Future<Result<AttestationReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  });

  /// Uploads the files, then sends the application paid by
  /// [paymentReference]. Returns its attestation number, if given.
  Future<Result<String?>> submit(
    AttestationDraft draft, {
    required String paymentReference,
    void Function(int sent, int total)? onProgress,
    Cancellation? cancellation,
  });

  /// One submitted attestation, with everything recorded for it.
  Future<Result<AttestationRecord>> details(String id);

  /// Sends the corrections to a queried record ([AttestationDraft.queried])
  /// with any replaced documents. No new payment is needed.
  Future<Result<void>> updateQueried(AttestationDraft draft);

  Future<AttestationDraft?> loadDraft();

  Future<void> saveDraft(AttestationDraft draft);

  /// Moves a just-captured photo into private storage and returns its new
  /// path. [replacing] is deleted.
  Future<String> keepPhoto(String capturedPath, {String? replacing});

  /// Moves a picked document into private storage and returns its new
  /// path. [replacing] is deleted.
  Future<String> keepDocument(String pickedPath, {String? replacing});

  Future<void> deleteFile(String path);
}
