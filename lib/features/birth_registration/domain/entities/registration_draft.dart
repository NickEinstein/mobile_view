import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

/// Step 1 fields, in form order. Values are text, option ids, an ISO date
/// (`dateOfBirth`) or a private file path (`facePhoto`).
enum ChildField {
  surname,
  firstName,
  middleName,
  dateOfBirth,
  typeOfBirth,
  birthOrder,
  sex,
  placeOfOccurrence,
  stateOfBirth,
  lgaOfBirth,
  localityOfBirth,
  stateOfOrigin,
  lgaOfOrigin,
  townOfOrigin,
  registrationState,
  registrationLga,
  registrationCenter,
  localityType,
  facePhoto;

  bool get isOptional => this == middleName;

  /// Fields that must be cleared when this one changes, because their
  /// options depend on it (e.g. a new state invalidates its LGA).
  List<ChildField> get dependents => switch (this) {
    stateOfBirth => const [lgaOfBirth],
    stateOfOrigin => const [lgaOfOrigin],
    registrationState => const [registrationLga, registrationCenter],
    registrationLga => const [registrationCenter],
    _ => const [],
  };
}

enum ChildFieldError { required, futureDate, notAChild }

/// The states chosen anywhere in an application, whose LGAs its dropdowns
/// and labels need.
Set<String> statesChosenIn({
  required ChildParticulars child,
  required ParentParticulars mother,
  required ParentParticulars father,
  required InformantParticulars informant,
}) => {
  ?child[ChildField.stateOfBirth],
  ?child[ChildField.stateOfOrigin],
  ?child[ChildField.registrationState],
  for (final parent in [mother, father]) ...[
    ?parent[ParentField.state],
    ?parent[ParentField.stateOfOrigin],
  ],
  ?informant[InformantField.state],
};

/// "Particulars of Child".
final class ChildParticulars extends Equatable {
  const ChildParticulars([this.values = const {}]);

  factory ChildParticulars.fromJson(Map<String, Object?> json) =>
      ChildParticulars({
        for (final field in ChildField.values)
          if (json[field.name] case final String value) field: value,
      });

  /// Registration covers children up to 17 (older people use attestation).
  static const maxAgeYears = 18;

  /// From this age registration has a fee (the registry's rule; the API
  /// itself insists on a payment from age 6).
  static const feeFromAgeYears = 5;

  final Map<ChildField, String> values;

  String? operator [](ChildField field) => values[field];

  DateTime? get dateOfBirth =>
      DateTime.tryParse(values[ChildField.dateOfBirth] ?? '');

  /// Whole years old on [today]; null without a date of birth.
  int? ageOn(DateTime today) {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final hadBirthday =
        today.month > dob.month ||
        (today.month == dob.month && today.day >= dob.day);
    return today.year - dob.year - (hadBirthday ? 0 : 1);
  }

  bool needsPaymentOn(DateTime today) => (ageOn(today) ?? 0) >= feeFromAgeYears;

  ChildParticulars set(ChildField field, String? value) {
    final next = Map<ChildField, String>.of(values);
    if (value == null || value.trim().isEmpty) {
      next.remove(field);
    } else {
      next[field] = value;
    }
    for (final dependent in field.dependents) {
      next.remove(dependent);
    }
    return ChildParticulars(next);
  }

  ChildFieldError? errorOf(ChildField field, {required DateTime today}) {
    final value = values[field];
    if (value == null) {
      return field.isOptional ? null : ChildFieldError.required;
    }
    if (field == ChildField.dateOfBirth) {
      final dob = dateOfBirth;
      if (dob == null) return ChildFieldError.required;
      if (dob.isAfter(today)) return ChildFieldError.futureDate;
      final eighteenth = DateTime(dob.year + maxAgeYears, dob.month, dob.day);
      if (!today.isBefore(eighteenth)) return ChildFieldError.notAChild;
    }
    return null;
  }

  bool isComplete({required DateTime today}) =>
      ChildField.values.every((field) => errorOf(field, today: today) == null);

  Map<String, Object?> toJson() => {
    for (final entry in values.entries) entry.key.name: entry.value,
  };

  @override
  List<Object?> get props => [values];
}

/// The six steps of the form.
enum RegistrationStep {
  child,
  mother,
  father,
  informant,
  documents,
  review;

  int get number => index + 1;
  static int get count => values.length;
}

/// An application in progress, saved as the user goes so it can be resumed.
final class RegistrationDraft extends Equatable {
  const RegistrationDraft({
    required this.startedOn,
    this.childHasNin,
    this.childNin,
    this.step = RegistrationStep.child,
    this.child = const ChildParticulars(),
    this.mother = const ParentParticulars(),
    this.father = const ParentParticulars(),
    this.informant = const InformantParticulars(),
    this.documents = const SupportingDocuments(),
    this.submissionKey,
    this.paymentReference,
  });

  factory RegistrationDraft.fromJson(Map<String, Object?> json) {
    final child = json['child'];
    return RegistrationDraft(
      startedOn: DateTime.parse(json['startedOn']! as String),
      childHasNin: json['childHasNin'] as bool?,
      childNin: json['childNin'] as String?,
      step: RegistrationStep.values.byName(json['step']! as String),
      child: child is Map<String, Object?>
          ? ChildParticulars.fromJson(child)
          : const ChildParticulars(),
      mother: ParentParticulars.fromJson(json['mother']),
      father: ParentParticulars.fromJson(json['father']),
      informant: InformantParticulars.fromJson(json['informant']),
      documents: SupportingDocuments.fromJson(json['documents']),
      submissionKey: json['submissionKey'] as String?,
      paymentReference: json['paymentReference'] as String?,
    );
  }

  final DateTime startedOn;

  /// Answer to "Does the child have a NIN?". Null until answered.
  final bool? childHasNin;

  /// Set only when [childHasNin] and the NIN was validated.
  final String? childNin;
  final RegistrationStep step;
  final ChildParticulars child;
  final ParentParticulars mother;
  final ParentParticulars father;
  final InformantParticulars informant;
  final SupportingDocuments documents;

  /// Sent with the submission so the server can ignore a repeat (e.g. a
  /// retry after the connection dropped). Set on the first attempt.
  final String? submissionKey;

  /// The paid fee's reference, once paid (see
  /// [ChildParticulars.needsPaymentOn]).
  final String? paymentReference;

  bool isPaidFor(DateTime today) =>
      paymentReference != null || !child.needsPaymentOn(today);

  /// When neither parent gave a NIN, the informant must.
  bool get parentsGaveNin => mother.hasNin || father.hasNin;

  /// The documents Step 5 asks for: a passport only for a parent who
  /// isn't Nigerian.
  List<DocumentType> get documentTypes => [
    for (final type in DocumentType.values)
      if (switch (type) {
        DocumentType.fatherPassport => father.isForeign,
        DocumentType.motherPassport => mother.isForeign,
        _ => true,
      })
        type,
  ];

  bool isDocumentRequired(DocumentType type) =>
      type.isRequired || (type.isPassport && documentTypes.contains(type));

  bool isDocumentMissing(DocumentType type) =>
      isDocumentRequired(type) && documents[type] == null;

  bool get documentsComplete => !DocumentType.values.any(isDocumentMissing);

  Set<String> get chosenStates => statesChosenIn(
    child: child,
    mother: mother,
    father: father,
    informant: informant,
  );

  /// Every photo, signature and document the draft points to.
  Iterable<String> get files => [
    ?child[ChildField.facePhoto],
    ...informant.files,
    for (final file in documents.files.values) file.path,
  ];

  RegistrationDraft copyWith({
    RegistrationStep? step,
    ChildParticulars? child,
    ParentParticulars? mother,
    ParentParticulars? father,
    InformantParticulars? informant,
    SupportingDocuments? documents,
    String? submissionKey,
    String? paymentReference,
  }) => RegistrationDraft(
    startedOn: startedOn,
    childHasNin: childHasNin,
    childNin: childNin,
    step: step ?? this.step,
    child: child ?? this.child,
    mother: mother ?? this.mother,
    father: father ?? this.father,
    informant: informant ?? this.informant,
    documents: documents ?? this.documents,
    submissionKey: submissionKey ?? this.submissionKey,
    paymentReference: paymentReference ?? this.paymentReference,
  );

  Map<String, Object?> toJson() => {
    'startedOn': startedOn.toIso8601String(),
    'childHasNin': childHasNin,
    'childNin': childNin,
    'step': step.name,
    'child': child.toJson(),
    'mother': mother.toJson(),
    'father': father.toJson(),
    'informant': informant.toJson(),
    'documents': documents.toJson(),
    'submissionKey': submissionKey,
    'paymentReference': paymentReference,
  };

  @override
  List<Object?> get props => [
    startedOn,
    childHasNin,
    childNin,
    step,
    child,
    mother,
    father,
    informant,
    documents,
    submissionKey,
    paymentReference,
  ];

  /// Contains personal data: keep it out of logs.
  @override
  String toString() => 'RegistrationDraft(step: ${step.name})';
}
