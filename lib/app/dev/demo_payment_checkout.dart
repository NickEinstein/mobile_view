import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';
import 'package:vital_reg_mobile/features/payments/presentation/checkout/payment_checkout.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Stands in for the payment gateway's checkout with the demo backend: "Pay" marks the
/// reference paid there, "Cancel" leaves it unpaid.
class DemoPaymentCheckout implements PaymentCheckout {
  const DemoPaymentCheckout();

  @override
  Future<void> open(BuildContext context, PaymentSession session) async {
    final paid = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.baDemoCheckoutTitle),
          content: Text(l10n.baDemoCheckoutMessage(session.reference)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.baDemoCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.baDemoPay),
            ),
          ],
        );
      },
    );
    if (paid ?? false) {
      FakeBackendInterceptor.paidReferences.add(session.reference);
    }
  }
}
