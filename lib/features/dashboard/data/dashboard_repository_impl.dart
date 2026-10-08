import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/dashboard/data/dtos/dashboard_summary_dto.dart';
import 'package:vital_reg_mobile/features/dashboard/domain/dashboard_repository.dart';
import 'package:vital_reg_mobile/features/dashboard/domain/entities/dashboard_summary.dart';

/// Cards from `GET /statistics/counts` (all time); charts from
/// `GET /statistics/<type>?period=<year>`.
class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<DashboardSummary>> summary({required int year}) async {
    final counts = _client.get(
      '/statistics/counts',
      decode: DashboardSummaryDto.countsFromJson,
    );
    final monthly = {
      for (final category in RegistrationCategory.values)
        category: _client.get(
          '/statistics/${category.apiName}',
          query: {'period': year},
          decode: DashboardSummaryDto.monthlyFromJson,
        ),
    };

    final Map<RegistrationCategory, int> totals;
    switch (await counts) {
      case Ok(:final value):
        totals = value;
      case Err(:final failure):
        return Err(failure);
    }
    final stats = <RegistrationCategory, CategoryStats>{};
    for (final MapEntry(key: category, value: pending) in monthly.entries) {
      switch (await pending) {
        case Ok(value: final months):
          stats[category] = CategoryStats(
            total: totals[category] ?? 0,
            monthly: months,
          );
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Ok(DashboardSummary(year: year, stats: stats));
  }
}
