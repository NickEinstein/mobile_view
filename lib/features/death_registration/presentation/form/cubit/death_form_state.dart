part of 'death_form_cubit.dart';

enum FormStatus { loading, ready, failure }

enum SubmitStatus { idle, submitting, failed, submitted }

/// Whose NIN is being verified.
enum NinOwner { deceased, informant }

final class DeathFormState extends Equatable {
  const DeathFormState({
    this.status = FormStatus.loading,
    this.draft,
    this.referenceData,
    this.showErrors = false,
    this.failure,
    this.verifying = const {},
    this.ninFailures = const {},
    this.returnToReview = false,
    this.declared = false,
    this.submitStatus = SubmitStatus.idle,
    this.progress,
    this.trackingId,
    this.submitFailure,
    this.lgasUnavailable = const {},
  });

  final FormStatus status;
  final DeathDraft? draft;
  final DeathReferenceData? referenceData;

  /// States whose LGAs failed to load; their LGA fields offer a retry.
  final Set<String> lgasUnavailable;

  /// Errors appear after the user tries to continue, not while typing.
  final bool showErrors;

  /// Why the form couldn't load.
  final Failure? failure;

  /// NINs being checked now.
  final Set<NinOwner> verifying;

  /// Why the last check of a NIN failed (not found, offline…).
  final Map<NinOwner, Failure> ninFailures;

  /// The user came from the preview to edit a step; "Next" goes back there.
  final bool returnToReview;

  /// The preview's "I hereby certify…" box. Not saved: it must be ticked
  /// again after resuming.
  final bool declared;
  final SubmitStatus submitStatus;

  /// Share of the uploads done, 0–1; null while unknown.
  final double? progress;

  /// Set once submitted, if the server gave one.
  final String? trackingId;
  final Failure? submitFailure;

  DeathStep get step => draft?.step ?? DeathStep.deceased;

  /// Correcting a queried record rather than registering a new death.
  bool get isCorrection => draft?.queried != null;

  /// The names a verified (or still unverified) NIN fills in.
  bool isLocked(DeceasedField field) =>
      field.isFromNin && (draft?.deceased.hasNin ?? false);

  bool isInformantLocked(InformantField field) =>
      field.isFromNin && draft?.informant[InformantField.nin] != null;

  bool isComplete(DeathStep step, DateTime today) {
    final draft = this.draft;
    if (draft == null) return false;
    return switch (step) {
      DeathStep.deceased => draft.deceased.isComplete(today: today),
      DeathStep.informant => draft.informant.isComplete,
      DeathStep.documents => draft.documentsComplete,
      // The informant signs here.
      DeathStep.review =>
        draft.hasSignature &&
            DeathStep.values
                .where((s) => s != DeathStep.review)
                .every((s) => isComplete(s, today)),
    };
  }

  bool isStepComplete(DateTime today) => isComplete(step, today);

  bool canSubmit(DateTime today) =>
      declared && isComplete(DeathStep.review, today);

  DeathFormState copyWith({
    FormStatus? status,
    DeathDraft? draft,
    DeathReferenceData? referenceData,
    bool? showErrors,
    Failure? failure,
    Set<NinOwner>? verifying,
    Map<NinOwner, Failure>? ninFailures,
    bool? returnToReview,
    bool? declared,
    SubmitStatus? submitStatus,
    double? Function()? progress,
    String? Function()? trackingId,
    Failure? Function()? submitFailure,
    Set<String>? lgasUnavailable,
  }) => DeathFormState(
    status: status ?? this.status,
    draft: draft ?? this.draft,
    referenceData: referenceData ?? this.referenceData,
    showErrors: showErrors ?? this.showErrors,
    failure: failure ?? this.failure,
    verifying: verifying ?? this.verifying,
    ninFailures: ninFailures ?? this.ninFailures,
    returnToReview: returnToReview ?? this.returnToReview,
    declared: declared ?? this.declared,
    submitStatus: submitStatus ?? this.submitStatus,
    progress: progress != null ? progress() : this.progress,
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
    verifying,
    ninFailures,
    returnToReview,
    declared,
    submitStatus,
    progress,
    trackingId,
    submitFailure,
    lgasUnavailable,
  ];
}
