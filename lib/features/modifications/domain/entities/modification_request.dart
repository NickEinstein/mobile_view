import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';

/// The answers on the request screen: what to correct and why. Choosing a
/// type or field clears the choices below it.
final class ModificationRequest extends Equatable {
  const ModificationRequest({
    required this.kind,
    this.type,
    this.field,
    this.reason,
    this.comment = '',
  });

  static const commentMaxLength = 200;

  /// The request a sent one was made with, from the API's values; null
  /// when they don't match anything this app offers.
  static ModificationRequest? fromApi(
    ModificationKind kind, {
    required String? type,
    required String? field,
    required String? reason,
    String? comment,
  }) {
    bool same(String a, String? b) => a.toLowerCase() == b?.toLowerCase();
    final modType = kind.types
        .where((option) => same(option.apiValue, type))
        .firstOrNull;
    if (modType == null) return null;
    var request = ModificationRequest(
      kind: kind,
      comment: comment ?? '',
    ).withType(modType);
    if (request.needsField) {
      final modField = modType.fields
          .where((option) => same(option.apiValue, field))
          .firstOrNull;
      if (modField == null) return null;
      request = request.withField(modField);
    }
    final modReason = request.reasons
        .where((option) => same(option.apiValue, reason))
        .firstOrNull;
    return modReason == null ? request : request.withReason(modReason);
  }

  final ModificationKind kind;
  final ModificationType? type;

  /// Only for types that list fields.
  final ModificationField? field;
  final ModificationReason? reason;
  final String comment;

  bool get needsField => type?.fields.isNotEmpty ?? false;

  /// The reasons that apply to what's chosen so far.
  List<ModificationReason> get reasons {
    final type = this.type;
    if (type == null) return const [];
    if (!needsField) return type.reasons;
    return field?.reasons ?? const [];
  }

  bool get isComplete =>
      type != null &&
      (!needsField || field != null) &&
      reason != null &&
      reasons.contains(reason);

  /// A date of birth change needs supporting documents and has its own fee.
  bool get changesDateOfBirth => field?.isDateOfBirth ?? false;

  /// What goes as `mod_field`: the field, or for a type
  /// without fields (e.g. "Mother Name"), the type itself.
  String? get apiField => field?.apiValue ?? type?.apiValue;

  /// The record values this request may change; everything else on the
  /// form is read-only.
  Set<RecordField> get editableFields => switch ((type, field)) {
    (_, ModificationField.childName || ModificationField.applicantName) ||
    (ModificationType.deceasedName, _) => const {
      RecordField.surname,
      RecordField.firstName,
      RecordField.middleName,
    },
    (
      _,
      ModificationField.childDateOfBirth ||
          ModificationField.applicantDateOfBirth,
    ) =>
      const {RecordField.dateOfBirth},
    (_, ModificationField.childSex || ModificationField.applicantSex) ||
    (ModificationType.deceasedSex, _) => const {RecordField.sex},
    (
      _,
      ModificationField.childPlaceOfBirth ||
          ModificationField.applicantPlaceOfBirth,
    ) =>
      const {
        RecordField.birthState,
        RecordField.birthLga,
        RecordField.birthTown,
      },
    (_, ModificationField.applicantStateOfOrigin) => const {
      RecordField.originState,
      RecordField.originLga,
      RecordField.originTown,
    },
    (ModificationType.motherName || ModificationType.applicantMotherName, _) =>
      const {
        RecordField.motherSurname,
        RecordField.motherFirstName,
        RecordField.motherMiddleName,
      },
    (ModificationType.fatherName, _) => const {
      RecordField.fatherSurname,
      RecordField.fatherFirstName,
      RecordField.fatherMiddleName,
    },
    // The attestation record has no father's middle name.
    (ModificationType.applicantFatherName, _) => const {
      RecordField.fatherSurname,
      RecordField.fatherFirstName,
    },
    (ModificationType.deceasedAgeAtDeath, _) => const {RecordField.ageAtDeath},
    (ModificationType.deceasedDateOfDeath, _) => const {
      RecordField.dateOfDeath,
    },
    _ => const {},
  };

  /// The backend's transaction type for this request's fee.
  String get paymentType =>
      changesDateOfBirth ? dateOfBirthPaymentType : kind.paymentType;

  static const dateOfBirthPaymentType = 'dob_modification_payment';

  ModificationRequest withType(ModificationType type) => ModificationRequest(
    kind: kind,
    type: type,
    comment: comment,
  )._withOnlyReason();

  ModificationRequest withField(ModificationField field) => ModificationRequest(
    kind: kind,
    type: type,
    field: field,
    comment: comment,
  )._withOnlyReason();

  ModificationRequest withReason(ModificationReason reason) =>
      ModificationRequest(
        kind: kind,
        type: type,
        field: field,
        reason: reason,
        comment: comment,
      );

  ModificationRequest withComment(String comment) => ModificationRequest(
    kind: kind,
    type: type,
    field: field,
    reason: reason,
    comment: comment,
  );

  /// Picks the reason when there is only one to pick, as in the designs.
  ModificationRequest _withOnlyReason() =>
      reasons.length == 1 ? withReason(reasons.single) : this;

  @override
  List<Object?> get props => [kind, type, field, reason, comment];
}
