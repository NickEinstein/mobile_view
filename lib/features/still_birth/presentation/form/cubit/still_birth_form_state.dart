part of 'still_birth_form_cubit.dart';

enum FormStatus { loading, ready, failure }

enum SubmitStatus { idle, submitting, failed, submitted }

final class StillBirthFormState extends Equatable {
  const StillBirthFormState({
    this.status = FormStatus.loading,
    this.draft,
    this.referenceData,
    this.showErrors = false,
    this.failure,
    this.returnToReview = false,
    this.declared = false,
    this.submitStatus = SubmitStatus.idle,
    this.trackingId,
    this.submitFailure,
    this.lgasUnavailable = const {},
  });

  final FormStatus status;
  final StillBirthDraft? draft;
  final StillBirthReferenceData? referenceData;

  /// States whose LGAs failed to load; their LGA fields offer a retry.
  final Set<String> lgasUnavailable;

  /// Errors appear after the user tries to continue, not while typing.
  final bool showErrors;

  /// Why the form couldn't load.
  final Failure? failure;

  /// The user came from the preview to edit a step; "Next" goes back there.
  final bool returnToReview;

  /// The preview's "I hereby certify…" box. Not saved: it must be ticked
  /// again after resuming.
  final bool declared;
  final SubmitStatus submitStatus;

  /// Set once submitted, if the server gave one.
  final String? trackingId;
  final Failure? submitFailure;

  StillBirthStep get step => draft?.step ?? StillBirthStep.deceased;

  bool isComplete(StillBirthStep step, DateTime today) {
    final draft = this.draft;
    if (draft == null) return false;
    return switch (step) {
      StillBirthStep.deceased => draft.deceased.isComplete(today: today),
      StillBirthStep.mother => draft.mother.isComplete,
      StillBirthStep.informant => draft.informant.isComplete,
      // Nothing to fill in; complete when everything before it is.
      StillBirthStep.review =>
        StillBirthStep.values
            .where((s) => s != StillBirthStep.review)
            .every((s) => isComplete(s, today)),
    };
  }

  bool isStepComplete(DateTime today) => isComplete(step, today);

  bool canSubmit(DateTime today) =>
      declared && isComplete(StillBirthStep.review, today);

  StillBirthFormState copyWith({
    FormStatus? status,
    StillBirthDraft? draft,
    StillBirthReferenceData? referenceData,
    bool? showErrors,
    Failure? failure,
    bool? returnToReview,
    bool? declared,
    SubmitStatus? submitStatus,
    String? Function()? trackingId,
    Failure? Function()? submitFailure,
    Set<String>? lgasUnavailable,
  }) => StillBirthFormState(
    status: status ?? this.status,
    draft: draft ?? this.draft,
    referenceData: referenceData ?? this.referenceData,
    showErrors: showErrors ?? this.showErrors,
    failure: failure ?? this.failure,
    returnToReview: returnToReview ?? this.returnToReview,
    declared: declared ?? this.declared,
    submitStatus: submitStatus ?? this.submitStatus,
    trackingId: trackingId != null ? trackingId() : this.trackingId,
    submitFailure: submitFailure != null ? submitFailure() : this.submitFailure,
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
    trackingId,
    submitFailure,
    lgasUnavailable,
  ];
}
