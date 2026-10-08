import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/dashboard/domain/dashboard_repository.dart';
import 'package:vital_reg_mobile/features/dashboard/domain/entities/dashboard_summary.dart';

part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._repository, {required int currentYear})
    : super(DashboardState(year: currentYear, currentYear: currentYear));

  final DashboardRepository _repository;

  Future<void> load() async {
    final year = state.year;
    emit(state.copyWith(status: DashboardStatus.loading));
    final result = await _repository.summary(year: year);
    // Ignore a stale response if the year changed meanwhile.
    if (isClosed || year != state.year) return;
    switch (result) {
      case Ok(value: final summary):
        emit(state.copyWith(status: DashboardStatus.ready, summary: summary));
      case Err(:final failure):
        emit(state.copyWith(status: DashboardStatus.failure, failure: failure));
    }
  }

  /// A stat card was tapped: its numbers go in the chart.
  void categorySelected(RegistrationCategory category) =>
      emit(state.copyWith(category: category));

  Future<void> yearChanged(int year) async {
    if (year == state.year) return;
    emit(state.copyWith(year: year));
    await load();
  }
}
