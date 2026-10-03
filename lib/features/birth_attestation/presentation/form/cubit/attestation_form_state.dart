part of 'attestation_form_cubit.dart';

enum FormStatus {
  loading,
  ready,
  failure,

  /// No confirmed payment on this device.
  missingPayment,

  /// Face validation (and the NIN question) not done yet.
  missingIdentity,
}

enum SubmitStatus { idle, submitting, failed, submitted }

final class AttestationFormState extends Equatable {
  const AttestationFormState({
    this.status = FormStatus.loading,
    this.draft,
    this.referenceData,
    this.paymentReference,
    this.showErrors = false,
    this.failure,
    this.returnToReview = false,
    this.declared = false,
    this.submitStatus = SubmitStatus.idle,
    this.progress,
    this.trackingId,
    this.submitFailure,
    this.queryReason,
    this.lgasUnavailable = const {},
  });

  final FormStatus status;
  final AttestationDraft? draft;
  final AttestationReferenceData? referenceData;

  /// The confirmed payment this application uses.
  final String? paymentReference;

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

  /// Set once submitted.
  final String? trackingId;
  final Failure? submitFailure;

  /// States whose LGAs failed to load; their LGA fields offer a retry.
  final Set<String> lgasUnavailable;

  /// Why the record being corrected was queried.
  final String? queryReason;

  bool get isCorrection => draft?.queried != null;

  AttestationStep get step => draft?.step ?? AttestationStep.applicant;

  ApplicantNinRecord? get ninRecord => draft?.ninRecord;

  /// Names and sex taken from the NIN record can't be changed.
  bool isLocked(ApplicantField field) {
    final record = ninRecord;
    if (record == null) return false;
    return switch (field) {
      ApplicantField.surname || ApplicantField.firstName => true,
      ApplicantField.middleName => record.middleName != null,
      ApplicantField.sex => record.sex != null,
      _ => false,
    };
  }

  /// A passport is needed and missing.
  bool passportMissing(Parent parent) {
    final draft = this.draft;
    if (draft == null) return false;
    return draft.parent(parent).needsPassport &&
        !draft.hasDocument(parent.passport);
  }

  bool isComplete(AttestationStep step, DateTime today) {
    final draft = this.draft;
    if (draft == null) return false;
    return switch (step) {
      AttestationStep.applicant =>
        draft.hasFace &&
            draft.applicant.isComplete(today: today, nin: draft.ninRecord),
      AttestationStep.additional =>
        draft.additional.isComplete(correction: draft.queried != null) &&
            draft.hasDocument(AttestationDocument.affidavit),
      AttestationStep.parents => Parent.values.every(
        (parent) =>
            draft.parent(parent).isComplete(parent) && !passportMissing(parent),
      ),
      // Nothing to fill in; complete when everything before it is.
      AttestationStep.review =>
        AttestationStep.values
            .where((s) => s != AttestationStep.review)
            .every((s) => isComplete(s, today)),
    };
  }

  bool isStepComplete(DateTime today) => isComplete(step, today);

  bool canSubmit(DateTime today) =>
      declared && isComplete(AttestationStep.review, today);

  AttestationFormState copyWith({
    FormStatus? status,
    AttestationDraft? draft,
    AttestationReferenceData? referenceData,
    String? paymentReference,
    bool? showErrors,
    Failure? failure,
    bool? returnToReview,
    bool? declared,
    SubmitStatus? submitStatus,
    double? Function()? progress,
    String? trackingId,
    Failure? Function()? submitFailure,
    String? queryReason,
    Set<String>? lgasUnavailable,
  }) => AttestationFormState(
    status: status ?? this.status,
    draft: draft ?? this.draft,
    referenceData: referenceData ?? this.referenceData,
    paymentReference: paymentReference ?? this.paymentReference,
    showErrors: showErrors ?? this.showErrors,
    failure: failure ?? this.failure,
    returnToReview: returnToReview ?? this.returnToReview,
    declared: declared ?? this.declared,
    submitStatus: submitStatus ?? this.submitStatus,
    progress: progress != null ? progress() : this.progress,
    trackingId: trackingId ?? this.trackingId,
    submitFailure: submitFailure != null ? submitFailure() : this.submitFailure,
    queryReason: queryReason ?? this.queryReason,
    lgasUnavailable: lgasUnavailable ?? this.lgasUnavailable,
  );

  @override
  List<Object?> get props => [
    status,
    draft,
    referenceData,
    paymentReference,
    showErrors,
    failure,
    returnToReview,
    declared,
    submitStatus,
    progress,
    trackingId,
    submitFailure,
    queryReason,
    lgasUnavailable,
  ];
}
