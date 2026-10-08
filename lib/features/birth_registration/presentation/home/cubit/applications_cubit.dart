import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/applications_source.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';

part 'applications_state.dart';

/// Birth Registration (and Birth Attestation) home: status counts, the selected status's list and
/// the search box.
class ApplicationsCubit extends Cubit<ApplicationsState> {
  ApplicationsCubit(this._repository, {this.searchDelay = _defaultDelay})
    : super(const ApplicationsState());

  static const _defaultDelay = Duration(milliseconds: 400);

  final ApplicationsSource _repository;

  /// Wait after typing before searching, so each keystroke isn't a request.
  final Duration searchDelay;
  Timer? _searchTimer;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    final (counts, list) = await (
      _repository.counts(),
      _repository.applications(status: state.status, query: state.query),
    ).wait;
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: false,
        counts: counts is Ok<ApplicationCounts> ? counts.value : null,
        items: list is Ok<List<BirthApplicationSummary>> ? list.value : null,
        failure: switch ((counts, list)) {
          (Err(:final failure), _) || (_, Err(:final failure)) => failure,
          _ => null,
        },
      ),
    );
  }

  Future<void> statusSelected(ApplicationStatus status) async {
    if (status == state.status) return;
    emit(state.copyWith(status: status, items: const []));
    await _reloadList();
  }

  void queryChanged(String query) {
    _searchTimer?.cancel();
    emit(state.copyWith(query: query.trim()));
    _searchTimer = Timer(searchDelay, () => unawaited(_reloadList()));
  }

  Future<void> _reloadList() async {
    final status = state.status;
    final query = state.query;
    emit(state.copyWith(isLoading: true));
    final result = await _repository.applications(status: status, query: query);
    // Ignore a stale response after the filter changed.
    if (isClosed || status != state.status || query != state.query) return;
    switch (result) {
      case Ok(value: final items):
        emit(state.copyWith(isLoading: false, items: items));
      case Err(:final failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  /// Whether there's an unfinished application on this device to resume.
  Future<bool> hasSavedDraft() => _repository.hasResumableDraft();

  Future<void> discardDraft() => _repository.discardDraft();

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}
