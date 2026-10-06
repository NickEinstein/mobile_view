part of 'attestation_reissuance_form_cubit.dart';

enum FormStatus {
  loading,
  ready,

  /// The options didn't load.
  failure,

  /// No request with a certificate was started (e.g. a deep link).
  missing,
}

enum SubmitStatus { idle, submitting, failed, submitted }

final class AttestationReissuanceFormState extends Equatable {
  const AttestationReissuanceFormState({
    this.status = FormStatus.loading,
    this.draft,
    this.record,
    this.options,
    this.nigeria = const [],
    this.lgasByState = const {},
    this.showErrors = false,
    this.failure,
    this.returnToReview = false,
    this.declared = false,
    this.submitStatus = SubmitStatus.idle,
    this.submitMessage,
    this.submitFailure,
  });

  final FormStatus status;

  /// The request, with its attestation form.
  final ReissuanceDraft? draft;

  /// Instead of [draft]: the queried request being corrected.
  final AttestationReissuanceRecord? record;
  final ReissuanceOptions? options;

  /// Nigeria's states: every state the form asks for is one.
  final List<Option> nigeria;

  /// Loaded as needed, by state id.
  final Map<String, List<Option>> lgasByState;

  /// Errors appear after the user tries to continue, not while typing.
  final bool showErrors;
  final Failure? failure;

  /// The user came from the preview to edit a step; "Next" goes back there.
  final bool returnToReview;

  /// The preview's declaration.
  final bool declared;
  final SubmitStatus submitStatus;
  final String? submitMessage;
  final Failure? submitFailure;

  AttestationReissuanceForm? get form => record?.form ?? draft?.attestationForm;

  bool get isQueried => record != null;

  DateTime get startedOn =>
      draft?.startedOn ?? record?.createdOn ?? DateTime.now();

  AttestationReissuanceStep get step =>
      form?.step ?? AttestationReissuanceStep.applicant;

  /// The certificate being replaced and whose it is.
  CertificateFacts? get certificate {
    final record = this.record;
    if (record != null) {
      return (
        kind: ReissuanceKind.attestation,
        number: record.certificateNumber,
        issuedOn: record.issuedOn,
        nin: record.nin,
      );
    }
    final certificate = draft?.certificate;
    if (certificate == null) return null;
    return (
      kind: certificate.kind,
      number: certificate.number,
      issuedOn: certificate.issuedOn,
      nin: draft!.ninRecord.nin,
    );
  }

  /// The sex comes from the NIN (or the queried request) and is locked.
  bool get sexLocked => isQueried || draft?.ninRecord.sex != null;

  bool isStepComplete(DateTime today) =>
      form?.isComplete(step, today: today) ?? false;

  bool canSubmit(DateTime today) =>
      declared &&
      (form?.isComplete(AttestationReissuanceStep.review, today: today) ??
          false);

  List<Option> lgasOf(String? stateId) => lgasByState[stateId] ?? const [];

  AttestationReissuanceFormState copyWith({
    FormStatus? status,
    ReissuanceDraft? draft,
    AttestationReissuanceRecord? record,
    ReissuanceOptions? options,
    List<Option>? nigeria,
    Map<String, List<Option>>? lgasByState,
    bool? showErrors,
    Failure? failure,
    bool? returnToReview,
    bool? declared,
    SubmitStatus? submitStatus,
    String? Function()? submitMessage,
    Failure? Function()? submitFailure,
  }) => AttestationReissuanceFormState(
    status: status ?? this.status,
    draft: draft ?? this.draft,
    record: record ?? this.record,
    options: options ?? this.options,
    nigeria: nigeria ?? this.nigeria,
    lgasByState: lgasByState ?? this.lgasByState,
    showErrors: showErrors ?? this.showErrors,
    failure: failure ?? this.failure,
    returnToReview: returnToReview ?? this.returnToReview,
    declared: declared ?? this.declared,
    submitStatus: submitStatus ?? this.submitStatus,
    submitMessage: submitMessage != null ? submitMessage() : this.submitMessage,
    submitFailure: submitFailure != null ? submitFailure() : this.submitFailure,
  );

  @override
  List<Object?> get props => [
    status,
    draft,
    record,
    options,
    nigeria,
    lgasByState,
    showErrors,
    failure,
    returnToReview,
    declared,
    submitStatus,
    submitMessage,
    submitFailure,
  ];

  /// Keeps personal data out of logs and test output.
  @override
  String toString() =>
      'AttestationReissuanceFormState(status: ${status.name}, '
      'step: ${step.name}, submit: ${submitStatus.name})';
}
