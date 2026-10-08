part of 'registration_form_cubit.dart';

enum FormStatus { loading, ready, failure }

enum SubmitStatus { idle, submitting, failed, submitted }

final class RegistrationFormState extends Equatable {
  const RegistrationFormState({
    this.status = FormStatus.loading,
    this.draft,
    this.referenceData,
    this.showErrors = false,
    this.failure,
    this.returnToReview = false,
    this.declared = false,
    this.submitStatus = SubmitStatus.idle,
    this.progress,
    this.trackingId,
    this.submitFailure,
    this.askForPayment = false,
    this.lgasUnavailable = const {},
  });

  final FormStatus status;
  final RegistrationDraft? draft;
  final ReferenceData? referenceData;

  /// Errors appear after the user tries to continue, not while typing.
  final bool showErrors;

  /// Why the form couldn't load.
  final Failure? failure;

  /// The user came from the review to edit a step; "Next" goes back there.
  final bool returnToReview;

  /// The review's "I hereby certify…" box. Not saved: it must be ticked
  /// again after resuming.
  final bool declared;
  final SubmitStatus submitStatus;

  /// Share of the upload sent, 0–1; null while unknown.
  final double? progress;

  /// Set once submitted, if the API gave one.
  final String? trackingId;
  final Failure? submitFailure;

  /// The child is 5 or older and the fee isn't paid: the page opens the
  /// payment screen, then calls `paymentClosed`.
  final bool askForPayment;

  /// States whose LGAs failed to load; their LGA fields offer a retry.
  final Set<String> lgasUnavailable;

  RegistrationStep get step => draft?.step ?? RegistrationStep.child;

  bool isComplete(RegistrationStep step, DateTime today) {
    final draft = this.draft;
    if (draft == null) return false;
    return switch (step) {
      RegistrationStep.child => draft.child.isComplete(today: today),
      RegistrationStep.mother => draft.mother.isComplete(ParentRole.mother),
      RegistrationStep.father => draft.father.isComplete(ParentRole.father),
      RegistrationStep.informant => draft.informant.isComplete(
        parentsGaveNin: draft.parentsGaveNin,
      ),
      RegistrationStep.documents => draft.documentsComplete,
      // Nothing to fill in; complete when everything before it is.
      RegistrationStep.review =>
        RegistrationStep.values
            .where((s) => s != RegistrationStep.review)
            .every((s) => isComplete(s, today)),
    };
  }

  bool isStepComplete(DateTime today) => isComplete(step, today);

  bool canSubmit(DateTime today) =>
      declared && isComplete(RegistrationStep.review, today);

  RegistrationFormState copyWith({
    FormStatus? status,
    RegistrationDraft? draft,
    ReferenceData? referenceData,
    bool? showErrors,
    Failure? failure,
    bool? returnToReview,
    bool? declared,
    SubmitStatus? submitStatus,
    double? Function()? progress,
    String? trackingId,
    Failure? Function()? submitFailure,
    bool? askForPayment,
    Set<String>? lgasUnavailable,
  }) => RegistrationFormState(
    status: status ?? this.status,
    draft: draft ?? this.draft,
    referenceData: referenceData ?? this.referenceData,
    showErrors: showErrors ?? this.showErrors,
    failure: failure ?? this.failure,
    returnToReview: returnToReview ?? this.returnToReview,
    declared: declared ?? this.declared,
    submitStatus: submitStatus ?? this.submitStatus,
    progress: progress != null ? progress() : this.progress,
    trackingId: trackingId ?? this.trackingId,
    submitFailure: submitFailure != null ? submitFailure() : this.submitFailure,
    askForPayment: askForPayment ?? this.askForPayment,
    lgasUnavailable: lgasUnavailable ?? this.lgasUnavailable,
  );

  @override
  List<Object?> get props => [
    status,
    draft,
    referenceData,
    showErrors,
    failure,
    returnToReview,
    declared,
    submitStatus,
    progress,
    trackingId,
    submitFailure,
    askForPayment,
    lgasUnavailable,
  ];
}
