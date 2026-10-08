import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_summary.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/still_birth_repository.dart';

part 'still_birth_home_state.dart';

/// Still Birth home: the total, the list and the search box.
class StillBirthHomeCubit extends Cubit<StillBirthHomeState> {
  StillBirthHomeCubit(this._repository, {this.searchDelay = _defaultDelay})
    : super(const StillBirthHomeState());

  static const _defaultDelay = Duration(milliseconds: 400);

  final StillBirthRepository _repository;

  /// Wait after typing before searching, so each keystroke isn't a request.
  final Duration searchDelay;
  Timer? _searchTimer;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    final (total, list) = await (
      _repository.count(),
      _repository.registrations(query: state.query),
    ).wait;
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: false,
        total: total is Ok<int> ? total.value : null,
        items: list is Ok<List<StillBirthSummary>> ? list.value : null,
        failure: () => switch ((total, list)) {
          (Err(:final failure), _) || (_, Err(:final failure)) => failure,
          _ => null,
        },
      ),
    );
  }

  void queryChanged(String query) {
    _searchTimer?.cancel();
    emit(state.copyWith(query: query.trim()));
    _searchTimer = Timer(searchDelay, () => unawaited(_reloadList()));
  }

  Future<void> _reloadList() async {
    final query = state.query;
    emit(state.copyWith(isLoading: true));
    final result = await _repository.registrations(query: query);
    // Ignore a stale response after the search changed.
    if (isClosed || query != state.query) return;
    emit(switch (result) {
      Ok(value: final items) => state.copyWith(
        isLoading: false,
        items: items,
        failure: () => null,
      ),
      Err(:final failure) => state.copyWith(
        isLoading: false,
        failure: () => failure,
      ),
    });
  }

  /// Whether there's an unfinished registration on this device to resume.
  Future<bool> hasSavedDraft() => _repository.hasResumableDraft();

  Future<void> discardDraft() => _repository.discardDraft();

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}
