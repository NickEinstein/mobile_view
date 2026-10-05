import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_draft.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_form.dart';

/// A submitted death registration, as recorded: the answers, which files
/// are on the server, and why it was queried, if it was.
final class DeathRecord extends Equatable {
  const DeathRecord({
    required this.summary,
    required this.deceased,
    required this.informant,
    this.documentKeys = const {},
    this.signatureKey,
    this.queryReason,
  });

  final BirthApplicationSummary summary;
  final DeceasedParticulars deceased;
  final InformantParticulars informant;

  /// Stored files' keys, by document.
  final Map<DeathDocument, String> documentKeys;
  final String? signatureKey;

  /// The registrar's reason, when [summary]'s status is queried.
  final String? queryReason;

  /// The record as a form: read on Certificate Details, corrected and sent
  /// back when queried.
  DeathDraft toQueriedDraft() => DeathDraft(
    startedOn: summary.submittedOn,
    deceased: deceased,
    informant: informant,
    queried: QueriedDeath(
      recordId: summary.id,
      certificateNumber: summary.trackingId,
      documentKeys: documentKeys,
      signatureKey: signatureKey,
      queryReason: queryReason,
    ),
  );

  @override
  List<Object?> get props => [
    summary,
    deceased,
    informant,
    documentKeys,
    signatureKey,
    queryReason,
  ];
}

/// Marks a draft as a recorded registration's correction (in memory
/// only); files on record count as provided.
final class QueriedDeath extends Equatable {
  const QueriedDeath({
    required this.recordId,
    required this.certificateNumber,
    this.documentKeys = const {},
    this.signatureKey,
    this.queryReason,
  });

  final String recordId;
  final String certificateNumber;
  final Map<DeathDocument, String> documentKeys;
  final String? signatureKey;
  final String? queryReason;

  @override
  List<Object?> get props => [
    recordId,
    certificateNumber,
    documentKeys,
    signatureKey,
    queryReason,
  ];
}
