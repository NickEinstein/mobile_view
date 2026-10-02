/// Rules shared by the Mother, Father and Informant steps.
library;

/// Why a field on the Mother, Father or Informant step isn't valid.
enum PersonFieldError {
  required,
  invalidNin,
  invalidPhone,
  invalidAge,

  /// The informant must give a NIN when neither parent did: the API needs
  /// at least one NIN, and a tracking ID doesn't count.
  informantNinRequired,

  /// Tracking IDs are 15 characters.
  invalidTrackingId,
}

/// Parents' ages at the birth, in years.
const minParentAge = 10;
const maxParentAge = 99;

final _ninPattern = RegExp(r'^\d{11}$');
final _phonePattern = RegExp(r'^\+?\d{10,14}$');

bool isValidNin(String value) => _ninPattern.hasMatch(value);

/// As the API checks it: exactly 15 characters.
bool isValidTrackingId(String value) => value.trim().length == 15;

bool isValidPhone(String value) => _phonePattern.hasMatch(value);

bool isValidParentAge(String value) {
  final age = int.tryParse(value);
  return age != null && age >= minParentAge && age <= maxParentAge;
}

/// Stored value of a yes/no question.
const answerYes = 'yes';
const answerNo = 'no';

/// [values] with [field] set to [value] (blank removes it) and [clearing]
/// removed, because their options depended on the old value.
Map<F, String> withValue<F extends Enum>(
  Map<F, String> values,
  F field,
  String? value,
  Iterable<F> clearing,
) {
  final next = Map<F, String>.of(values);
  if (value == null || value.trim().isEmpty) {
    next.remove(field);
  } else {
    next[field] = value;
  }
  for (final dependent in clearing) {
    next.remove(dependent);
  }
  return next;
}

Map<F, String> valuesFromJson<F extends Enum>(Object? json, List<F> fields) => {
  if (json is Map<String, Object?>)
    for (final field in fields)
      if (json[field.name] case final String value) field: value,
};

Map<String, Object?> valuesToJson<F extends Enum>(Map<F, String> values) => {
  for (final entry in values.entries) entry.key.name: entry.value,
};
