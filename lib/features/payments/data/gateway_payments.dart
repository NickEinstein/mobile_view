import 'dart:convert';

import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';
import 'package:vital_reg_mobile/features/payments/data/dtos/payment_dtos.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

/// [PaymentSource] for one transaction type, e.g.
/// `birth_modification_payment`.
class GatewayPayments implements PaymentSource {
  GatewayPayments({
    required ApiClient client,
    required UserStorage storage,
    required this.type,
    required this.description,
    this.referenceCheckPath,
  }) : _client = client,
       _storage = storage;

  final ApiClient _client;

  /// The payment holds a reference someone paid for, so it is kept in the
  /// Keychain/Keystore, never in plain preferences.
  final UserStorage _storage;

  /// The backend's transaction type.
  final String type;

  /// Shown on the gateway's checkout.
  final String description;

  /// A module's own check for a typed-in reference (answering `{valid}`);
  /// otherwise `GET /payments/verify`.
  final String? referenceCheckPath;

  /// One kept payment per transaction type.
  String get _paymentKey => UserStorage.paymentKey(type);

  /// Where gateways send the payer when done; the checkout page closes
  /// when it is reached.
  static final _returnUrl = Uri.parse(
    'https://ecrvs.ng/dashboard/payment-verification/gateway',
  );

  @override
  Future<Result<PaymentQuote>> quote() =>
      _client.get('/payments/price/$type', decode: quoteFromJson);

  @override
  Future<Result<bool>> sendPaymentOtp(String email) async {
    final canReceive = await _client.get(
      '/can-receive-email/${Uri.encodeComponent(email)}',
      decode: emailValidFromJson,
    );
    return switch (canReceive) {
      Ok(value: true) => _client.post(
        '/validation/send-otp',
        body: {'email': email},
        decode: (_) => true,
      ),
      Ok() => const Ok(false),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> resendPaymentOtp(String email) => _client.post(
    '/validation/resend-otp',
    body: {'email': email},
    decode: (_) {},
  );

  @override
  Future<Result<void>> confirmPaymentOtp({
    required String email,
    required String code,
  }) => _client.post(
    '/validation/validate-otp',
    body: {'email': email, 'otp': code},
    decode: (_) {},
  );

  @override
  Future<Result<PaymentSession>> startPayment(String email) => _client.post(
    '/payments/initiate',
    body: {
      'email': email,
      'type': type,
      'description': description,
      'redirectUrl': _returnUrl.toString(),
    },
    decode: (json) => sessionFromJson(json, returnUrl: _returnUrl),
  );

  /// Each gateway's check, called after a checkout.
  static const _gatewayChecks = {
    'alatpay': '/payments/alat/verify',
    'paystack': '/payments/paystack/verify',
    'credo': '/payments/credo/verify',
    'unified_payment': '/payments/unified/verify',
  };

  /// After a checkout, the backend asks the gateway; otherwise it looks up
  /// a completed payment.
  @override
  Future<Result<PaymentStatus>> verifyPayment(
    String reference, {
    String? gateway,
  }) => switch (_gatewayChecks[gateway]) {
    final path? => _client.post(
      path,
      body: {'reference': reference, 'type': type},
      decode: paymentStatusFromJson,
    ),
    null => switch (referenceCheckPath) {
      final path? => _client.get(
        path,
        query: {'reference': reference},
        decode: (json) => json.asJsonMap()['valid'] == true
            ? PaymentStatus.paid
            : PaymentStatus.pending,
      ),
      null => _client.get(
        '/payments/verify',
        query: {'reference': reference, 'type': type},
        decode: paymentStatusFromJson,
      ),
    },
  };

  @override
  Future<StoredPayment?> storedPayment() async {
    final raw = await _storage.read(key: _paymentKey);
    if (raw == null) return null;
    try {
      return storedPaymentFromJson(jsonDecode(raw));
    } on Object {
      // Unreadable (e.g. from an older app version). Leave it in storage
      // so the payment can still be traced, but don't use it.
      return null;
    }
  }

  @override
  Future<void> keepPayment(StoredPayment payment) => _storage.write(
    key: _paymentKey,
    value: jsonEncode(storedPaymentToJson(payment)),
  );

  @override
  Future<void> clearPayment() => _storage.delete(key: _paymentKey);
}
