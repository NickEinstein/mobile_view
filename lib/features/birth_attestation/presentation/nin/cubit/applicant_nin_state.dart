part of 'applicant_nin_cubit.dart';

final class ApplicantNinState extends Equatable {
  const ApplicantNinState({
    this.hasNin,
    this.nin = '',
    this.isSubmitting = false,
    this.isDone = false,
    this.isUnderAge = false,
    this.failure,
  });

  /// Null until the user answers.
  final bool? hasNin;
  final String nin;
  final bool isSubmitting;

  /// The application is started; the page moves on to the face.
  final bool isDone;

  /// The NIN belongs to someone under 18.
  final bool isUnderAge;
  final Failure? failure;

  bool get ninLooksValid => ApplicantNinCubit._ninPattern.hasMatch(nin);

  bool get canProceed => switch (hasNin) {
    null => false,
    false => true,
    true => ninLooksValid,
  };

  /// [isUnderAge] and [failure] are cleared unless passed, so editing
  /// dismisses the error.
  ApplicantNinState copyWith({
    bool? hasNin,
    String? nin,
    bool? isSubmitting,
    bool? isDone,
    bool isUnderAge = false,
    Failure? failure,
  }) => ApplicantNinState(
    hasNin: hasNin ?? this.hasNin,
    nin: nin ?? this.nin,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isDone: isDone ?? this.isDone,
    isUnderAge: isUnderAge,
    failure: failure,
  );

  @override
  List<Object?> get props => [
    hasNin,
    nin,
    isSubmitting,
    isDone,
    isUnderAge,
    failure,
  ];

  /// Keeps the NIN out of logs and test output.
  @override
  String toString() => 'ApplicantNinState(hasNin: $hasNin, done: $isDone)';
}
