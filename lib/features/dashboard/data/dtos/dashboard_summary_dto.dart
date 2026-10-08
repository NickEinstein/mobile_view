import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/dashboard/domain/entities/dashboard_summary.dart';

/// The backend's `/statistics` answers. Counts are SQL `COUNT`s, which
/// may arrive as strings ("12").
abstract final class DashboardSummaryDto {
  /// `GET /statistics/counts` → `{birth, attestation, death, stillbirth}`.
  static Map<RegistrationCategory, int> countsFromJson(Object? json) {
    final map = json.asJsonMap();
    return {
      for (final category in RegistrationCategory.values)
        category: _count(map[category.apiName], category.apiName),
    };
  }

  /// `GET /statistics/<type>?period=<year>` → 12 counts, January first.
  static List<int> monthlyFromJson(Object? json) {
    if (json is! List<Object?> || json.length != 12) {
      throw const FormatException('Expected 12 monthly counts.');
    }
    return [for (final value in json) _count(value, 'monthly')];
  }

  static int _count(Object? value, String what) => switch (value) {
    final int count => count,
    final num count when count == count.truncate() => count.toInt(),
    final String text when int.tryParse(text) != null => int.parse(text),
    null => 0,
    _ => throw FormatException('Expected a count for "$what".'),
  };
}

extension RegistrationCategoryApi on RegistrationCategory {
  /// The name in `/statistics` paths and in the counts' keys.
  String get apiName => switch (this) {
    RegistrationCategory.birthRegistration => 'birth',
    RegistrationCategory.birthAttestation => 'attestation',
    RegistrationCategory.deathRegistration => 'death',
    RegistrationCategory.stillBirth => 'stillbirth',
  };
}
