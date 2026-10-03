part of 'face_validation_cubit.dart';

enum FaceValidationStage { guidelines, capture }

final class FaceValidationState extends Equatable {
  const FaceValidationState({
    this.stage = FaceValidationStage.guidelines,
    this.isLoading = true,
    this.matchesNin = false,
    this.missingApplication = false,
    this.photoPath,
    this.isChecking = false,
    this.isDone = false,
    this.notMatched = false,
    this.failure,
  });

  final FaceValidationStage stage;
  final bool isLoading;

  /// The applicant gave a NIN, so the face is matched against its photo.
  final bool matchesNin;

  /// No application was started (e.g. the NIN step was skipped); the page
  /// can't continue.
  final bool missingApplication;

  /// The latest photo, in private storage.
  final String? photoPath;
  final bool isChecking;

  /// Kept in the application; the page moves on.
  final bool isDone;

  /// The identity service didn't match the latest photo.
  final bool notMatched;
  final Failure? failure;

  bool get canContinue =>
      photoPath != null && !isChecking && !isDone && !missingApplication;

  /// [notMatched] and [failure] are cleared unless passed, so a new photo
  /// or attempt starts clean.
  FaceValidationState copyWith({
    FaceValidationStage? stage,
    bool? isLoading,
    bool? matchesNin,
    bool? missingApplication,
    String? photoPath,
    bool? isChecking,
    bool? isDone,
    bool notMatched = false,
    Failure? failure,
  }) => FaceValidationState(
    stage: stage ?? this.stage,
    isLoading: isLoading ?? this.isLoading,
    matchesNin: matchesNin ?? this.matchesNin,
    missingApplication: missingApplication ?? this.missingApplication,
    photoPath: photoPath ?? this.photoPath,
    isChecking: isChecking ?? this.isChecking,
    isDone: isDone ?? this.isDone,
    notMatched: notMatched,
    failure: failure,
  );

  @override
  List<Object?> get props => [
    stage,
    isLoading,
    matchesNin,
    missingApplication,
    photoPath,
    isChecking,
    isDone,
    notMatched,
    failure,
  ];
}
