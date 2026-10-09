import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/person_fields.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';

/// How the informant confirms their identity.
enum IdentityMode { signature, face }

/// Informant step fields, in form order. [signature] and [facePhoto] are
/// private file paths; [identityMode] is an [IdentityMode] name.
enum InformantField {
  relationship,
  surname,
  firstName,
  middleName,
  sameResidenceAsMother,
  country,
  state,
  lga,
  address,
  settlement,
  phone,
  nin,
  trackingId,
  identityMode,
  signature,
  facePhoto;

  List<InformantField> get dependents => switch (this) {
    country => const [state, lga],
    state => const [lga],
    _ => const [],
  };
}

/// "Particulars of Informant": the person reporting the birth.
final class InformantParticulars extends Equatable {
  const InformantParticulars([this.values = const {}]);

  factory InformantParticulars.fromJson(Object? json) =>
      InformantParticulars(valuesFromJson(json, InformantField.values));

  final Map<InformantField, String> values;

  String? operator [](InformantField field) => values[field];

  /// Signature unless the user picked face capture (the designs start on
  /// signature).
  IdentityMode get identityMode =>
      values[InformantField.identityMode] == IdentityMode.face.name
      ? IdentityMode.face
      : IdentityMode.signature;

  bool get livesWithMother =>
      values[InformantField.sameResidenceAsMother] == answerYes;

  /// The parent the informant is, by relationship (father "1", mother
  /// "2"); null for anyone else.
  ParentRole? get parentRole => switch (values[InformantField.relationship]) {
    '1' => ParentRole.father,
    '2' => ParentRole.mother,
    _ => null,
  };

  /// What a parent informant takes from that parent's step and can't
  /// change here. Phone and NIN stay editable, and edit the parent's own.
  static const fromParent = {
    InformantField.surname,
    InformantField.firstName,
    InformantField.middleName,
    InformantField.sameResidenceAsMother,
    InformantField.country,
    InformantField.state,
    InformantField.lga,
    InformantField.address,
    InformantField.settlement,
  };

  /// With [parent]'s details, for a parent informant. The mother lives
  /// where she lives; the father as he said.
  InformantParticulars copiedFrom(ParentParticulars parent, ParentRole role) {
    final next = withoutParent().values;
    String? from(ParentField field) =>
        parent.applies(field, role) ? parent[field] : null;
    void copy(InformantField field, String? value) {
      if (value != null) next[field] = value;
    }

    copy(InformantField.surname, from(ParentField.surname));
    copy(InformantField.firstName, from(ParentField.firstName));
    copy(InformantField.middleName, from(ParentField.middleName));
    final withMother =
        role == ParentRole.mother || parent.livesWithMother(role);
    copy(
      InformantField.sameResidenceAsMother,
      withMother ? answerYes : answerNo,
    );
    if (!withMother) {
      copy(InformantField.country, from(ParentField.country));
      copy(InformantField.state, from(ParentField.state));
      copy(InformantField.lga, from(ParentField.lga));
      copy(InformantField.address, from(ParentField.address));
      copy(InformantField.settlement, from(ParentField.settlement));
    }
    copy(InformantField.phone, from(ParentField.phone));
    copy(InformantField.nin, from(ParentField.nin));
    return InformantParticulars(next);
  }

  /// Without anything copied from a parent (the informant is someone else
  /// now).
  InformantParticulars withoutParent() => InformantParticulars(
    Map<InformantField, String>.of(values)..removeWhere(
      (field, _) =>
          fromParent.contains(field) ||
          field == InformantField.phone ||
          field == InformantField.nin,
    ),
  );

  /// Whether [field] is asked, given the answers so far.
  bool applies(InformantField field) => switch (field) {
    InformantField.country ||
    InformantField.address ||
    InformantField.settlement => !livesWithMother,
    InformantField.state || InformantField.lga =>
      !livesWithMother &&
          (values[InformantField.country] ?? ReferenceData.nigeria) ==
              ReferenceData.nigeria,
    InformantField.signature => identityMode == IdentityMode.signature,
    InformantField.facePhoto => identityMode == IdentityMode.face,
    _ => true,
  };

  InformantParticulars set(InformantField field, String? value) =>
      InformantParticulars(withValue(values, field, value, field.dependents));

  /// [parentsGaveNin]: the NIN is only required when neither parent gave
  /// one.
  PersonFieldError? errorOf(
    InformantField field, {
    required bool parentsGaveNin,
  }) {
    if (!applies(field)) return null;
    final value = values[field];
    switch (field) {
      case InformantField.middleName || InformantField.identityMode:
        return null;
      case InformantField.trackingId:
        return value == null || isValidTrackingId(value)
            ? null
            : PersonFieldError.invalidTrackingId;
      case InformantField.nin:
        if (value != null) {
          return isValidNin(value) ? null : PersonFieldError.invalidNin;
        }
        return parentsGaveNin ? null : PersonFieldError.informantNinRequired;
      case InformantField.phone when value != null && !isValidPhone(value):
        return PersonFieldError.invalidPhone;
      case _:
        return value == null ? PersonFieldError.required : null;
    }
  }

  bool isComplete({required bool parentsGaveNin}) => InformantField.values
      .every((field) => errorOf(field, parentsGaveNin: parentsGaveNin) == null);

  /// Captured files, including ones for the identity mode not chosen.
  Iterable<String> get files => [
    ?values[InformantField.signature],
    ?values[InformantField.facePhoto],
  ];

  Map<String, Object?> toJson() => valuesToJson(values);

  @override
  List<Object?> get props => [values];
}
