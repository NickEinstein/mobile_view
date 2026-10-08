import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_form.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

/// What happened at the child's NIN step.
enum ChildNinDecision { verified, skipped }

/// Where an unfinished registration picks up again.
enum AdoptionStage { nin, payment, form }

/// An adopted child registration in progress; [referenceId] is the
/// server's application.
final class AdoptionDraft extends Equatable {
  const AdoptionDraft({
    required this.referenceId,
    required this.startedOn,
    this.ninDecision,
    this.childNin,
    this.paymentReference,
    this.step = AdoptionStep.child,
    this.child = const ChildParticulars(),
    this.adopter1 = const AdopterParticulars(),
    this.adopter2 = const AdopterParticulars(),
    this.details = const AdoptionDetails(),
    this.informant = const InformantParticulars(),
    this.informantPassport,
    this.documents = const {},
    this.uploads = const {},
  });

  factory AdoptionDraft.fromJson(Map<String, Object?> json) {
    final uploads = json['uploads'];
    final documents = json['documents'];
    return AdoptionDraft(
      referenceId: json['referenceId']! as String,
      startedOn: DateTime.parse(json['startedOn']! as String),
      ninDecision: switch (json['ninDecision']) {
        final String name => ChildNinDecision.values.asNameMap()[name],
        _ => null,
      },
      childNin: json['childNin'] as String?,
      paymentReference: json['paymentReference'] as String?,
      step: switch (json['step']) {
        final String name =>
          AdoptionStep.values.asNameMap()[name] ?? AdoptionStep.child,
        _ => AdoptionStep.child,
      },
      child: ChildParticulars.fromJson(json['child']),
      adopter1: AdopterParticulars.fromJson(json['adopter1']),
      adopter2: AdopterParticulars.fromJson(json['adopter2']),
      details: AdoptionDetails.fromJson(json['details']),
      informant: InformantParticulars.fromJson(json['informant']),
      informantPassport: AttachedFile.fromJson(json['informantPassport']),
      documents: {
        if (documents is Map<String, Object?>)
          for (final MapEntry(:key, :value) in documents.entries)
            if ((
                  AdoptionDocument.values.asNameMap()[key],
                  AttachedFile.fromJson(value),
                )
                case (final document?, final file?))
              document: file,
      },
      uploads: {
        if (uploads is Map<String, Object?>)
          for (final MapEntry(:key, :value) in uploads.entries)
            if (value is String) key: value,
      },
    );
  }

  /// The application's id from `POST /initiate`.
  final String referenceId;
  final DateTime startedOn;

  /// Null until the NIN step is done.
  final ChildNinDecision? ninDecision;

  /// Only when verified.
  final String? childNin;

  /// The paid reference, once attached to the application.
  final String? paymentReference;
  final AdoptionStep step;
  final ChildParticulars child;
  final AdopterParticulars adopter1;

  /// Optional: empty when the adoption order names one adopter.
  final AdopterParticulars adopter2;
  final AdoptionDetails details;
  final InformantParticulars informant;

  /// Optional photo of the informant's international passport.
  final AttachedFile? informantPassport;
  final Map<AdoptionDocument, AttachedFile> documents;

  /// Files already uploaded: private path → storage key. A file is
  /// uploaded once, however often its section is saved.
  final Map<String, String> uploads;

  AdoptionStage get stage => switch (this) {
    AdoptionDraft(ninDecision: null) => AdoptionStage.nin,
    AdoptionDraft(paymentReference: null) => AdoptionStage.payment,
    _ => AdoptionStage.form,
  };

  /// Whether a second adopter is given (`ad2Present`).
  bool get hasAdopter2 => !adopter2.isEmpty;

  AdopterParticulars adopter(Adopter which) => switch (which) {
    Adopter.first => adopter1,
    Adopter.second => adopter2,
  };

  bool get isNinVerified => ninDecision == ChildNinDecision.verified;

  /// Whether [field] is locked because the child's NIN filled it.
  bool isLocked(ChildField field) => isNinVerified && field.comesFromNin;

  /// The documents asked for: Adopter 2's identity only when Adopter 2 is
  /// given.
  List<AdoptionDocument> get documentsAsked => [
    for (final document in AdoptionDocument.values)
      if (document != AdoptionDocument.adopter2Identity || hasAdopter2)
        document,
  ];

  /// Every document asked for is required.
  bool isMissing(AdoptionDocument document) =>
      documentsAsked.contains(document) && documents[document] == null;

  bool get documentsComplete => !documentsAsked.any(isMissing);

  /// Every file the draft points to.
  /// The states whose LGAs the dropdowns and labels need.
  Set<String> get chosenStates => {
    ?child[ChildField.stateOfBirth],
    ?child[ChildField.registrationState],
    ?adopter1[AdopterField.state],
    ?adopter2[AdopterField.state],
    ?informant[InformantField.state],
    ?informant[InformantField.stateOfOrigin],
  };

  Iterable<String> get files => [
    ?child[ChildField.facePhoto],
    ?informant[InformantField.signature],
    ?informant[InformantField.face],
    ?informantPassport?.path,
    for (final file in documents.values) file.path,
  ];

  /// The files sent to the server, uploaded before a section is saved.
  /// The informant's consent is the signature or the face, not both.
  Iterable<String> get filesToUpload => [
    ?child[ChildField.facePhoto],
    if (informant.applies(InformantField.signature))
      ?informant[InformantField.signature],
    if (informant.applies(InformantField.face)) ?informant[InformantField.face],
    ?informantPassport?.path,
    for (final document in documentsAsked) ?documents[document]?.path,
  ];

  AdoptionDraft copyWith({
    ChildNinDecision? ninDecision,
    String? Function()? childNin,
    String? paymentReference,
    AdoptionStep? step,
    ChildParticulars? child,
    AdopterParticulars? adopter1,
    AdopterParticulars? adopter2,
    AdoptionDetails? details,
    InformantParticulars? informant,
    AttachedFile? Function()? informantPassport,
    Map<AdoptionDocument, AttachedFile>? documents,
    Map<String, String>? uploads,
  }) => AdoptionDraft(
    referenceId: referenceId,
    startedOn: startedOn,
    ninDecision: ninDecision ?? this.ninDecision,
    childNin: childNin != null ? childNin() : this.childNin,
    paymentReference: paymentReference ?? this.paymentReference,
    step: step ?? this.step,
    child: child ?? this.child,
    adopter1: adopter1 ?? this.adopter1,
    adopter2: adopter2 ?? this.adopter2,
    details: details ?? this.details,
    informant: informant ?? this.informant,
    informantPassport: informantPassport != null
        ? informantPassport()
        : this.informantPassport,
    documents: documents ?? this.documents,
    uploads: uploads ?? this.uploads,
  );

  Map<String, Object?> toJson() => {
    'referenceId': referenceId,
    'startedOn': startedOn.toIso8601String(),
    'ninDecision': ninDecision?.name,
    'childNin': childNin,
    'paymentReference': paymentReference,
    'step': step.name,
    'child': child.values.toJson(),
    'adopter1': adopter1.values.toJson(),
    'adopter2': adopter2.values.toJson(),
    'details': details.values.toJson(),
    'informant': informant.values.toJson(),
    'informantPassport': informantPassport?.toJson(),
    'documents': {
      for (final MapEntry(:key, :value) in documents.entries)
        key.name: value.toJson(),
    },
    'uploads': uploads,
  };

  @override
  List<Object?> get props => [
    referenceId,
    startedOn,
    ninDecision,
    childNin,
    paymentReference,
    step,
    child,
    adopter1,
    adopter2,
    details,
    informant,
    informantPassport,
    documents,
    uploads,
  ];

  /// Contains personal data: keep it out of logs.
  @override
  String toString() =>
      'AdoptionDraft(stage: ${stage.name}, step: ${step.name})';
}
