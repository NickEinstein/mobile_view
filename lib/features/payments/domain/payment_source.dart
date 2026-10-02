import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';

/// A payment: email → one-time code → the gateway's checkout → our backend
/// confirms.
abstract interface class PaymentSource {
  /// The current fee.
  Future<Result<PaymentQuote>> quote();

  /// Checks [email] can receive mail and, if so, sends it a one-time code
  /// (true). The payment reference is later emailed there too.
  Future<Result<bool>> sendPaymentOtp(String email);

  Future<Result<void>> resendPaymentOtp(String email);

  Future<Result<void>> confirmPaymentOtp({
    required String email,
    required String code,
  });

  /// Asks our backend to set up a payment; it picks the gateway.
  Future<Result<PaymentSession>> startPayment(String email);

  /// Asks our backend whether [reference] is paid (a redirect is never
  /// trusted). [gateway] is set after a checkout.
  Future<Result<PaymentStatus>> verifyPayment(
    String reference, {
    String? gateway,
  });

  /// The payment kept on this device, if any.
  Future<StoredPayment?> storedPayment();

  Future<void> keepPayment(StoredPayment payment);

  /// Once whatever used the payment is submitted.
  Future<void> clearPayment();
}
