import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_form.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_record.dart';

/// The states chosen in a death registration, whose LGAs are needed.
Set<String> deathStates({
  required DeceasedParticulars deceased,
  required InformantParticulars informant,
}) => {
  ?deceased[DeceasedField.state],
  ?deceased[DeceasedField.stateOfOrigin],
  ?deceased[DeceasedField.registrationState],
  ?informant[InformantField.state],
};

final class DeathDraft extends Equatable {
  const DeathDraft({
    required this.startedOn,
    this.step = DeathStep.deceased,
    this.deceased = const DeceasedParticulars(),
    this.informant = const InformantParticulars(),
    this.documents = const DeathDocuments(),
    this.signature,
    this.submissionKey,
    this.queried,
  });

  factory DeathDraft.fromJson(Map<String, Object?> json) {
    final step = json['step'];
    return DeathDraft(
      startedOn: DateTime.parse(json['startedOn']! as String),
      step: step is String
          ? DeathStep.values.asNameMap()[step] ?? DeathStep.deceased
          : DeathStep.deceased,
      deceased: DeceasedParticulars.fromJson(json['deceased']),
      informant: InformantParticulars.fromJson(json['informant']),
      documents: DeathDocuments.fromJson(json['documents']),
      signature: json['signature'] as String?,
      submissionKey: json['submissionKey'] as String?,
    );
  }

  final DateTime startedOn;
  final DeathStep step;
  final DeceasedParticulars deceased;
  final InformantParticulars informant;
  final DeathDocuments documents;

  /// The informant's signature, drawn on the preview (a private file
  /// path).
  final String? signature;

  /// Sent with the submission so the server can ignore a repeat. Set on
  /// the first attempt.
  final String? submissionKey;

  /// Set for a recorded registration (Certificate Details, or correcting
  /// a queried one). Such drafts live only in memory.
  final QueriedDeath? queried;

  /// [document] is attached, or already on the server.
  bool hasDocument(DeathDocument document) =>
      documents[document] != null ||
      (queried?.documentKeys.containsKey(document) ?? false);

  /// Signed here, or a signature is already on the server.
  bool get hasSignature => signature != null || queried?.signatureKey != null;

  /// Every required document is attached or on file.
  bool get documentsComplete => DeathDocument.values
      .where(
        (d) => d.isRequired(placeOfDeath: deceased[DeceasedField.placeOfDeath]),
      )
      .every(hasDocument);

  /// Something worth resuming has been entered.
  bool get hasAnswers =>
      deceased.values.values.isNotEmpty ||
      informant.values.values.isNotEmpty ||
      documents.files.isNotEmpty;

  Set<String> get chosenStates =>
      deathStates(deceased: deceased, informant: informant);

  /// Every file the draft points to.
  Iterable<String> get files => [
    ?signature,
    for (final file in documents.files.values) file.path,
  ];

  DeathDraft copyWith({
    DeathStep? step,
    DeceasedParticulars? deceased,
    InformantParticulars? informant,
    DeathDocuments? documents,
    String? Function()? signature,
    String? submissionKey,
  }) => DeathDraft(
    startedOn: startedOn,
    step: step ?? this.step,
    deceased: deceased ?? this.deceased,
    informant: informant ?? this.informant,
    documents: documents ?? this.documents,
    signature: signature != null ? signature() : this.signature,
    submissionKey: submissionKey ?? this.submissionKey,
    queried: queried,
  );

  Map<String, Object?> toJson() => {
    'startedOn': startedOn.toIso8601String(),
    'step': step.name,
    'deceased': deceased.toJson(),
    'informant': informant.toJson(),
    'documents': documents.toJson(),
    'signature': signature,
    'submissionKey': submissionKey,
  };

  @override
  List<Object?> get props => [
    startedOn,
    step,
    deceased,
    informant,
    documents,
    signature,
    submissionKey,
    queried,
  ];

  /// Contains personal data: keep it out of logs.
  @override
  String toString() => 'DeathDraft(step: ${step.name})';
}
