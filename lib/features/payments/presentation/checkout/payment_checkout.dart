import 'package:flutter/widgets.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';

/// Where the payer pays: the gateway's checkout in real builds, a stand-in with
/// the demo backend. Bound in the composition root.
// ignore: one_member_abstracts
abstract interface class PaymentCheckout {
  /// Shows the checkout for [session] and completes when the payer is done
  /// or closes it. Whether they paid is then asked of our backend.
  Future<void> open(BuildContext context, PaymentSession session);
}
