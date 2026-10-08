import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/features/payments/presentation/checkout/payment_checkout.dart';

/// Registers the app-wide checkout; each service has its own
/// `GatewayPayments`.
void registerPaymentsModule(GetIt getIt, {required PaymentCheckout checkout}) {
  getIt.registerSingleton<PaymentCheckout>(checkout);
}
