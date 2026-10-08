part of 'adoption_form_cubit.dart';

enum SubmitStatus { idle, submitting, submitted }

enum FormStatus {
  loading,
  ready,

  /// Couldn't load (e.g. offline); offer to try again.
  failure,

  /// No registration on the device has passed the NIN step.
  notStarted,

  /// The fee hasn't been paid.
  notPaid,
}

final class AdoptionFormState extends Equatable {
  const AdoptionFormState({
    this.status = FormStatus.loading,
    this.draft,
    this.referenceData,
    this.showErrors = false,
    this.failure,
    this.isSaving = false,
    this.saveFailure,
    this.ninChecking,
    this.ninFailure,
    this.ninValidations = 0,
    this.informantNinChecking = false,
    this.informantNinFailure,
    this.returnToReview = false,
    this.declared = false,
    this.submitStatus = SubmitStatus.idle,
    this.trackingId,
    this.queryReason,
    this.lgasUnavailable = const {},
  });

  final FormStatus status;
  final AdoptionDraft? draft;
  final AdoptionReferenceData? referenceData;

  /// States whose LGAs failed to load; their LGA fields offer a retry.
  final Set<String> lgasUnavailable;

  /// Errors appear after the user tries to continue, not while typing.
  final bool showErrors;

  /// Why the form couldn't load.
  final Failure? failure;

  /// Saving the step's section on the server.
  final bool isSaving;

  /// Why the last section save failed.
  final Failure? saveFailure;

  /// Whose NIN is being validated.
  final Adopter? ninChecking;

  /// Whose NIN couldn't be validated, and why.
  final (Adopter, Failure)? ninFailure;

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

  /// Shown once submitted: the server's number, or the reference id.
  final String? trackingId;

  /// Why a queried application was queried.
  final String? queryReason;

  AdoptionStep get step => draft?.step ?? AdoptionStep.child;

  /// Whether this phase of the app has built [step].

  bool isComplete(AdoptionStep step, DateTime today) {
    final draft = this.draft;
    if (draft == null) return false;
    return switch (step) {
      AdoptionStep.child => draft.child.isComplete(today: today),
      AdoptionStep.adopter1 => draft.adopter1.isComplete(),
      AdoptionStep.adopter2 => draft.adopter2.isComplete(optional: true),
      AdoptionStep.adoptionDetails => draft.details.isComplete(today: today),
      AdoptionStep.informant => draft.informant.isComplete,
      AdoptionStep.documents => draft.documentsComplete,
      // Nothing to fill in; complete when everything before it is.
      AdoptionStep.review =>
        AdoptionStep.values
            .where((s) => s != AdoptionStep.review)
            .every((s) => isComplete(s, today)),
    };
  }

  bool canSubmit(DateTime today) =>
      declared && isComplete(AdoptionStep.review, today);

  bool isStepComplete(DateTime today) => isComplete(step, today);

  AdoptionFormState copyWith({
    FormStatus? status,
    AdoptionDraft? draft,
    AdoptionReferenceData? referenceData,
    bool? showErrors,
    Failure? failure,
    bool? isSaving,
    Failure? Function()? saveFailure,
    Adopter? Function()? ninChecking,
    (Adopter, Failure)? Function()? ninFailure,
    int? ninValidations,
    bool? informantNinChecking,
    Failure? Function()? informantNinFailure,
    bool? returnToReview,
    bool? declared,
    SubmitStatus? submitStatus,
    String? trackingId,
    String? queryReason,
    Set<String>? lgasUnavailable,
  }) => AdoptionFormState(
    status: status ?? this.status,
    draft: draft ?? this.draft,
    referenceData: referenceData ?? this.referenceData,
    showErrors: showErrors ?? this.showErrors,
    failure: failure ?? this.failure,
    isSaving: isSaving ?? this.isSaving,
    saveFailure: saveFailure != null ? saveFailure() : this.saveFailure,
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
    trackingId: trackingId ?? this.trackingId,
    queryReason: queryReason ?? this.queryReason,
    lgasUnavailable: lgasUnavailable ?? this.lgasUnavailable,
  );

  @override
  List<Object?> get props => [
    status,
    draft,
    referenceData,
    showErrors,
    failure,
    isSaving,
    saveFailure,
    ninChecking,
    ninFailure,
    ninValidations,
    informantNinChecking,
    informantNinFailure,
    returnToReview,
    declared,
    submitStatus,
    trackingId,
    queryReason,
    lgasUnavailable,
  ];
}
