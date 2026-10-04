part of 'modification_form_cubit.dart';

enum ModificationFormStep { form, documents }

final class ModificationFormState extends Equatable {
  const ModificationFormState({
    required this.edit,
    this.step = ModificationFormStep.form,
    this.declared = false,
    this.showErrors = false,
    this.documents = const ModificationDocuments(),
    this.states = const [],
    this.lgasByState = const {},
    this.optionsLoading = false,
    this.optionsFailure,
    this.isSubmitting = false,
    this.failure,
    this.paymentMissing = false,
    this.submitted = false,
    this.message,
  });

  final RecordEdit edit;

  final ModificationFormStep step;

  /// "I hereby certify…".
  final bool declared;

  /// After a tap on Modify or Submit with something missing.
  final bool showErrors;
  final ModificationDocuments documents;
  final List<Option> states;

  /// The LGAs of each state chosen (of birth, of origin).
  final Map<String, List<Option>> lgasByState;
  final bool optionsLoading;
  final Failure? optionsFailure;
  final bool isSubmitting;
  final Failure? failure;

  /// No paid fee was found for this request.
  final bool paymentMissing;
  final bool submitted;

  /// The server's confirmation.
  final String? message;

  /// The LGAs of the state [lgaField] belongs to.
  List<Option> lgasFor(RecordField lgaField) =>
      lgasByState[edit[lgaField.stateField!]] ?? const [];

  /// [optionsFailure], [failure] and [paymentMissing] are cleared unless
  /// passed, so each attempt starts clean.
  ModificationFormState copyWith({
    RecordEdit? edit,
    ModificationFormStep? step,
    bool? declared,
    bool? showErrors,
    ModificationDocuments? documents,
    List<Option>? states,
    Map<String, List<Option>>? lgasByState,
    bool? optionsLoading,
    Failure? optionsFailure,
    bool? isSubmitting,
    Failure? failure,
    bool paymentMissing = false,
    bool? submitted,
    String? message,
  }) => ModificationFormState(
    edit: edit ?? this.edit,
    step: step ?? this.step,
    declared: declared ?? this.declared,
    showErrors: showErrors ?? this.showErrors,
    documents: documents ?? this.documents,
    states: states ?? this.states,
    lgasByState: lgasByState ?? this.lgasByState,
    optionsLoading: optionsLoading ?? this.optionsLoading,
    optionsFailure: optionsFailure,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    failure: failure,
    paymentMissing: paymentMissing,
    submitted: submitted ?? this.submitted,
    message: message ?? this.message,
  );

  @override
  List<Object?> get props => [
    edit,
    step,
    declared,
    showErrors,
    documents,
    states,
    lgasByState,
    optionsLoading,
    optionsFailure,
    isSubmitting,
    failure,
    paymentMissing,
    submitted,
    message,
  ];
}
