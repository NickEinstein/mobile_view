import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_record.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_reference_data.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/surrogacy_birth_repository.dart';

/// "Certificate Details" for one application. A draft can be continued on
/// this device ("Continue").
class SurrogacyDetailsCubit extends Cubit<SurrogacyDetailsState> {
  SurrogacyDetailsCubit(this._repository, {required this.id})
    : super(const SurrogacyDetailsState());

  final SurrogacyBirthRepository _repository;
  final String id;

  Future<void> load() async {
    emit(const SurrogacyDetailsState());
    final record = await _repository.details(id);
    final reference = switch (record) {
      Ok(value: final r) => await _repository.referenceData(
        withLgasOf: r.draft.chosenStates,
      ),
      Err(:final failure) => Err<SurrogacyReferenceData>(failure),
    };
    if (isClosed) return;
    switch ((record, reference)) {
      case (Ok(value: final record), Ok(value: final data)):
        emit(
          SurrogacyDetailsState(
            isLoading: false,
            record: record,
            referenceData: data,
          ),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(SurrogacyDetailsState(isLoading: false, failure: failure));
    }
  }

  /// Whether another registration is unfinished on this device, which
  /// continuing this draft would replace.
  Future<bool> wouldReplaceDraft() async {
    final draft = await _repository.loadDraft();
    return draft != null && draft.referenceId != state.record?.referenceId;
  }

  /// Loads the draft as the server last saved it onto this device. The
  /// page then opens the stage it reached.
  Future<void> continueDraft() async {
    final record = state.record;
    final data = state.referenceData;
    if (record == null || data == null || state.isResuming) return;
    emit(state.copyWith(isResuming: true, resumeFailure: () => null));
    final result = await _repository.resume(record.referenceId);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final resumed):
        await _repository.discardDraft();
        final draft = resumed.draft.withRegistrationLocation(
          data.locationOfCenter,
        );
        await _repository.saveDraft(draft);
        if (isClosed) return;
        emit(state.copyWith(isResuming: false, resumedAt: draft.stage));
      case Err(:final failure):
        emit(state.copyWith(isResuming: false, resumeFailure: () => failure));
    }
  }
}

final class SurrogacyDetailsState extends Equatable {
  const SurrogacyDetailsState({
    this.isLoading = true,
    this.record,
    this.referenceData,
    this.failure,
    this.isResuming = false,
    this.resumeFailure,
    this.resumedAt,
  });

  final bool isLoading;
  final SurrogacyRecord? record;
  final SurrogacyReferenceData? referenceData;
  final Failure? failure;
  final bool isResuming;
  final Failure? resumeFailure;

  /// Set once a draft is on the device: where to pick it up.
  final SurrogacyStage? resumedAt;

  SurrogacyDetailsState copyWith({
    bool? isResuming,
    Failure? Function()? resumeFailure,
    SurrogacyStage? resumedAt,
  }) => SurrogacyDetailsState(
    isLoading: isLoading,
    record: record,
    referenceData: referenceData,
    failure: failure,
    isResuming: isResuming ?? this.isResuming,
    resumeFailure: resumeFailure != null ? resumeFailure() : this.resumeFailure,
    resumedAt: resumedAt ?? this.resumedAt,
  );

  @override
  List<Object?> get props => [
    isLoading,
    record,
    referenceData,
    failure,
    isResuming,
    resumeFailure,
    resumedAt,
  ];
}
