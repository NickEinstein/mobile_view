import 'dart:typed_data';

import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/applications_source.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_draft.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_record.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_reference_data.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

/// Foreign Birth Notification: pay, fill the form on the device, then
/// submit it in one go.
abstract interface class ForeignBirthRepository implements ApplicationsSource {
  /// The notification fee.
  PaymentSource get payments;

  /// The form's option lists and the countries.
  Future<Result<ForeignBirthReferenceData>> referenceData();

  /// The states (cities, provinces) of [countryId].
  Future<Result<List<Option>>> states(String countryId);

  /// The LGAs of a Nigerian [stateId].
  Future<Result<List<Option>>> lgas(String stateId);

  /// What the identity service holds for [nin]. `NotFoundFailure` when it
  /// has no record.
  Future<Result<ApplicantNinRecord>> lookupNin(String nin);

  /// The notification in progress on this device, if any.
  Future<ForeignBirthDraft?> loadDraft();

  Future<void> saveDraft(ForeignBirthDraft draft);

  /// Stores a camera photo privately and returns its path. [replacing] is
  /// deleted.
  Future<String> keepPhoto(String capturedPath, {String? replacing});

  /// Stores a drawn signature (PNG) privately and returns its path.
  Future<String> keepSignature(Uint8List png, {String? replacing});

  /// Stores a picked document privately and returns its path.
  Future<String> keepDocument(String pickedPath, {String? replacing});

  Future<void> deleteFile(String path);

  /// Uploads every file to be sent that isn't uploaded yet; returns the
  /// draft with their storage keys recorded.
  Future<Result<ForeignBirthDraft>> uploadFiles(ForeignBirthDraft draft);

  /// Sends the whole notification (its files already uploaded). Returns
  /// the notification number when the server gives one.
  Future<Result<String?>> submit(ForeignBirthDraft draft);

  /// One notification, for its details or a query response. [id] is the
  /// backend's numeric id.
  Future<Result<ForeignBirthRecord>> details(String id);

  /// Resends a queried notification, corrected (its new files already
  /// uploaded).
  Future<Result<void>> amend(
    ForeignBirthDraft draft, {
    required ForeignBirthRecord record,
  });
}
