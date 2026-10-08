import 'package:equatable/equatable.dart';

/// What the attestation costs. Amounts are in kobo, so money is never a
/// floating-point number.
final class PaymentQuote extends Equatable {
  const PaymentQuote({required this.total, this.currency = 'NGN'});

  /// In minor units (kobo for naira). The gateway may add its charges at
  /// checkout.
  final int total;

  /// ISO code, e.g. NGN; the backend prices payers abroad in another.
  final String currency;

  @override
  List<Object?> get props => [total, currency];
}

/// A payment set up by our backend: its reference and the gateway's
/// checkout page, which ends at [returnUrl].
final class PaymentSession extends Equatable {
  const PaymentSession({
    required this.reference,
    required this.checkoutUrl,
    required this.returnUrl,
    this.gateway,
  });

  final String reference;
  final Uri checkoutUrl;
  final Uri returnUrl;

  /// The gateway our backend chose (e.g.
  /// `alatpay`), whose own check confirms the payment afterwards.
  final String? gateway;

  @override
  List<Object?> get props => [reference, checkoutUrl, returnUrl, gateway];
}

enum PaymentStatus { pending, paid, failed }

/// The payment kept on the device until its application is submitted, so
/// no one pays twice.
final class StoredPayment extends Equatable {
  const StoredPayment({
    required this.reference,
    this.session,
    this.isPaid = false,
  });

  final String reference;

  /// Null for a reference the user typed in ("Enter Reference").
  final PaymentSession? session;

  /// Our backend confirmed it.
  final bool isPaid;

  StoredPayment paid() =>
      StoredPayment(reference: reference, session: session, isPaid: true);

  @override
  List<Object?> get props => [reference, session, isPaid];

  @override
  String toString() => 'StoredPayment(paid: $isPaid)';
}
