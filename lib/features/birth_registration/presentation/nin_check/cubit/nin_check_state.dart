part of 'nin_check_cubit.dart';

final class NinCheckState extends Equatable {
  const NinCheckState({
    this.hasNin,
    this.nin = '',
    this.isSubmitting = false,
    this.isDone = false,
    this.failure,
  });

  /// Null until the user answers.
  final bool? hasNin;
  final String nin;
  final bool isSubmitting;

  /// The draft exists; the page moves on to the form.
  final bool isDone;
  final Failure? failure;

  bool get ninLooksValid => NinCheckCubit._ninPattern.hasMatch(nin);

  bool get canProceed => switch (hasNin) {
    null => false,
    false => true,
    true => ninLooksValid,
  };

  /// [failure] is cleared unless passed, so editing dismisses the error.
  NinCheckState copyWith({
    bool? hasNin,
    String? nin,
    bool? isSubmitting,
    bool? isDone,
    Failure? failure,
  }) => NinCheckState(
    hasNin: hasNin ?? this.hasNin,
    nin: nin ?? this.nin,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isDone: isDone ?? this.isDone,
    failure: failure,
  );

  @override
  List<Object?> get props => [hasNin, nin, isSubmitting, isDone, failure];

  /// Keeps the NIN out of logs and test output.
  @override
  String toString() => 'NinCheckState(hasNin: $hasNin, done: $isDone)';
}
