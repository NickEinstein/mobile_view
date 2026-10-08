part of 'foreign_birth_form_cubit.dart';

enum SubmitStatus { idle, submitting, submitted }

enum FormStatus {
  loading,
  ready,

  /// Couldn't load (e.g. offline); offer to try again.
  failure,

  /// The fee hasn't been paid.
  notPaid,
}

final class ForeignBirthFormState extends Equatable {
  const ForeignBirthFormState({
    this.status = FormStatus.loading,
    this.draft,
    this.referenceData,
    this.states = const {},
    this.lgas = const {},
    this.placesFailure,
    this.showErrors = false,
    this.failure,
    this.ninChecking,
    this.ninFailure,
    this.ninValidations = 0,
    this.informantNinChecking = false,
    this.informantNinFailure,
    this.returnToReview = false,
    this.declared = false,
    this.submitStatus = SubmitStatus.idle,
    this.submitFailure,
    this.trackingId,
    this.record,
  });

  final FormStatus status;
  final ForeignBirthDraft? draft;
  final ForeignBirthReferenceData? referenceData;

  /// States (cities, provinces) loaded so far, by country id.
  final Map<String, List<Option>> states;

  /// LGAs loaded so far, by Nigerian state id.
  final Map<String, List<Option>> lgas;

  /// Why some places couldn't be loaded.
  final Failure? placesFailure;

  /// Errors appear after the user tries to continue, not while typing.
  final bool showErrors;

  /// Why the form couldn't load.
  final Failure? failure;

  /// Whose NIN is being validated.
  final Parent? ninChecking;

  /// Whose NIN couldn't be validated, and why.
  final (Parent, Failure)? ninFailure;

  /// Counts successful NIN validations, so each shows "NIN Validated".
  final int ninValidations;

  /// The informant's NIN is being validated.
  final bool informantNinChecking;

  /// Why the informant's NIN couldn't be validated.
  final Failure? informantNinFailure;

  /// Opened from the review's Edit: finishing the step goes back there.
  final bool returnToReview;

  /// The review's declaration is ticked.
  final bool declared;
  final SubmitStatus submitStatus;

  /// Why the last submit failed.
  final Failure? submitFailure;

  /// Shown once submitted: the notification number, or the payment
  /// reference.
  final String? trackingId;

  /// The queried notification being corrected.
  final ForeignBirthRecord? record;

  /// A viewable URL for a file on record (by its storage key).
  String? fileUrl(String? key) => record?.fileUrls[key];

  ForeignBirthStep get step => draft?.step ?? ForeignBirthStep.child;

  List<Option> statesOf(String? countryId) =>
      states[countryId] ?? const <Option>[];

  List<Option> lgasOf(String? stateId) => lgas[stateId] ?? const <Option>[];

  bool isComplete(ForeignBirthStep step, DateTime today) {
    final draft = this.draft;
    if (draft == null) return false;
    return switch (step) {
      ForeignBirthStep.child => draft.child.isComplete(today: today),
      ForeignBirthStep.mother => draft.mother.isComplete(Parent.mother),
      ForeignBirthStep.father =>
        draft.father.isComplete(Parent.father) && draft.hasNigerianParent,
      ForeignBirthStep.informant => draft.informant.isComplete,
      ForeignBirthStep.documents => draft.certificate != null,
      // Nothing to fill in; complete when everything before it is.
      ForeignBirthStep.review =>
        ForeignBirthStep.values
            .where((s) => s != ForeignBirthStep.review)
            .every((s) => isComplete(s, today)),
    };
  }

  bool canSubmit(DateTime today) =>
      declared && isComplete(ForeignBirthStep.review, today);

  bool isStepComplete(DateTime today) => isComplete(step, today);

  ForeignBirthFormState copyWith({
    FormStatus? status,
    ForeignBirthDraft? draft,
    ForeignBirthReferenceData? referenceData,
    Map<String, List<Option>>? states,
    Map<String, List<Option>>? lgas,
    Failure? Function()? placesFailure,
    bool? showErrors,
    Failure? failure,
    Parent? Function()? ninChecking,
    (Parent, Failure)? Function()? ninFailure,
    int? ninValidations,
    bool? informantNinChecking,
    Failure? Function()? informantNinFailure,
    bool? returnToReview,
    bool? declared,
    SubmitStatus? submitStatus,
    Failure? Function()? submitFailure,
    String? trackingId,
    ForeignBirthRecord? record,
  }) => ForeignBirthFormState(
    status: status ?? this.status,
    draft: draft ?? this.draft,
    referenceData: referenceData ?? this.referenceData,
    states: states ?? this.states,
    lgas: lgas ?? this.lgas,
    placesFailure: placesFailure != null ? placesFailure() : this.placesFailure,
    showErrors: showErrors ?? this.showErrors,
    failure: failure ?? this.failure,
    ninChecking: ninChecking != null ? ninChecking() : this.ninChecking,
    ninFailure: ninFailure != null ? ninFailure() : this.ninFailure,
    ninValidations: ninValidations ?? this.ninValidations,
    informantNinChecking: informantNinChecking ?? this.informantNinChecking,
    informantNinFailure: informantNinFailure != null
        ? informantNinFailure()
        : this.informantNinFailure,
    returnToReview: returnToReview ?? this.returnToReview,
    declared: declared ?? this.declared,
    submitStatus: submitStatus ?? this.submitStatus,
    submitFailure: submitFailure != null ? submitFailure() : this.submitFailure,
    trackingId: trackingId ?? this.trackingId,
    record: record ?? this.record,
  );

  @override
  List<Object?> get props => [
    status,
    draft,
    referenceData,
    states,
    lgas,
    placesFailure,
    showErrors,
    failure,
    ninChecking,
    ninFailure,
    ninValidations,
    informantNinChecking,
    informantNinFailure,
    returnToReview,
    declared,
    submitStatus,
    submitFailure,
    trackingId,
    record,
  ];
}
