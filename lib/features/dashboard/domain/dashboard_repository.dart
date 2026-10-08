import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/dashboard/domain/entities/dashboard_summary.dart';

abstract interface class DashboardRepository {
  Future<Result<DashboardSummary>> summary({required int year});
}
