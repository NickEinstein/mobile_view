import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_record.dart';

/// The states chosen anywhere in an attestation, whose LGAs its dropdowns
/// and labels need.
Set<String> attestationStates({
  required ApplicantParticulars applicant,
  required AdditionalInformation additional,
  required ParentInformation mother,
  required ParentInformation father,
}) => {
  ?applicant[ApplicantField.stateOfOrigin],
  ?additional[AdditionalField.stateOfBirth],
  ?additional[AdditionalField.registrationState],
  ?mother[ParentInfoField.stateOfOrigin],
  ?father[ParentInfoField.stateOfOrigin],
};

/// A Birth Attestation in progress on this device: after payment, the NIN
/// answer and the applicant's face, then the form's four steps.
final class AttestationDraft extends Equatable {
  const AttestationDraft({
    required this.startedOn,
    this.hasNin,
    this.ninRecord,
    this.facePhoto,
    this.faceMatched = false,
    this.step = AttestationStep.applicant,
    this.applicant = const ApplicantParticulars(),
    this.additional = const AdditionalInformation(),
    this.mother = const ParentInformation(),
    this.father = const ParentInformation(),
    this.documents = const AttestationDocuments(),
    this.submissionKey,
    this.queried,
  });

  factory AttestationDraft.fromJson(Map<String, Object?> json) {
    final record = json['ninRecord'];
    final step = json['step'];
    return AttestationDraft(
      startedOn: DateTime.parse(json['startedOn']! as String),
      hasNin: json['hasNin'] as bool?,
      ninRecord: record is Map<String, Object?>
          ? ApplicantNinRecord.fromJson(record)
          : null,
      facePhoto: json['facePhoto'] as String?,
      faceMatched: json['faceMatched'] as bool? ?? false,
      step: step is String
          ? AttestationStep.values.asNameMap()[step] ??
                AttestationStep.applicant
          : AttestationStep.applicant,
      applicant: ApplicantParticulars.fromJson(json['applicant']),
      additional: AdditionalInformation.fromJson(json['additional']),
      mother: ParentInformation.fromJson(json['mother']),
      father: ParentInformation.fromJson(json['father']),
      documents: AttestationDocuments.fromJson(json['documents']),
      submissionKey: json['submissionKey'] as String?,
    );
  }

  final DateTime startedOn;

  /// Answer to "Does the applicant have a NIN?". Null until answered.
  final bool? hasNin;

  /// Set once [hasNin] and the NIN was verified.
  final ApplicantNinRecord? ninRecord;

  /// The applicant's face, a private file path.
  final String? facePhoto;

  /// The face matched the NIN photo. Without a NIN it is only captured.
  final bool faceMatched;
  final AttestationStep step;
  final ApplicantParticulars applicant;
  final AdditionalInformation additional;
  final ParentInformation mother;
  final ParentInformation father;
  final AttestationDocuments documents;

  /// Sent with the submission so the server can ignore a repeat. Set on
  /// the first attempt.
  final String? submissionKey;

  /// Set when correcting a queried record. Such drafts live only in
  /// memory: the record itself is on the server.
  final QueriedUpdate? queried;

  /// The applicant's face is captured, or already on file.
  bool get hasFace => facePhoto != null || (queried?.hasFace ?? false);

  /// [document] is attached, or already on file.
  bool hasDocument(AttestationDocument document) =>
      documents[document] != null ||
      (queried?.providedDocuments.contains(document) ?? false);

  ParentInformation parent(Parent parent) => switch (parent) {
    Parent.mother => mother,
    Parent.father => father,
  };

  Set<String> get chosenStates => attestationStates(
    applicant: applicant,
    additional: additional,
    mother: mother,
    father: father,
  );

  /// Every photo and document the draft points to.
  Iterable<String> get files => [
    ?facePhoto,
    for (final file in documents.files.values) file.path,
  ];

  AttestationDraft withFace(String path, {required bool matched}) =>
      _copy(facePhoto: path, faceMatched: matched);

  AttestationDraft copyWith({
    AttestationStep? step,
    ApplicantParticulars? applicant,
    AdditionalInformation? additional,
    ParentInformation? mother,
    ParentInformation? father,
    AttestationDocuments? documents,
    String? submissionKey,
  }) => _copy(
    step: step,
    applicant: applicant,
    additional: additional,
    mother: mother,
    father: father,
    documents: documents,
    submissionKey: submissionKey,
  );

  AttestationDraft _copy({
    String? facePhoto,
    bool? faceMatched,
    AttestationStep? step,
    ApplicantParticulars? applicant,
    AdditionalInformation? additional,
    ParentInformation? mother,
    ParentInformation? father,
    AttestationDocuments? documents,
    String? submissionKey,
  }) => AttestationDraft(
    startedOn: startedOn,
    hasNin: hasNin,
    ninRecord: ninRecord,
    queried: queried,
    facePhoto: facePhoto ?? this.facePhoto,
    faceMatched: faceMatched ?? this.faceMatched,
    step: step ?? this.step,
    applicant: applicant ?? this.applicant,
    additional: additional ?? this.additional,
    mother: mother ?? this.mother,
    father: father ?? this.father,
    documents: documents ?? this.documents,
    submissionKey: submissionKey ?? this.submissionKey,
  );

  Map<String, Object?> toJson() => {
    'startedOn': startedOn.toIso8601String(),
    'hasNin': hasNin,
    'ninRecord': ninRecord?.toJson(),
    'facePhoto': facePhoto,
    'faceMatched': faceMatched,
    'step': step.name,
    'applicant': applicant.values.toJson(),
    'additional': additional.values.toJson(),
    'mother': mother.values.toJson(),
    'father': father.values.toJson(),
    'documents': documents.toJson(),
    'submissionKey': submissionKey,
  };

  @override
  List<Object?> get props => [
    startedOn,
    hasNin,
    ninRecord,
    facePhoto,
    faceMatched,
    step,
    applicant,
    additional,
    mother,
    father,
    documents,
    submissionKey,
    queried,
  ];

  /// Contains personal data: keep it out of logs.
  @override
  String toString() => 'AttestationDraft(step: ${step.name})';
}
