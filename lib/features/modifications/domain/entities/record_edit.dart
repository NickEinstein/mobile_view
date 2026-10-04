import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';

enum RecordEditError {
  required,
  invalidName,
  invalidAge,
  futureDate,

  /// Nothing the request may change was changed.
  unchanged,
}

/// The corrected values: the record's, with only [editable] ones changed.
final class RecordEdit extends Equatable {
  const RecordEdit({
    required this.record,
    required this.editable,
    required this.values,
  });

  factory RecordEdit.start(
    ModificationRecord record,
    Set<RecordField> editable,
  ) => RecordEdit(record: record, editable: editable, values: record.values);

  static const maxAge = 150;

  /// Letters, with spaces, hyphens or apostrophes between them.
  static final _namePattern = RegExp(r"^[A-Za-z]+([ '\-][A-Za-z]+)*$");

  final ModificationRecord record;
  final Set<RecordField> editable;
  final Map<RecordField, String> values;

  String? operator [](RecordField field) => values[field];

  /// [field] set to [value] (blank removes it). A new state clears its
  /// LGAs. Read-only fields never change.
  RecordEdit set(RecordField field, String? value) {
    if (!editable.contains(field)) return this;
    final next = Map<RecordField, String>.of(values);
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      next.remove(field);
    } else {
      next[field] = trimmed;
    }
    final lga = field.lgaField;
    if (lga != null && trimmed != values[field]) next.remove(lga);
    return RecordEdit(record: record, editable: editable, values: next);
  }

  bool get isChanged =>
      editable.any((field) => values[field] != record.values[field]);

  RecordEditError? errorOf(RecordField field, {required DateTime today}) {
    if (!editable.contains(field)) return null;
    final value = values[field];
    if (value == null) {
      return field.isOptional ? null : RecordEditError.required;
    }
    if (field.isName && !_namePattern.hasMatch(value)) {
      return RecordEditError.invalidName;
    }
    if (field == RecordField.ageAtDeath) {
      final age = int.tryParse(value);
      if (age == null || age < 0 || age > maxAge) {
        return RecordEditError.invalidAge;
      }
    }
    if (field.isDate) {
      final date = DateTime.tryParse(value);
      if (date == null) return RecordEditError.required;
      if (date.isAfter(DateTime(today.year, today.month, today.day))) {
        return RecordEditError.futureDate;
      }
    }
    return null;
  }

  /// [requireChange] is off for a queried request, which may be resent as
  /// it was (e.g. with new documents).
  bool isValid({required DateTime today, bool requireChange = true}) =>
      (isChanged || !requireChange) &&
      editable.every((field) => errorOf(field, today: today) == null);

  @override
  List<Object?> get props => [record, editable, values];

  @override
  String toString() => 'RecordEdit(${editable.length} editable)';
}
