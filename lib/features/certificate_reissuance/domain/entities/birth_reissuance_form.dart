import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

// The birth reissuance form, with the registry's fields and rules.

/// The form's steps, in order.
enum BirthReissuanceStep {
  child,
  mother,
  father,
  documents,
  review;

  static const count = 5;
  int get number => index + 1;
}

enum ReissuanceFieldError {
  required,

  /// A date (of birth) after the e-CRVS commission date.
  tooLate,
  invalidAge,
  invalidPhone,

  /// An attestation applicant under 18.
  underAge,
  invalidEmail,
}

/// Ids with a special meaning.
abstract final class ReissuanceCodes {
  /// Nigeria: only a Nigerian residence
  /// has an LGA, and only a Nigerian has an LGA of origin.
  static const nigeria = '63';

  /// "Literate": only then is the level of education asked.
  static const literate = '1';

  /// The sexes.
  static const male = '1';
  static const female = '2';

  /// Reissuance is for births registered before e-CRVS was commissioned.
  static final latestBirthDate = DateTime(2023, 11, 8);
}

// ---- Step 1: Particulars of Child -----------------------------------------

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
  townOfBirth,
  townOfOrigin,
  locality,
  registrationState,
  registrationLga,
  registrationCenter;

  bool get isOptional =>
      this == middleName || this == townOfBirth || this == townOfOrigin;

  List<ChildField> get dependents => switch (this) {
    stateOfBirth => const [lgaOfBirth],
    registrationState => const [registrationLga, registrationCenter],
    registrationLga => const [registrationCenter],
    _ => const [],
  };
}

final class ChildParticulars extends Equatable {
  const ChildParticulars([this.values = const FieldValues()]);

  factory ChildParticulars.fromJson(Object? json) =>
      ChildParticulars(FieldValues.fromJson(json, ChildField.values));

  final FieldValues<ChildField> values;

  String? operator [](ChildField field) => values[field];

  DateTime? get dateOfBirth =>
      DateTime.tryParse(values[ChildField.dateOfBirth] ?? '');

  int? get birthOrder => int.tryParse(values[ChildField.birthOrder] ?? '');

  ChildParticulars set(ChildField field, String? value) =>
      ChildParticulars(values.set(field, value, dependents: field.dependents));

  ReissuanceFieldError? errorOf(ChildField field) {
    if (values[field] == null) {
      return field.isOptional ? null : ReissuanceFieldError.required;
    }
    if (field == ChildField.dateOfBirth) {
      final date = dateOfBirth;
      if (date == null) return ReissuanceFieldError.required;
      if (date.isAfter(ReissuanceCodes.latestBirthDate)) {
        return ReissuanceFieldError.tooLate;
      }
    }
    return null;
  }

  bool get isComplete =>
      ChildField.values.every((field) => errorOf(field) == null);

  @override
  List<Object?> get props => [values];
}

// ---- Steps 2 and 3: Particulars of Mother / Father -------------------------

enum ParentRole { mother, father }

/// Mother and Father step fields, in form order. [sameResidenceAsMother]
/// is the father's "Is it the same as mother's?", `yes` or `no`.
enum ParentDetail {
  surname,
  firstName,
  maidenName,
  sameResidenceAsMother,
  country,
  state,
  lga,
  address,
  age,
  maritalStatus,
  nationality,
  stateOfOrigin,
  lgaOfOrigin,
  ethnicGroup,
  literacy,
  educationLevel,
  occupation,
  phone;

  /// Place of usual residence: what "same as mother's" copies.
  static const residence = [country, state, lga, address];

  List<ParentDetail> get dependents => switch (this) {
    country => const [state, lga],
    state => const [lga],
    nationality => const [stateOfOrigin, lgaOfOrigin],
    stateOfOrigin => const [lgaOfOrigin],
    literacy => const [educationLevel],
    _ => const [],
  };
}

final class ParentParticulars extends Equatable {
  const ParentParticulars([this.values = const FieldValues()]);

  factory ParentParticulars.fromJson(Object? json) =>
      ParentParticulars(FieldValues.fromJson(json, ParentDetail.values));

  static const yes = 'yes';
  static const no = 'no';

  /// The mother's youngest age, raised by one for each child before this
  /// one.
  static const motherMinAge = 9;
  static const motherMaxAge = 60;
  static const fatherMinAge = 10;
  static const fatherMaxAge = 90;

  static final _phonePattern = RegExp(r'^\d{11,15}$');

  final FieldValues<ParentDetail> values;

  String? operator [](ParentDetail field) => values[field];

  ParentParticulars set(ParentDetail field, String? value) =>
      ParentParticulars(values.set(field, value, dependents: field.dependents));

  /// The father's "same as mother's": yes copies her residence, no clears
  /// his. The fields stay editable.
  ParentParticulars sameResidenceAs(
    ParentParticulars mother, {
    required bool same,
  }) {
    var next = values.set(ParentDetail.sameResidenceAsMother, same ? yes : no);
    for (final field in ParentDetail.residence) {
      // Not through [set]: a country or state would clear what follows.
      next = next.set(field, same ? mother[field] : null);
    }
    return ParentParticulars(next);
  }

  static (int, int) ageRange(ParentRole role, {int? birthOrder}) =>
      switch (role) {
        ParentRole.mother => (
          motherMinAge + ((birthOrder ?? 1) > 1 ? birthOrder! - 1 : 0),
          motherMaxAge,
        ),
        ParentRole.father => (fatherMinAge, fatherMaxAge),
      };

  /// Whether [field] is asked, given the role and the answers so far.
  bool applies(ParentDetail field, ParentRole role) => switch (field) {
    ParentDetail.maidenName => role == ParentRole.mother,
    ParentDetail.sameResidenceAsMother => role == ParentRole.father,
    ParentDetail.lga => values[ParentDetail.country] == ReissuanceCodes.nigeria,
    ParentDetail.lgaOfOrigin =>
      values[ParentDetail.nationality] == ReissuanceCodes.nigeria,
    ParentDetail.educationLevel =>
      values[ParentDetail.literacy] == ReissuanceCodes.literate,
    _ => true,
  };

  /// [birthOrder] is the child's; it raises the mother's youngest age.
  ReissuanceFieldError? errorOf(
    ParentDetail field,
    ParentRole role, {
    int? birthOrder,
  }) {
    if (!applies(field, role)) return null;
    final value = values[field];
    if (value == null) {
      return field == ParentDetail.sameResidenceAsMother
          ? null
          : ReissuanceFieldError.required;
    }
    if (field == ParentDetail.age) {
      final (min, max) = ageRange(role, birthOrder: birthOrder);
      final age = int.tryParse(value);
      if (age == null || age < min || age > max) {
        return ReissuanceFieldError.invalidAge;
      }
    }
    if (field == ParentDetail.phone && !_phonePattern.hasMatch(value)) {
      return ReissuanceFieldError.invalidPhone;
    }
    return null;
  }

  bool isComplete(ParentRole role, {int? birthOrder}) => ParentDetail.values
      .every((field) => errorOf(field, role, birthOrder: birthOrder) == null);

  @override
  List<Object?> get props => [values];
}

/// A file a queried request was sent with, already in storage under [key].
final class KeptFile extends Equatable {
  const KeptFile({required this.key, required this.mimeType});

  final String key;
  final String mimeType;

  @override
  List<Object?> get props => [key, mimeType];
}

/// The birth reissuance form in progress.
final class BirthReissuanceForm extends Equatable {
  const BirthReissuanceForm({
    this.step = BirthReissuanceStep.child,
    this.child = const ChildParticulars(),
    this.mother = const ParentParticulars(),
    this.father = const ParentParticulars(),
    this.document,
    this.signature,
    this.keptDocument,
    this.keptSignature,
  });

  factory BirthReissuanceForm.fromJson(Map<String, Object?> json) {
    final step = json['step'];
    return BirthReissuanceForm(
      step: step is String
          ? BirthReissuanceStep.values.asNameMap()[step] ??
                BirthReissuanceStep.child
          : BirthReissuanceStep.child,
      child: ChildParticulars.fromJson(json['child']),
      mother: ParentParticulars.fromJson(json['mother']),
      father: ParentParticulars.fromJson(json['father']),
      document: AttachedFile.fromJson(json['document']),
      signature: json['signature'] as String?,
    );
  }

  final BirthReissuanceStep step;
  final ChildParticulars child;
  final ParentParticulars mother;
  final ParentParticulars father;

  /// The one optional supporting document, in private storage.
  final AttachedFile? document;

  /// The parent's drawn signature (PNG), in private storage. Required.
  final String? signature;

  /// A queried request's document and signature, until replaced. Only in
  /// memory: a correction isn't saved on the device.
  final KeptFile? keptDocument;
  final KeptFile? keptSignature;

  /// The countries whose states, and the states whose LGAs, the answers
  /// use (Nigeria's states always: the child's places are there).
  ({Set<String> countries, Set<String> states}) get places => (
    countries: {
      ReissuanceCodes.nigeria,
      for (final parent in [mother, father]) ...[
        ?parent[ParentDetail.country],
        ?parent[ParentDetail.nationality],
      ],
    },
    states: {
      ?child[ChildField.stateOfBirth],
      ?child[ChildField.registrationState],
      for (final parent in [mother, father]) ...[
        ?parent[ParentDetail.state],
        ?parent[ParentDetail.stateOfOrigin],
      ],
    },
  );

  bool get hasDocument => document != null || keptDocument != null;

  bool get hasSignature => signature != null || keptSignature != null;

  /// Every file the form keeps, to delete with it.
  List<String> get files => [?document?.path, ?signature];

  ParentParticulars parent(ParentRole role) =>
      role == ParentRole.mother ? mother : father;

  bool isComplete(BirthReissuanceStep step) => switch (step) {
    BirthReissuanceStep.child => child.isComplete,
    BirthReissuanceStep.mother => mother.isComplete(
      ParentRole.mother,
      birthOrder: child.birthOrder,
    ),
    BirthReissuanceStep.father => father.isComplete(ParentRole.father),
    BirthReissuanceStep.documents => hasSignature,
    // Nothing to fill in; complete when everything before it is.
    BirthReissuanceStep.review =>
      BirthReissuanceStep.values
          .where((s) => s != BirthReissuanceStep.review)
          .every(isComplete),
  };

  BirthReissuanceForm copyWith({
    BirthReissuanceStep? step,
    ChildParticulars? child,
    ParentParticulars? mother,
    ParentParticulars? father,
    AttachedFile? Function()? document,
    String? Function()? signature,
    KeptFile? Function()? keptDocument,
    KeptFile? Function()? keptSignature,
  }) => BirthReissuanceForm(
    step: step ?? this.step,
    child: child ?? this.child,
    mother: mother ?? this.mother,
    father: father ?? this.father,
    document: document != null ? document() : this.document,
    signature: signature != null ? signature() : this.signature,
    keptDocument: keptDocument != null ? keptDocument() : this.keptDocument,
    keptSignature: keptSignature != null ? keptSignature() : this.keptSignature,
  );

  Map<String, Object?> toJson() => {
    'step': step.name,
    'child': child.values.toJson(),
    'mother': mother.values.toJson(),
    'father': father.values.toJson(),
    'document': document?.toJson(),
    'signature': signature,
  };

  @override
  List<Object?> get props => [
    step,
    child,
    mother,
    father,
    document,
    signature,
    keptDocument,
    keptSignature,
  ];
}
