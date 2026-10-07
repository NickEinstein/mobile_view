part of 'surrogacy_form_cubit.dart';

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

final class SurrogacyFormState extends Equatable {
  const SurrogacyFormState({
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
    this.returnToReview = false,
    this.declared = false,
    this.submitStatus = SubmitStatus.idle,
    this.trackingId,
    this.queryReason,
    this.lgasUnavailable = const {},
  });

  final FormStatus status;
  final SurrogacyDraft? draft;
  final SurrogacyReferenceData? referenceData;

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
  final SurrogacyPerson? ninChecking;

  /// Whose NIN couldn't be validated, and why.
  final (SurrogacyPerson, Failure)? ninFailure;

  /// Counts successful NIN validations, so each shows "NIN Validated".
  final int ninValidations;

  /// The user came from the review to edit a step; finishing it goes back.
  final bool returnToReview;

  /// The review's "I hereby certify…" box. Not saved: it must be ticked
  /// again after resuming.
  final bool declared;
  final SubmitStatus submitStatus;

  /// Shown once submitted: the server's number, or the reference id.
  final String? trackingId;

  /// When correcting a queried application: why it was queried.
  final String? queryReason;

  SurrogacyStep get step => draft?.step ?? SurrogacyStep.child;

  bool isComplete(SurrogacyStep step, DateTime today) {
    final draft = this.draft;
    if (draft == null) return false;
    return switch (step) {
      SurrogacyStep.child => draft.child.isComplete(today: today),
      SurrogacyStep.surrogacy => draft.surrogacy.isComplete(today: today),
      SurrogacyStep.legalMother => draft.legalMother.isComplete,
      SurrogacyStep.legalFather => switch (draft.hasLegalFather) {
        null => false,
        false => true,
        true => draft.legalFather.isComplete,
      },
      SurrogacyStep.surrogateMother => draft.surrogateMother.isComplete,
      SurrogacyStep.informant => draft.informant.isComplete,
      SurrogacyStep.documents => draft.documentsComplete,
      // Nothing to fill in; complete when everything before it is.
      SurrogacyStep.review =>
        SurrogacyStep.values
            .where((s) => s != SurrogacyStep.review)
            .every((s) => isComplete(s, today)),
    };
  }

  bool isStepComplete(DateTime today) => isComplete(step, today);

  bool canSubmit(DateTime today) =>
      declared && isComplete(SurrogacyStep.review, today);

  SurrogacyFormState copyWith({
    FormStatus? status,
    SurrogacyDraft? draft,
    SurrogacyReferenceData? referenceData,
    bool? showErrors,
    Failure? failure,
    bool? isSaving,
    Failure? Function()? saveFailure,
    SurrogacyPerson? Function()? ninChecking,
    (SurrogacyPerson, Failure)? Function()? ninFailure,
    int? ninValidations,
    bool? returnToReview,
    bool? declared,
    SubmitStatus? submitStatus,
    String? trackingId,
    String? queryReason,
    Set<String>? lgasUnavailable,
  }) => SurrogacyFormState(
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
    returnToReview,
    declared,
    submitStatus,
    trackingId,
    queryReason,
    lgasUnavailable,
  ];
}
