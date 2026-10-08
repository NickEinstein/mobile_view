import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_draft.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_form.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_summary.dart';

/// One registered still birth, with everything recorded for it.
final class StillBirthRecord extends Equatable {
  const StillBirthRecord({
    required this.summary,
    required this.deceased,
    required this.mother,
    required this.informant,
  });

  final StillBirthSummary summary;
  final DeceasedParticulars deceased;
  final MotherParticulars mother;

  /// Its signature is the stored file's URL or key.
  final InformantParticulars informant;

  /// The answers in the form's shape, for the review cards.
  StillBirthDraft toDraft() => StillBirthDraft(
    startedOn: summary.registeredOn,
    deceased: deceased,
    mother: mother,
    informant: informant,
  );

  @override
  List<Object?> get props => [summary, deceased, mother, informant];
}
