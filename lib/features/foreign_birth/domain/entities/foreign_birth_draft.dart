import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_form.dart';

/// Where an unfinished notification picks up again.
enum ForeignBirthStage { payment, form }

/// A foreign birth notification in progress; nothing reaches the server
/// until the final submit.
final class ForeignBirthDraft extends Equatable {
  const ForeignBirthDraft({
    required this.startedOn,
    this.paymentReference,
    this.step = ForeignBirthStep.child,
    this.child = const ChildParticulars(),
    this.mother = const ParentParticulars(),
    this.father = const ParentParticulars(),
    this.informant = const InformantParticulars(),
    this.certificate,
    this.uploads = const {},
  });

  factory ForeignBirthDraft.fromJson(Map<String, Object?> json) {
    final uploads = json['uploads'];
    return ForeignBirthDraft(
      startedOn: DateTime.parse(json['startedOn']! as String),
      paymentReference: json['paymentReference'] as String?,
      step: switch (json['step']) {
        final String name =>
          ForeignBirthStep.values.asNameMap()[name] ?? ForeignBirthStep.child,
        _ => ForeignBirthStep.child,
      },
      child: ChildParticulars.fromJson(json['child']),
      mother: ParentParticulars.fromJson(json['mother']),
      father: ParentParticulars.fromJson(json['father']),
      informant: InformantParticulars.fromJson(json['informant']),
      certificate: AttachedFile.fromJson(json['certificate']),
      uploads: {
        if (uploads is Map<String, Object?>)
          for (final MapEntry(:key, :value) in uploads.entries)
            if (value is String) key: value,
      },
    );
  }

  final DateTime startedOn;

  /// The paid reference the submit will carry. Null until paid.
  final String? paymentReference;
  final ForeignBirthStep step;
  final ChildParticulars child;
  final ParentParticulars mother;
  final ParentParticulars father;
  final InformantParticulars informant;

  /// A photo of the foreign birth certificate: the backend's single
  /// `supporting_document`.
  final AttachedFile? certificate;

  /// Files already uploaded: private path → storage key. A failed submit
  /// doesn't upload them again.
  final Map<String, String> uploads;

  ForeignBirthStage get stage => paymentReference == null
      ? ForeignBirthStage.payment
      : ForeignBirthStage.form;

  ParentParticulars parent(Parent which) => switch (which) {
    Parent.mother => mother,
    Parent.father => father,
  };

  /// The backend refuses a notification unless the mother or the father
  /// is Nigerian.
  bool get hasNigerianParent => mother.isNigerian || father.isNigerian;

  /// Every country whose states the form shows.
  Set<String> get countryIds => {
    ?child[ChildField.countryOfBirth],
    for (final parent in [mother, father]) ...[
      ?parent[ParentField.nationality],
      ?parent[ParentField.country],
    ],
    ?informant[InformantField.nationality],
    ?informant[InformantField.country],
  };

  /// Every Nigerian state whose LGAs the form shows.
  Set<String> get nigerianStateIds => {
    for (final parent in [mother, father]) ...[
      if (parent.isNigerian) ?parent[ParentField.stateOfOrigin],
      if (parent.livesInNigeria) ?parent[ParentField.state],
    ],
    if (informant.isNigerian) ?informant[InformantField.stateOfOrigin],
    if (informant.livesInNigeria) ?informant[InformantField.state],
  };

  /// Every file the draft points to.
  Iterable<String> get files => [
    ?child[ChildField.facePhoto],
    ?informant[InformantField.signature],
    ?informant[InformantField.face],
    ?certificate?.path,
  ];

  /// The files sent: the informant consents by signature or by face, not
  /// both.
  Iterable<String> get filesToUpload => [
    ?child[ChildField.facePhoto],
    if (informant.applies(InformantField.signature))
      ?informant[InformantField.signature],
    if (informant.applies(InformantField.face)) ?informant[InformantField.face],
    ?certificate?.path,
  ];

  /// The informant's consent as sent: the signature or the face.
  String? get consentPath => switch (informant[InformantField.consentType]) {
    ConsentType.signature => informant[InformantField.signature],
    ConsentType.faceCapture => informant[InformantField.face],
    _ => null,
  };

  ForeignBirthDraft copyWith({
    String? paymentReference,
    ForeignBirthStep? step,
    ChildParticulars? child,
    ParentParticulars? mother,
    ParentParticulars? father,
    InformantParticulars? informant,
    AttachedFile? Function()? certificate,
    Map<String, String>? uploads,
  }) => ForeignBirthDraft(
    startedOn: startedOn,
    paymentReference: paymentReference ?? this.paymentReference,
    step: step ?? this.step,
    child: child ?? this.child,
    mother: mother ?? this.mother,
    father: father ?? this.father,
    informant: informant ?? this.informant,
    certificate: certificate != null ? certificate() : this.certificate,
    uploads: uploads ?? this.uploads,
  );

  ForeignBirthDraft withParent(Parent which, ParentParticulars particulars) =>
      switch (which) {
        Parent.mother => copyWith(mother: particulars),
        Parent.father => copyWith(father: particulars),
      };

  Map<String, Object?> toJson() => {
    'startedOn': startedOn.toIso8601String(),
    'paymentReference': paymentReference,
    'step': step.name,
    'child': child.values.toJson(),
    'mother': mother.values.toJson(),
    'father': father.values.toJson(),
    'informant': informant.values.toJson(),
    'certificate': certificate?.toJson(),
    'uploads': uploads,
  };

  @override
  List<Object?> get props => [
    startedOn,
    paymentReference,
    step,
    child,
    mother,
    father,
    informant,
    certificate,
    uploads,
  ];

  /// Contains personal data: keep it out of logs.
  @override
  String toString() =>
      'ForeignBirthDraft(stage: ${stage.name}, step: ${step.name})';
}
