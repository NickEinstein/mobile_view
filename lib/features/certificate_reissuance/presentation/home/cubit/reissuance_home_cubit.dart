import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';

part 'reissuance_home_state.dart';

/// Certificate Reissuance home: the Birth/Attestation tab's counts, and its
/// requests in the chosen card's status, filtered by the search box.
class ReissuanceHomeCubit extends Cubit<ReissuanceHomeState> {
  ReissuanceHomeCubit(this._repository, {this.searchDelay = _defaultDelay})
    : super(const ReissuanceHomeState());

  static const _defaultDelay = Duration(milliseconds: 400);

  final ReissuanceRepository _repository;

  /// Wait after typing before searching, so each keystroke isn't a request.
  final Duration searchDelay;
  Timer? _searchTimer;

  Future<void> load() async {
    final kind = state.kind;
    emit(state.copyWith(isLoading: true));
    final (counts, list) = await (_repository.counts(kind), _fetchList()).wait;
    if (isClosed || kind != state.kind) return;
    emit(
      state.copyWith(
        isLoading: false,
        // Missing counts show as 0; only a failed list is reported.
        counts: counts is Ok<ReissuanceCounts>
            ? counts.value
            : const ReissuanceCounts(),
        items: list is Ok<List<ReissuanceSummary>> ? list.value : null,
        failure: switch (list) {
          Err(:final failure) => failure,
          _ => null,
        },
      ),
    );
  }

  /// The Birth/Attestation tab: its own counts and list.
  Future<void> kindSelected(ReissuanceKind kind) async {
    if (kind == state.kind) return;
    emit(
      state.copyWith(
        kind: kind,
        counts: const ReissuanceCounts(),
        items: const [],
      ),
    );
    await load();
  }

  /// A card; null is "Total".
  Future<void> statusSelected(ReissuanceStatus? status) async {
    if (status == state.status) return;
    emit(state.copyWith(status: () => status, items: const []));
    await _reloadList();
  }

  void queryChanged(String query) {
    _searchTimer?.cancel();
    emit(state.copyWith(query: query.trim()));
    _searchTimer = Timer(searchDelay, () => unawaited(_reloadList()));
  }

  Future<Result<List<ReissuanceSummary>>> _fetchList() => _repository.requests(
    kind: state.kind,
    status: state.status,
    query: state.query,
  );

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
