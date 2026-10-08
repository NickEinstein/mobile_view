part of 'payment_cubit.dart';

/// The two tabs: pay now, or use a reference paid earlier.
enum PaymentMode { makePayment, enterReference }

enum PaymentStep {
  loading,

  /// The fee couldn't be loaded; offer to try again.
  loadFailed,
  ready,
  sendingOtp,

  /// The code dialog is open.
  otp,
  confirmingOtp,

  /// Setting up the payment with the gateway.
  starting,

  /// The checkout is open.
  checkout,

  /// Asking our backend whether it was paid.
  verifying,
  paid,
}

/// Why the user is still on the payment screen.
enum PaymentNotice { notReceived, failed, emailCannotReceive }

final class PaymentState extends Equatable {
  const PaymentState({
    this.step = PaymentStep.loading,
    this.mode = PaymentMode.makePayment,
    this.email = const Email.pure(),
    this.reference = '',
    this.otp = '',
    this.resendCooldown = 0,
    this.quote,
    this.payment,
    this.notice,
    this.failure,
  });

  final PaymentStep step;
  final PaymentMode mode;
  final Email email;

  /// Typed under "Enter Reference".
  final String reference;
  final String otp;

  /// Seconds until the code can be resent.
  final int resendCooldown;
  final PaymentQuote? quote;

  /// The payment set up so far, if any.
  final StoredPayment? payment;
  final PaymentNotice? notice;
  final Failure? failure;

  bool get otpComplete => PaymentCubit._otpPattern.hasMatch(otp);

  /// A payment is already set up, so Pay needs no email or code.
  bool get hasPendingPayment => payment?.session != null && !payment!.isPaid;

  bool get canPay =>
      step == PaymentStep.ready && (hasPendingPayment || email.isValid);

  bool get canVerifyReference =>
      step == PaymentStep.ready && reference.isNotEmpty;

  bool get isBusy => switch (step) {
    PaymentStep.sendingOtp ||
    PaymentStep.starting ||
    PaymentStep.checkout ||
    PaymentStep.verifying => true,
    _ => false,
  };

  /// [notice] and [failure] are cleared unless passed (or kept), so each
  /// attempt starts clean.
  PaymentState copyWith({
    PaymentStep? step,
    PaymentMode? mode,
    Email? email,
    String? reference,
    String? otp,
    int? resendCooldown,
    PaymentQuote? quote,
    StoredPayment? payment,
    PaymentNotice? notice,
    Failure? failure,
    bool keepNotice = false,
    bool keepFailure = false,
  }) => PaymentState(
    step: step ?? this.step,
    mode: mode ?? this.mode,
    email: email ?? this.email,
    reference: reference ?? this.reference,
    otp: otp ?? this.otp,
    resendCooldown: resendCooldown ?? this.resendCooldown,
    quote: quote ?? this.quote,
    payment: payment ?? this.payment,
    notice: notice ?? (keepNotice ? this.notice : null),
    failure: failure ?? (keepFailure ? this.failure : null),
  );

  @override
  List<Object?> get props => [
    step,
    mode,
    email,
    reference,
    otp,
    resendCooldown,
    quote,
    payment,
    notice,
    failure,
  ];

  /// Keeps the email out of logs and test output.
  @override
  String toString() => 'PaymentState(step: ${step.name}, mode: ${mode.name})';
}
