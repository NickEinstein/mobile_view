import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/adopted_child_repository.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_draft.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_record.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_reference_data.dart';

/// "Certificate Details" for one application. A draft can be continued on
/// this device ("Continue").
class AdoptionDetailsCubit extends Cubit<AdoptionDetailsState> {
  AdoptionDetailsCubit(this._repository, {required this.id})
    : super(const AdoptionDetailsState());

  final AdoptedChildRepository _repository;
  final String id;

  Future<void> load() async {
    emit(const AdoptionDetailsState());
    final record = await _repository.details(id);
    final reference = switch (record) {
      Ok(value: final r) => await _repository.referenceData(
        withLgasOf: r.draft.chosenStates,
      ),
      Err(:final failure) => Err<AdoptionReferenceData>(failure),
    };
    if (isClosed) return;
    switch ((record, reference)) {
      case (Ok(value: final record), Ok(value: final data)):
        emit(
          AdoptionDetailsState(
            isLoading: false,
            record: record,
            referenceData: data,
          ),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(AdoptionDetailsState(isLoading: false, failure: failure));
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
    if (record == null || state.isResuming) return;
    emit(state.copyWith(isResuming: true, resumeFailure: () => null));
    final result = await _repository.resume(record.referenceId);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final resumed):
        await _repository.discardDraft();
        final draft = resumed.draft;
        await _repository.saveDraft(draft);
        if (isClosed) return;
        emit(state.copyWith(isResuming: false, resumedAt: draft.stage));
      case Err(:final failure):
        emit(state.copyWith(isResuming: false, resumeFailure: () => failure));
    }
  }
}

final class AdoptionDetailsState extends Equatable {
  const AdoptionDetailsState({
    this.isLoading = true,
    this.record,
    this.referenceData,
    this.failure,
    this.isResuming = false,
    this.resumeFailure,
    this.resumedAt,
  });

  final bool isLoading;
  final AdoptionRecord? record;
  final AdoptionReferenceData? referenceData;
  final Failure? failure;
  final bool isResuming;
  final Failure? resumeFailure;

  /// Set once a draft is on the device: where to pick it up.
  final AdoptionStage? resumedAt;

  AdoptionDetailsState copyWith({
    bool? isResuming,
    Failure? Function()? resumeFailure,
    AdoptionStage? resumedAt,
  }) => AdoptionDetailsState(
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
