import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/attestation_face_source.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/face_source.dart';

part 'face_validation_state.dart';

/// "Face Validation": with a NIN the photo must match the NIN photo;
/// without one it is only captured.
class FaceValidationCubit extends Cubit<FaceValidationState> {
  /// For the Birth Attestation draft.
  FaceValidationCubit(BirthAttestationRepository repository)
    : this.source(AttestationFaceSource(repository));

  /// For another service's application (Certificate Reissuance).
  FaceValidationCubit.source(this._source) : super(const FaceValidationState());

  final FaceSource _source;
  FaceSubject? _subject;

  /// Reads the application started before this step.
  Future<void> load() async {
    _subject = await _source.subject();
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: false,
        matchesNin: _subject?.nin != null,
        missingApplication: _subject == null,
      ),
    );
  }

  void guidelinesRead() =>
      emit(state.copyWith(stage: FaceValidationStage.capture));

  /// Back from the camera stage to the guidelines.
  void backToGuidelines() =>
      emit(state.copyWith(stage: FaceValidationStage.guidelines));

  /// [capturedPath] is the camera's temporary file; it is moved to private
  /// storage, replacing the previous photo.
  Future<void> captured(String capturedPath) async {
    final kept = await _source.keepPhoto(
      capturedPath,
      replacing: state.photoPath,
    );
    if (isClosed) {
      await _source.deleteFile(kept);
      return;
    }
    emit(state.copyWith(photoPath: kept));
  }

  Future<void> validate() async {
    final photo = state.photoPath;
    final subject = _subject;
    if (photo == null || subject == null || state.isChecking || state.isDone) {
      return;
    }
    final nin = subject.nin;
    if (nin == null) {
      await _keep(photo, matched: false);
      return;
    }

    emit(state.copyWith(isChecking: true));
    final result = await _source.matchFace(photo, nin: nin);
    if (isClosed) return;
    switch (result) {
      case Ok(value: true):
        await _keep(photo, matched: true);
      case Ok(value: false):
        emit(state.copyWith(isChecking: false, notMatched: true));
      case Err(:final failure):
        emit(state.copyWith(isChecking: false, failure: failure));
    }
  }

  Future<void> _keep(String photo, {required bool matched}) async {
    await _source.keepFace(photo, matched: matched);
    if (isClosed) return;
    emit(state.copyWith(isChecking: false, isDone: true));
  }

  /// A photo that was never kept isn't needed once the user leaves.
  @override
  Future<void> close() async {
    final photo = state.photoPath;
    if (photo != null && !state.isDone) await _source.deleteFile(photo);
    return super.close();
  }
}
