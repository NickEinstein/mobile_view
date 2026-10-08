import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

const sampleQuote = PaymentQuote(total: 210000);

final sampleSession = PaymentSession(
  reference: 'BRT8UY7Q6Y',
  checkoutUrl: Uri.parse('https://gateway.test/pay/BRT8UY7Q6Y'),
  returnUrl: Uri.parse('https://api.test/payments/done'),
  gateway: 'alatpay',
);

/// A payment already made, for flows that start after paying.
const paidPayment = StoredPayment(reference: 'BRTPAID1', isPaid: true);

/// In-memory [PaymentSource] with scripted answers, shared by every
/// feature that takes a payment.
class FakePaymentSource implements PaymentSource {
  FakePaymentSource({this.stored});

  Result<PaymentQuote> quoteResult = const Ok(sampleQuote);
  Result<bool> sendOtpResult = const Ok(true);
  Result<void> confirmOtpResult = const Ok(null);
  Result<PaymentSession> startResult = Ok(sampleSession);
  Result<PaymentStatus> verifyResult = const Ok(PaymentStatus.pending);

  StoredPayment? stored;
  int otpsSent = 0;
  int starts = 0;
  int clears = 0;
  final List<String> verified = [];

  @override
  Future<Result<PaymentQuote>> quote() async => quoteResult;

  @override
  Future<Result<bool>> sendPaymentOtp(String email) async {
    otpsSent++;
    return sendOtpResult;
  }

  @override
  Future<Result<void>> resendPaymentOtp(String email) async {
    otpsSent++;
    return const Ok(null);
  }

  @override
  Future<Result<void>> confirmPaymentOtp({
    required String email,
    required String code,
  }) async => confirmOtpResult;

  @override
  Future<Result<PaymentSession>> startPayment(String email) async {
    starts++;
    return startResult;
  }

  /// The gateway each [verifyPayment] call named, if any.
  final List<String?> verifiedGateways = [];

  @override
  Future<Result<PaymentStatus>> verifyPayment(
    String reference, {
    String? gateway,
  }) async {
    verified.add(reference);
    verifiedGateways.add(gateway);
    return verifyResult;
  }

  @override
  Future<StoredPayment?> storedPayment() async => stored;

  @override
  Future<void> keepPayment(StoredPayment payment) async => stored = payment;

  @override
  Future<void> clearPayment() async {
    clears++;
    stored = null;
  }
}
