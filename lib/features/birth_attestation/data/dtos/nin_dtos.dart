import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';

/// `GET /verify-nin/{nin}`; null when there is no record (`status` isn't
/// 1).
ApplicantNinRecord? ninRecordFromJson(Object? json, {required String nin}) {
  final map = _nimc(json);
  if (map['status'] != 1) return null;
  return ApplicantNinRecord(
    nin: nin,
    surname: map.requireString('lastname'),
    firstName: map.requireString('firstname'),
    middleName: _blankToNull(map.optionalString('middlename')),
    dateOfBirth: _ddMmYyyy(map.requireString('dob')),
    sex: switch (map.optionalString('gender')?.toLowerCase()) {
      'm' => Sex.male,
      'f' => Sex.female,
      _ => null,
    },
    phone: _blankToNull(map.optionalString('phone')),
    // Sic: the service spells it "orgin".
    stateOfOrigin: _blankToNull(map.optionalString('state_orgin')),
    lgaOfOrigin: _blankToNull(map.optionalString('lga_orgin')),
  );
}

/// The NIN record's `photo` (base64), which the face service matches
/// against. Null when there is none.
String? ninPhotoFromJson(Object? json) =>
    _blankToNull(_nimc(json).optionalString('photo'));

/// The record under `nimc` (or the reply itself, without one).
JsonMap _nimc(Object? json) {
  final map = json.asJsonMap();
  return switch (map['nimc']) {
    final JsonMap nimc => nimc,
    _ => map,
  };
}

String? _blankToNull(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

DateTime _ddMmYyyy(String raw) {
  final parts = raw.split('-');
  final day = parts.length == 3 ? int.tryParse(parts[0]) : null;
  final month = parts.length == 3 ? int.tryParse(parts[1]) : null;
  final year = parts.length == 3 ? int.tryParse(parts[2]) : null;
  if (day == null || month == null || year == null) {
    throw const FormatException('Expected a DD-MM-YYYY date.');
  }
  return DateTime(year, month, day);
}
