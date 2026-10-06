part of 'birth_reissuance_form_cubit.dart';

enum FormStatus {
  loading,
  ready,

  /// The options didn't load.
  failure,

  /// No request with a certificate was started (e.g. a deep link).
  missing,
}

enum SubmitStatus { idle, submitting, failed, submitted }

final class BirthReissuanceFormState extends Equatable {
  const BirthReissuanceFormState({
    this.status = FormStatus.loading,
    this.draft,
    this.record,
    this.options,
    this.statesByCountry = const {},
    this.lgasByState = const {},
    this.showErrors = false,
    this.failure,
    this.returnToReview = false,
    this.submitStatus = SubmitStatus.idle,
    this.submitMessage,
    this.submitFailure,
  });

  final FormStatus status;

  /// The request, with its birth form.
  final ReissuanceDraft? draft;

  /// Instead of [draft]: the queried request being corrected.
  final BirthReissuanceRecord? record;
  final ReissuanceOptions? options;

  /// Loaded as needed, by country code.
  final Map<String, List<Option>> statesByCountry;

  /// Loaded as needed, by state id.
  final Map<String, List<Option>> lgasByState;

  /// Errors appear after the user tries to continue, not while typing.
  final bool showErrors;
  final Failure? failure;

  /// The user came from the preview to edit a step; "Next" goes back there.
  final bool returnToReview;

  final SubmitStatus submitStatus;

  /// The server's confirmation, once submitted.
  final String? submitMessage;
  final Failure? submitFailure;

  BirthReissuanceForm? get form => record?.form ?? draft?.birthForm;

  bool get isQueried => record != null;

  DateTime get startedOn =>
      draft?.startedOn ?? record?.createdOn ?? DateTime.now();

  /// The certificate being replaced and whose it is.
  CertificateFacts? get certificate {
    final record = this.record;
    if (record != null) {
      return (
        kind: ReissuanceKind.birth,
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

  /// The sex comes from the NIN and can't be changed (also on a queried
  /// request).
  bool get sexLocked => isQueried || draft?.ninRecord.sex != null;

  BirthReissuanceStep get step => form?.step ?? BirthReissuanceStep.child;

  bool get isStepComplete => form?.isComplete(step) ?? false;

  /// Everything is filled in; the recipient's email is confirmed apart.
  bool get canSubmit => form?.isComplete(BirthReissuanceStep.review) ?? false;

  List<Option> statesOf(String? countryCode) =>
      statesByCountry[countryCode] ?? const [];

  List<Option> lgasOf(String? stateId) => lgasByState[stateId] ?? const [];

  BirthReissuanceFormState copyWith({
    FormStatus? status,
    ReissuanceDraft? draft,
    BirthReissuanceRecord? record,
    ReissuanceOptions? options,
    Map<String, List<Option>>? statesByCountry,
    Map<String, List<Option>>? lgasByState,
    bool? showErrors,
    Failure? failure,
    bool? returnToReview,
    SubmitStatus? submitStatus,
    String? Function()? submitMessage,
    Failure? Function()? submitFailure,
  }) => BirthReissuanceFormState(
    status: status ?? this.status,
    draft: draft ?? this.draft,
    record: record ?? this.record,
    options: options ?? this.options,
    statesByCountry: statesByCountry ?? this.statesByCountry,
    lgasByState: lgasByState ?? this.lgasByState,
    showErrors: showErrors ?? this.showErrors,
    failure: failure ?? this.failure,
    returnToReview: returnToReview ?? this.returnToReview,
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
    statesByCountry,
    lgasByState,
    showErrors,
    failure,
    returnToReview,
    submitStatus,
    submitMessage,
    submitFailure,
  ];

  /// Keeps personal data out of logs and test output.
  @override
  String toString() =>
      'BirthReissuanceFormState(status: ${status.name}, step: ${step.name}, '
      'submit: ${submitStatus.name})';
}
