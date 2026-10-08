import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_form.dart';

/// A still birth registration in progress on this device.
/// The states whose LGAs a still birth's dropdowns and labels need.
Set<String> stillBirthStates({
  required MotherParticulars mother,
  required InformantParticulars informant,
}) => {?mother[MotherField.state], ?informant[InformantField.state]};

final class StillBirthDraft extends Equatable {
  const StillBirthDraft({
    required this.startedOn,
    this.step = StillBirthStep.deceased,
    this.deceased = const DeceasedParticulars(),
    this.mother = const MotherParticulars(),
    this.informant = const InformantParticulars(),
    this.submissionKey,
  });

  factory StillBirthDraft.fromJson(Map<String, Object?> json) {
    final step = json['step'];
    return StillBirthDraft(
      startedOn: DateTime.parse(json['startedOn']! as String),
      step: step is String
          ? StillBirthStep.values.asNameMap()[step] ?? StillBirthStep.deceased
          : StillBirthStep.deceased,
      deceased: DeceasedParticulars.fromJson(json['deceased']),
      mother: MotherParticulars.fromJson(json['mother']),
      informant: InformantParticulars.fromJson(json['informant']),
      submissionKey: json['submissionKey'] as String?,
    );
  }

  final DateTime startedOn;
  final StillBirthStep step;
  final DeceasedParticulars deceased;
  final MotherParticulars mother;
  final InformantParticulars informant;

  /// Sent with the submission so the server can ignore a repeat. Set on
  /// the first attempt.
  final String? submissionKey;

  /// Something worth resuming has been entered.
  bool get hasAnswers =>
      deceased.values.values.isNotEmpty ||
      mother.values.values.isNotEmpty ||
      informant.values.values.isNotEmpty;

  /// Every file the draft points to.
  Iterable<String> get files => [?informant[InformantField.signature]];

  Set<String> get chosenStates =>
      stillBirthStates(mother: mother, informant: informant);

  StillBirthDraft copyWith({
    StillBirthStep? step,
    DeceasedParticulars? deceased,
    MotherParticulars? mother,
    InformantParticulars? informant,
    String? submissionKey,
  }) => StillBirthDraft(
    startedOn: startedOn,
    step: step ?? this.step,
    deceased: deceased ?? this.deceased,
    mother: mother ?? this.mother,
    informant: informant ?? this.informant,
    submissionKey: submissionKey ?? this.submissionKey,
  );

  Map<String, Object?> toJson() => {
    'startedOn': startedOn.toIso8601String(),
    'step': step.name,
    'deceased': deceased.values.toJson(),
    'mother': mother.values.toJson(),
    'informant': informant.values.toJson(),
    'submissionKey': submissionKey,
  };

  @override
  List<Object?> get props => [
    startedOn,
    step,
    deceased,
    mother,
    informant,
    submissionKey,
  ];

  /// Contains personal data: keep it out of logs.
  @override
  String toString() => 'StillBirthDraft(step: ${step.name})';
}
