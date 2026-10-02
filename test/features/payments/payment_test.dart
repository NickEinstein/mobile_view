import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/payments/data/dtos/payment_dtos.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';
import 'package:vital_reg_mobile/features/payments/presentation/checkout/payment_checkout.dart';
import 'package:vital_reg_mobile/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:vital_reg_mobile/features/payments/presentation/view/payment_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_payment_source.dart';

/// Records each checkout; [onOpen] decides whether it was paid.
class _FakeCheckout implements PaymentCheckout {
  _FakeCheckout(this.onOpen);

  final void Function(PaymentSession session) onOpen;

  @override
  Future<void> open(BuildContext context, PaymentSession session) async =>
      onOpen(session);
}

void main() {
  late FakePaymentSource repository;

  setUp(() => repository = FakePaymentSource());

  PaymentCubit build() => PaymentCubit(repository, resendCooldownSeconds: 0);

  /// Loaded, email typed, code sent and typed.
  Future<void> toOtp(PaymentCubit cubit) async {
    await cubit.load();
    cubit.emailChanged('payer@mail.com');
    await cubit.pay();
    cubit.otpChanged('123456');
  }

  group('PaymentCubit', () {
    blocTest<PaymentCubit, PaymentState>(
      'shows the fee',
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.step, PaymentStep.ready);
        expect(cubit.state.quote?.total, 210000);
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      'offers to retry when the fee does not load',
      setUp: () => repository.quoteResult = const Err(NetworkFailure()),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.step, PaymentStep.loadFailed),
    );

    blocTest<PaymentCubit, PaymentState>(
      'Pay needs a valid email, then sends the code',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.emailChanged('not-an-email');
        expect(cubit.state.canPay, isFalse);
        cubit.emailChanged('payer@mail.com');
        await cubit.pay();
      },
      verify: (cubit) {
        expect(cubit.state.step, PaymentStep.otp);
        expect(repository.otpsSent, 1);
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      'says so when the email cannot receive mail',
      setUp: () => repository.sendOtpResult = const Ok(false),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.emailChanged('payer@mail.com');
        await cubit.pay();
      },
      verify: (cubit) {
        expect(cubit.state.step, PaymentStep.ready);
        expect(cubit.state.notice, PaymentNotice.emailCannotReceive);
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      'a wrong code keeps the dialog open',
      setUp: () => repository.confirmOtpResult = const Err(
        ValidationFailure(message: 'The code is incorrect or expired.'),
      ),
      build: build,
      act: (cubit) async {
        await toOtp(cubit);
        await cubit.confirmOtp();
      },
      verify: (cubit) {
        expect(cubit.state.step, PaymentStep.otp);
        expect(cubit.state.failure, isA<ValidationFailure>());
        expect(repository.starts, 0);
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      'a confirmed code sets up the payment and keeps its reference first',
      build: build,
      act: (cubit) async {
        await toOtp(cubit);
        await cubit.confirmOtp();
      },
      verify: (cubit) {
        expect(cubit.state.step, PaymentStep.checkout);
        expect(
          repository.stored,
          StoredPayment(reference: 'BRT8UY7Q6Y', session: sampleSession),
        );
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      'is paid once the backend confirms it',
      setUp: () => repository.verifyResult = const Ok(PaymentStatus.paid),
      build: build,
      act: (cubit) async {
        await toOtp(cubit);
        await cubit.confirmOtp();
        await cubit.checkoutClosed();
      },
      verify: (cubit) {
        expect(cubit.state.step, PaymentStep.paid);
        expect(repository.stored?.isPaid, isTrue);
        // Confirmed with the gateway that took the payment.
        expect(repository.verifiedGateways, ['alatpay']);
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      'unpaid after checkout: says so, and Pay reopens the same payment',
      build: build,
      act: (cubit) async {
        await toOtp(cubit);
        await cubit.confirmOtp();
        await cubit.checkoutClosed();
        expect(cubit.state.notice, PaymentNotice.notReceived);
        await cubit.pay();
      },
      verify: (cubit) {
        expect(cubit.state.step, PaymentStep.checkout);
        expect(repository.starts, 1);
        expect(repository.otpsSent, 1);
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      '"check again" picks up a late payment',
      build: build,
      act: (cubit) async {
        await toOtp(cubit);
        await cubit.confirmOtp();
        await cubit.checkoutClosed();
        repository.verifyResult = const Ok(PaymentStatus.paid);
        await cubit.recheck();
      },
      verify: (cubit) => expect(cubit.state.step, PaymentStep.paid),
    );

    blocTest<PaymentCubit, PaymentState>(
      'a reference paid earlier is accepted',
      setUp: () => repository.verifyResult = const Ok(PaymentStatus.paid),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit
          ..modeChanged(PaymentMode.enterReference)
          ..referenceChanged(' brt123 ');
        await cubit.verifyReference();
      },
      verify: (cubit) {
        expect(repository.verified, ['BRT123']);
        expect(cubit.state.step, PaymentStep.paid);
        expect(
          repository.stored,
          const StoredPayment(reference: 'BRT123', isPaid: true),
        );
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      'an unpaid reference is not kept',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit
          ..modeChanged(PaymentMode.enterReference)
          ..referenceChanged('BRT123');
        await cubit.verifyReference();
      },
      verify: (cubit) {
        expect(cubit.state.notice, PaymentNotice.notReceived);
        expect(repository.stored, isNull);
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      'on return, a confirmed payment needs no new check',
      setUp: () => repository.stored = const StoredPayment(
        reference: 'BRT1',
        isPaid: true,
      ),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.step, PaymentStep.paid);
        expect(repository.verified, isEmpty);
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      'on return, checks a payment left unconfirmed',
      setUp: () => repository
        ..stored = StoredPayment(
          reference: 'BRT8UY7Q6Y',
          session: sampleSession,
        )
        ..verifyResult = const Ok(PaymentStatus.paid),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.step, PaymentStep.paid);
        expect(repository.starts, 0);
      },
    );
  });

  group('payment JSON', () {
    test('only a completed, successful payment counts as paid', () {
      expect(
        paymentStatusFromJson({'success': true, 'status': 'completed'}),
        PaymentStatus.paid,
      );
      expect(
        paymentStatusFromJson({'success': false, 'status': 'completed'}),
        PaymentStatus.pending,
      );
      expect(
        paymentStatusFromJson({'success': true, 'status': 'failed'}),
        PaymentStatus.failed,
      );
    });

    test('checkout pages must be https', () {
      expect(
        () => sessionFromJson({
          'reference': 'R1',
          'url': 'http://gateway.test/pay',
        }, returnUrl: sampleSession.returnUrl),
        throwsFormatException,
      );
    });

    test('a kept payment reads back the same', () {
      final withSession = StoredPayment(
        reference: 'BRT8UY7Q6Y',
        session: sampleSession,
        isPaid: true,
      );
      const typedIn = StoredPayment(reference: 'R1', isPaid: true);
      expect(
        storedPaymentFromJson(storedPaymentToJson(withSession)),
        withSession,
      );
      expect(storedPaymentFromJson(storedPaymentToJson(typedIn)), typedIn);
    });
  });

  testWidgets('email, code, checkout, verified, continue', (tester) async {
    final opened = <PaymentSession>[];
    var continued = 0;
    final checkout = _FakeCheckout((session) {
      opened.add(session);
      repository.verifyResult = const Ok(PaymentStatus.paid);
    });

    await tester.pumpApp(
      BlocProvider(
        create: (_) => build()..load().ignore(),
        child: PaymentView(checkout: checkout, onPaid: () => continued++),
      ),
    );
    await tester.pumpAndSettle();

    // One fee, as the price API gives it.
    expect(find.text('₦2,100'), findsWidgets);
    expect(find.text('VAT'), findsNothing);
    expect(find.text('Make Payment'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'payer@mail.com');
    await tester.pump();
    await tester.tap(find.text('Pay ₦2,100'));
    await tester.pumpAndSettle();

    expect(find.text('Authorize Transaction'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.pump();
    await tester.tap(find.text('Authorize'));
    await tester.pumpAndSettle();

    expect(find.text('Authorize Transaction'), findsNothing);
    expect(opened, [sampleSession]);
    expect(find.text('Payment Verified Successfully'), findsOneWidget);
    expect(find.text('BRT8UY7Q6Y'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(continued, 1);
  });

  testWidgets('Enter Reference verifies a reference paid earlier', (
    tester,
  ) async {
    repository.verifyResult = const Ok(PaymentStatus.paid);
    await tester.pumpApp(
      BlocProvider(
        create: (_) => build()..load().ignore(),
        child: PaymentView(checkout: _FakeCheckout((_) {}), onPaid: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter Reference'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'BRT123');
    await tester.pump();
    await tester.tap(find.text('Verify Reference'));
    await tester.pumpAndSettle();

    expect(find.text('Payment Verified Successfully'), findsOneWidget);
  });
}
