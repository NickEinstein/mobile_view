import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/auth/domain/value_objects/credentials.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

part 'payment_state.dart';

/// "Payment": Make Payment (email → code → checkout) or Enter Reference.
/// The reference is kept as soon as it exists, so no one pays twice.
class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit(this._repository, {this.resendCooldownSeconds = 60})
    : super(const PaymentState());

  /// The codes are six digits.
  static const otpLength = 6;
  static final _otpPattern = RegExp('^\\d{$otpLength}\$');

  final PaymentSource _repository;
  final int resendCooldownSeconds;
  Timer? _cooldownTimer;

  Future<void> load() async {
    emit(state.copyWith(step: PaymentStep.loading));
    final stored = await _repository.storedPayment();
    final result = await _repository.quote();
    if (isClosed) return;
    final quote = switch (result) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (stored != null && stored.isPaid) {
      emit(state.copyWith(step: PaymentStep.paid, payment: stored));
      return;
    }
    if (quote == null) {
      emit(
        state.copyWith(
          step: PaymentStep.loadFailed,
          failure: (result as Err<PaymentQuote>).failure,
        ),
      );
      return;
    }
    emit(state.copyWith(quote: quote));
    if (stored != null) {
      // Possibly paid before the app closed: ask first.
      await _verify(stored, afterAttempt: false);
    } else {
      emit(state.copyWith(step: PaymentStep.ready));
    }
  }

  void modeChanged(PaymentMode mode) => emit(state.copyWith(mode: mode));

  void emailChanged(String value) =>
      emit(state.copyWith(email: Email.dirty(value.trim())));

  void referenceChanged(String value) =>
      emit(state.copyWith(reference: value.trim().toUpperCase()));

  /// "Pay": straight to the checkout for a payment already set up;
  /// otherwise the email's one-time code first.
  Future<void> pay() async {
    if (state.step != PaymentStep.ready) return;
    final payment = state.payment;
    if (payment?.session != null) {
      emit(state.copyWith(step: PaymentStep.checkout));
      return;
    }
    if (state.email.isNotValid) return;

    emit(state.copyWith(step: PaymentStep.sendingOtp));
    final result = await _repository.sendPaymentOtp(state.email.value);
    if (isClosed) return;
    switch (result) {
      case Ok(value: true):
        emit(state.copyWith(step: PaymentStep.otp, otp: ''));
        _startCooldown();
      case Ok(value: false):
        emit(
          state.copyWith(
            step: PaymentStep.ready,
            notice: PaymentNotice.emailCannotReceive,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(step: PaymentStep.ready, failure: failure));
    }
  }

  void otpChanged(String code) => emit(state.copyWith(otp: code));

  Future<void> resendOtp() async {
    if (state.step != PaymentStep.otp || state.resendCooldown > 0) return;
    final result = await _repository.resendPaymentOtp(state.email.value);
    if (isClosed) return;
    switch (result) {
      case Ok():
        _startCooldown();
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  /// Closed the code dialog without confirming.
  void cancelOtp() {
    if (state.step != PaymentStep.otp) return;
    _cooldownTimer?.cancel();
    emit(state.copyWith(step: PaymentStep.ready, resendCooldown: 0));
  }

  /// "Authorize": confirms the code, then sets up the payment.
  Future<void> confirmOtp() async {
    if (state.step != PaymentStep.otp || !state.otpComplete) return;
    emit(state.copyWith(step: PaymentStep.confirmingOtp));
    final confirmed = await _repository.confirmPaymentOtp(
      email: state.email.value,
      code: state.otp,
    );
    if (isClosed) return;
    if (confirmed case Err(:final failure)) {
      emit(state.copyWith(step: PaymentStep.otp, failure: failure));
      return;
    }

    _cooldownTimer?.cancel();
    emit(state.copyWith(step: PaymentStep.starting, resendCooldown: 0));
    final started = await _repository.startPayment(state.email.value);
    if (isClosed) return;
    switch (started) {
      case Ok(value: final session):
        final payment = StoredPayment(
          reference: session.reference,
          session: session,
        );
        await _repository.keepPayment(payment);
        if (isClosed) return;
        emit(state.copyWith(step: PaymentStep.checkout, payment: payment));
      case Err(:final failure):
        emit(state.copyWith(step: PaymentStep.ready, failure: failure));
    }
  }

  /// The checkout closed, whether paid or not.
  Future<void> checkoutClosed() async {
    final payment = state.payment;
    if (state.step != PaymentStep.checkout || payment == null) return;
    await _verify(payment, afterAttempt: true);
  }

  /// "Verify Reference": a reference paid earlier.
  Future<void> verifyReference() async {
    if (state.step != PaymentStep.ready || state.reference.isEmpty) return;
    await _verify(
      StoredPayment(reference: state.reference),
      afterAttempt: true,
    );
  }

  /// "I've paid, check again": transfers can take a while to confirm.
  Future<void> recheck() async {
    final payment = state.payment;
    if (state.step != PaymentStep.ready || payment == null) return;
    await _verify(payment, afterAttempt: true);
  }

  Future<void> _verify(
    StoredPayment payment, {
    required bool afterAttempt,
  }) async {
    emit(state.copyWith(step: PaymentStep.verifying));
    final result = await _repository.verifyPayment(
      payment.reference,
      gateway: payment.session?.gateway,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(value: PaymentStatus.paid):
        final paid = payment.paid();
        await _repository.keepPayment(paid);
        if (isClosed) return;
        emit(state.copyWith(step: PaymentStep.paid, payment: paid));
      case Ok(value: final status):
        emit(
          state.copyWith(
            step: PaymentStep.ready,
            // A typed-in reference isn't kept until it's paid.
            payment: payment.session == null ? null : payment,
            notice: switch (status) {
              PaymentStatus.failed => PaymentNotice.failed,
              _ when afterAttempt => PaymentNotice.notReceived,
              _ => null,
            },
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(step: PaymentStep.ready, failure: failure));
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    if (resendCooldownSeconds <= 0) return;
    emit(state.copyWith(resendCooldown: resendCooldownSeconds));
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = state.resendCooldown - 1;
      if (left <= 0) timer.cancel();
      emit(state.copyWith(resendCooldown: left, keepFailure: true));
    });
  }

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }
}
