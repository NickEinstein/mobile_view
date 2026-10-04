import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';

/// A value on a registered record. Dates are `yyyy-MM-dd`; options are
/// the API's ids.
enum RecordField {
  surname,
  firstName,
  middleName,
  dateOfBirth,
  sex,
  birthState,
  birthLga,
  birthTown,
  originState,
  originLga,
  originTown,
  dateOfDeath,
  ageAtDeath,
  motherSurname,
  motherFirstName,
  motherMiddleName,
  fatherSurname,
  fatherFirstName,
  fatherMiddleName;

  /// The LGA list that depends on this state, if it is one.
  RecordField? get lgaField => switch (this) {
    birthState => birthLga,
    originState => originLga,
    _ => null,
  };

  /// The state this LGA belongs to, if it is one.
  RecordField? get stateField => switch (this) {
    birthLga => birthState,
    originLga => originState,
    _ => null,
  };

  bool get isDate => this == dateOfBirth || this == dateOfDeath;

  bool get isOptional =>
      this == middleName ||
      this == motherMiddleName ||
      this == fatherMiddleName;

  bool get isName => switch (this) {
    surname ||
    firstName ||
    middleName ||
    motherSurname ||
    motherFirstName ||
    motherMiddleName ||
    fatherSurname ||
    fatherFirstName ||
    fatherMiddleName => true,
    _ => false,
  };
}

/// The registered record a request corrects, found by its certificate
/// number.
final class ModificationRecord extends Equatable {
  const ModificationRecord({
    required this.kind,
    required this.recordId,
    required this.certificateNumber,
    required this.name,
    this.values = const {},
  });

  final ModificationKind kind;

  /// The record's own id, which the request is sent against (e.g.
  /// `Birth_Reg_ID`).
  final String recordId;
  final String certificateNumber;

  /// The child's, applicant's or deceased's name.
  final String name;
  final Map<RecordField, String> values;

  String? operator [](RecordField field) => values[field];

  @override
  List<Object?> get props => [kind, recordId, certificateNumber, name, values];

  /// Keeps personal data out of logs and test output.
  @override
  String toString() => 'ModificationRecord(${kind.name})';
}
