import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';

// Shapes follow the backend (NPC_ECRVS_API_V2, src/app/payments).

/// `GET /payments/price/{type}`: `{"amount": 5000, "currency": "NGN"}`, the
/// amount in major units (naira).
PaymentQuote quoteFromJson(Object? json) {
  final map = json.asJsonMap();
  final amount = map['amount'];
  final major = switch (amount) {
    final num value => value,
    final String value => num.tryParse(value),
    _ => null,
  };
  if (major == null) {
    throw const FormatException('Expected "amount" to be a number.');
  }
  return PaymentQuote(
    total: (major * 100).round(),
    currency: map.optionalString('currency') ?? 'NGN',
  );
}

/// `GET /can-receive-email/{email}`: `{"valid": true}`
bool emailValidFromJson(Object? json) => json.asJsonMap()['valid'] == true;

/// `POST /payments/initiate`: `{"gateway", "reference", "url"}`.
PaymentSession sessionFromJson(Object? json, {required Uri returnUrl}) {
  final map = json.asJsonMap();
  return PaymentSession(
    reference: map.requireString('reference'),
    checkoutUrl: httpsUrl(map.requireString('url')),
    returnUrl: returnUrl,
    gateway: map.optionalString('gateway'),
  );
}

/// `GET /payments/verify` and each gateway's own `POST …/verify`: `{"success": true, "status": "completed"}`.
/// Anything not completed is still pending, unless it says it failed.
PaymentStatus paymentStatusFromJson(Object? json) {
  final map = json.asJsonMap();
  final status = map.optionalString('status')?.toLowerCase();
  if (map['success'] == true && status == 'completed') {
    return PaymentStatus.paid;
  }
  return switch (status) {
    'failed' || 'declined' || 'cancelled' => PaymentStatus.failed,
    _ => PaymentStatus.pending,
  };
}

JsonMap storedPaymentToJson(StoredPayment payment) => {
  'reference': payment.reference,
  'isPaid': payment.isPaid,
  if (payment.session case final session?)
    'session': {
      'checkoutUrl': session.checkoutUrl.toString(),
      'returnUrl': session.returnUrl.toString(),
      'gateway': ?session.gateway,
    },
};

StoredPayment storedPaymentFromJson(Object? json) {
  final map = json.asJsonMap();
  final reference = map.requireString('reference');
  final session = map['session'];
  return StoredPayment(
    reference: reference,
    isPaid: map['isPaid'] == true,
    session: session == null
        ? null
        : PaymentSession(
            reference: reference,
            checkoutUrl: httpsUrl(
              session.asJsonMap().requireString('checkoutUrl'),
            ),
            returnUrl: httpsUrl(session.asJsonMap().requireString('returnUrl')),
            gateway: session.asJsonMap().optionalString('gateway'),
          ),
  );
}

/// Payment pages are only ever opened over HTTPS.
Uri httpsUrl(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw const FormatException('Expected an https URL.');
  }
  return uri;
}
