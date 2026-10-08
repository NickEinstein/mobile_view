import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_form.dart';

/// What happened at the child's NIN step.
enum ChildNinDecision { verified, skipped }

/// Where an unfinished registration picks up again.
enum SurrogacyStage { nin, payment, form }

/// A surrogacy birth registration in progress; [referenceId] is the
/// server's application.
final class SurrogacyDraft extends Equatable {
  const SurrogacyDraft({
    required this.referenceId,
    required this.startedOn,
    this.ninDecision,
    this.childNin,
    this.paymentReference,
    this.step = SurrogacyStep.child,
    this.child = const ChildParticulars(),
    this.surrogacy = const SurrogacyDetails(),
    this.legalMother = const ParentParticulars(),
    this.hasLegalFather,
    this.legalFather = const ParentParticulars(),
    this.surrogateMother = const SurrogateMotherParticulars(),
    this.informant = const InformantParticulars(),
    this.informantPassport,
    this.documents = const {},
    this.uploads = const {},
  });

  factory SurrogacyDraft.fromJson(Map<String, Object?> json) {
    final uploads = json['uploads'];
    final documents = json['documents'];
    return SurrogacyDraft(
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
          SurrogacyStep.values.asNameMap()[name] ?? SurrogacyStep.child,
        _ => SurrogacyStep.child,
      },
      child: ChildParticulars.fromJson(json['child']),
      surrogacy: SurrogacyDetails.fromJson(json['surrogacy']),
      legalMother: ParentParticulars.fromJson(json['legalMother']),
      hasLegalFather: json['hasLegalFather'] as bool?,
      legalFather: ParentParticulars.fromJson(json['legalFather']),
      surrogateMother: SurrogateMotherParticulars.fromJson(
        json['surrogateMother'],
      ),
      informant: InformantParticulars.fromJson(json['informant']),
      informantPassport: AttachedFile.fromJson(json['informantPassport']),
      documents: {
        if (documents is Map<String, Object?>)
          for (final document in SurrogacyDocument.values)
            document: ?AttachedFile.fromJson(documents[document.name]),
      },
      uploads: {
        if (uploads is Map<String, Object?>)
          for (final MapEntry(:key, :value) in uploads.entries)
            if (value is String) key: value,
      },
    );
  }

  /// The application's id from `POST /initiate` (e.g. `SBR-2026-0004821`).
  final String referenceId;
  final DateTime startedOn;

  /// Null until the NIN step is done.
  final ChildNinDecision? ninDecision;

  /// Only when verified.
  final String? childNin;

  /// The paid reference, once attached to the application.
  final String? paymentReference;
  final SurrogacyStep step;
  final ChildParticulars child;
  final SurrogacyDetails surrogacy;
  final ParentParticulars legalMother;

  /// "Is a second legal parent (Father) named in the court order?" Null
  /// until answered; only then is [legalFather] asked.
  final bool? hasLegalFather;
  final ParentParticulars legalFather;

  /// Optional: empty when not given.
  final SurrogateMotherParticulars surrogateMother;
  final InformantParticulars informant;

  /// Optional photo of the informant's international passport.
  final AttachedFile? informantPassport;
  final Map<SurrogacyDocument, AttachedFile> documents;

  /// Files already uploaded: private path → storage key. A file is
  /// uploaded once, however often its section is saved.
  final Map<String, String> uploads;

  SurrogacyStage get stage => switch (this) {
    SurrogacyDraft(ninDecision: null) => SurrogacyStage.nin,
    SurrogacyDraft(paymentReference: null) => SurrogacyStage.payment,
    _ => SurrogacyStage.form,
  };

  bool get isNinVerified => ninDecision == ChildNinDecision.verified;

  /// Whether [field] is locked because the child's NIN filled it.
  bool isLocked(ChildField field) => isNinVerified && field.comesFromNin;

  /// The documents asked for: the father's identity only when he is
  /// named.
  List<SurrogacyDocument> get documentsAsked => [
    for (final document in SurrogacyDocument.values)
      if (document != SurrogacyDocument.fatherIdentity ||
          (hasLegalFather ?? false))
        document,
  ];

  /// Every document asked for is required.
  bool isMissing(SurrogacyDocument document) =>
      documentsAsked.contains(document) && documents[document] == null;

  bool get documentsComplete => !documentsAsked.any(isMissing);

  /// Every file the draft points to.
  /// The states whose LGAs the dropdowns and labels need.
  Set<String> get chosenStates => {
    ?child[ChildField.stateOfBirth],
    ?child[ChildField.registrationState],
    ?legalMother[ParentField.state],
    ?legalFather[ParentField.state],
    ?surrogateMother[SurrogateField.stateOfOrigin],
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
  // The informant's face has no field in the API, so it stays here.
  Iterable<String> get filesToUpload => [
    ?child[ChildField.facePhoto],
    if (informant.applies(InformantField.signature))
      ?informant[InformantField.signature],
    ?informantPassport?.path,
    for (final document in documentsAsked) ?documents[document]?.path,
  ];

  /// Fills the registration state and LGA from the centre when a saved
  /// application left them out.
  SurrogacyDraft withRegistrationLocation(
    ({String state, String lga})? Function(String? centerId) locate,
  ) {
    final center = child[ChildField.registrationCenter];
    final location = locate(center);
    if (location == null || child[ChildField.registrationState] != null) {
      return this;
    }
    return copyWith(
      child: child
          .set(ChildField.registrationState, location.state)
          .set(ChildField.registrationLga, location.lga)
          .set(ChildField.registrationCenter, center),
    );
  }

  SurrogacyDraft copyWith({
    ChildNinDecision? ninDecision,
    String? Function()? childNin,
    String? paymentReference,
    SurrogacyStep? step,
    ChildParticulars? child,
    SurrogacyDetails? surrogacy,
    ParentParticulars? legalMother,
    bool? hasLegalFather,
    ParentParticulars? legalFather,
    SurrogateMotherParticulars? surrogateMother,
    InformantParticulars? informant,
    AttachedFile? Function()? informantPassport,
    Map<SurrogacyDocument, AttachedFile>? documents,
    Map<String, String>? uploads,
  }) => SurrogacyDraft(
    referenceId: referenceId,
    startedOn: startedOn,
    ninDecision: ninDecision ?? this.ninDecision,
    childNin: childNin != null ? childNin() : this.childNin,
    paymentReference: paymentReference ?? this.paymentReference,
    step: step ?? this.step,
    child: child ?? this.child,
    surrogacy: surrogacy ?? this.surrogacy,
    legalMother: legalMother ?? this.legalMother,
    hasLegalFather: hasLegalFather ?? this.hasLegalFather,
    legalFather: legalFather ?? this.legalFather,
    surrogateMother: surrogateMother ?? this.surrogateMother,
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
    'surrogacy': surrogacy.values.toJson(),
    'legalMother': legalMother.values.toJson(),
    'hasLegalFather': hasLegalFather,
    'legalFather': legalFather.values.toJson(),
    'surrogateMother': surrogateMother.values.toJson(),
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
    surrogacy,
    legalMother,
    hasLegalFather,
    legalFather,
    surrogateMother,
    informant,
    informantPassport,
    documents,
    uploads,
  ];

  /// Contains personal data: keep it out of logs.
  @override
  String toString() =>
      'SurrogacyDraft(stage: ${stage.name}, step: ${step.name})';
}
