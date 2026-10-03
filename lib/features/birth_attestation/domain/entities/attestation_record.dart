import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';

/// A submitted attestation, as recorded: the answers, which documents and
/// photo are on file, and why it was queried, if it was.
final class AttestationRecord extends Equatable {
  const AttestationRecord({
    required this.summary,
    required this.applicant,
    required this.additional,
    required this.mother,
    required this.father,
    this.nin,
    this.documentKeys = const {},
    this.hasFace = false,
    this.queryReason,
  });

  final BirthApplicationSummary summary;
  final ApplicantParticulars applicant;
  final AdditionalInformation additional;
  final ParentInformation mother;
  final ParentInformation father;
  final String? nin;

  /// The storage key of each document on file, which a correction sends
  /// back unless it is replaced.
  final Map<AttestationDocument, String> documentKeys;

  Set<AttestationDocument> get providedDocuments => documentKeys.keys.toSet();
  final bool hasFace;

  /// The registrar's reason, when [summary]'s status is queried.
  final String? queryReason;

  /// The record as a form to correct and send back.
  AttestationDraft toQueriedDraft() => AttestationDraft(
    startedOn: summary.submittedOn,
    hasNin: nin != null,
    step: AttestationStep.applicant,
    applicant: applicant,
    additional: additional,
    mother: mother,
    father: father,
    queried: QueriedUpdate(
      recordId: summary.id,
      certificateNumber: summary.trackingId,
      nin: nin,
      documentKeys: documentKeys,
      hasFace: hasFace,
    ),
  );

  @override
  List<Object?> get props => [
    summary,
    applicant,
    additional,
    mother,
    father,
    nin,
    documentKeys,
    hasFace,
    queryReason,
  ];
}

/// Marks a draft as the correction of a queried record; files on record
/// count as provided.
final class QueriedUpdate extends Equatable {
  const QueriedUpdate({
    required this.recordId,
    required this.certificateNumber,
    this.nin,
    this.documentKeys = const {},
    this.hasFace = false,
  });

  final String recordId;
  final String certificateNumber;
  final String? nin;

  /// The storage key of each document on file, which a correction sends
  /// back unless it is replaced.
  final Map<AttestationDocument, String> documentKeys;

  Set<AttestationDocument> get providedDocuments => documentKeys.keys.toSet();
  final bool hasFace;

  @override
  List<Object?> get props => [
    recordId,
    certificateNumber,
    nin,
    documentKeys,
    hasFace,
  ];
}
