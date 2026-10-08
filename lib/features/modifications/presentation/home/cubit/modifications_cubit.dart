import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_summary.dart';
import 'package:vital_reg_mobile/features/modifications/domain/modifications_repository.dart';

part 'modifications_state.dart';

/// Modifications home: a count per kind of record, and the selected kind's
/// requests in the chosen status, filtered by the search box.
class ModificationsCubit extends Cubit<ModificationsState> {
  ModificationsCubit(this._repository, {this.searchDelay = _defaultDelay})
    : super(const ModificationsState());

  static const _defaultDelay = Duration(milliseconds: 400);

  final ModificationsRepository _repository;

  /// Wait after typing before searching, so each keystroke isn't a request.
  final Duration searchDelay;
  Timer? _searchTimer;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    final counts = Future.wait([
      for (final kind in ModificationKind.values) _repository.count(kind),
    ]);
    final (countResults, list) = await (counts, _fetchList()).wait;
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: false,
        counts: {
          for (final (i, kind) in ModificationKind.values.indexed)
            if (countResults[i] case Ok(:final value)) kind: value,
        },
        items: list is Ok<List<ModificationSummary>> ? list.value : null,
        failure: switch (list) {
          Err(:final failure) => failure,
          // A missing count shows as 0; only a failed list is reported.
          _ => null,
        },
      ),
    );
  }

  Future<void> kindSelected(ModificationKind kind) async {
    if (kind == state.kind) return;
    emit(state.copyWith(kind: kind, items: const []));
    await _reloadList();
  }

  Future<void> statusSelected(ModificationStatus status) async {
    if (status == state.status) return;
    emit(state.copyWith(status: status, items: const []));
    await _reloadList();
  }

  void queryChanged(String query) {
    _searchTimer?.cancel();
    emit(state.copyWith(query: query.trim()));
    _searchTimer = Timer(searchDelay, () => unawaited(_reloadList()));
  }

  Future<Result<List<ModificationSummary>>> _fetchList() => _repository
      .requests(kind: state.kind, status: state.status, query: state.query);

  Future<void> _reloadList() async {
    final filter = (state.kind, state.status, state.query);
    emit(state.copyWith(isLoading: true));
    final result = await _fetchList();
    // Ignore a stale response after the filter changed.
    if (isClosed || filter != (state.kind, state.status, state.query)) return;
    switch (result) {
      case Ok(value: final items):
        emit(state.copyWith(isLoading: false, items: items));
      case Err(:final failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}
