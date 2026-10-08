part of 'child_nin_cubit.dart';

enum ChildNinStep {
  /// Creating the application, or reading the one on the device.
  starting,

  /// The application couldn't be created; offer to try again.
  startFailed,
  ready,
  validating,
  skipping,

  /// Recorded; the page moves on to payment.
  done,
}

final class ChildNinState extends Equatable {
  const ChildNinState({
    this.step = ChildNinStep.starting,
    this.referenceId,
    this.justCreated = false,
    this.nin = '',
    this.decision,
    this.failure,
  });

  final ChildNinStep step;
  final String? referenceId;

  /// The application was just created: show its reference id.
  final bool justCreated;
  final String nin;

  /// Set once [step] is done.
  final ChildNinDecision? decision;
  final Failure? failure;

  bool get ninLooksValid => ChildNinCubit._ninPattern.hasMatch(nin);

  bool get canValidate => step == ChildNinStep.ready && ninLooksValid;

  bool get isBusy =>
      step == ChildNinStep.validating || step == ChildNinStep.skipping;

  /// [failure] is cleared unless passed, so editing dismisses the error.
  ChildNinState copyWith({
    ChildNinStep? step,
    String? referenceId,
    bool? justCreated,
    String? nin,
    ChildNinDecision? decision,
    Failure? failure,
  }) => ChildNinState(
    step: step ?? this.step,
    referenceId: referenceId ?? this.referenceId,
    justCreated: justCreated ?? this.justCreated,
    nin: nin ?? this.nin,
    decision: decision ?? this.decision,
    failure: failure,
  );

  @override
  List<Object?> get props => [
    step,
    referenceId,
    justCreated,
    nin,
    decision,
    failure,
  ];

  /// Keeps the NIN out of logs and test output.
  @override
  String toString() => 'ChildNinState(step: ${step.name})';
}
