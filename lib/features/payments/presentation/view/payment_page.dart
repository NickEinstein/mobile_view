import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_code_field.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_dialog.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_text_field.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';
import 'package:vital_reg_mobile/features/payments/presentation/checkout/payment_checkout.dart';
import 'package:vital_reg_mobile/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:vital_reg_mobile/features/payments/presentation/view/naira.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

part 'otp_dialog.dart';
part 'payment_widgets.dart';

/// "Payment", before a paid service's form. [onPaid] runs once confirmed.
class PaymentPage extends StatelessWidget {
  const PaymentPage({required this.source, required this.onPaid, super.key});

  final PaymentSource source;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PaymentCubit(source)..load().ignore(),
      child: PaymentView(
        checkout: GetIt.instance<PaymentCheckout>(),
        onPaid: onPaid,
      ),
    );
  }
}

class PaymentView extends StatelessWidget {
  const PaymentView({required this.checkout, required this.onPaid, super.key});

  final PaymentCheckout checkout;
  final VoidCallback onPaid;

  Future<void> _openCheckout(BuildContext context, PaymentState state) async {
    final cubit = context.read<PaymentCubit>();
    final session = state.payment?.session;
    if (session == null) return;
    await checkout.open(context, session);
    await cubit.checkoutClosed();
  }

  Future<void> _confirmPaid(BuildContext context, String reference) async {
    await _showVerifiedDialog(context, reference: reference);
    onPaid();
  }

  void _onStep(BuildContext context, PaymentState state) {
    switch (state) {
      case PaymentState(step: PaymentStep.otp):
        unawaited(_showOtpDialog(context));
      case PaymentState(step: PaymentStep.checkout):
        unawaited(_openCheckout(context, state));
      case PaymentState(
        step: PaymentStep.paid,
        payment: StoredPayment(:final reference),
      ):
        unawaited(_confirmPaid(context, reference));
      case _:
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<PaymentCubit>().state;
    final cubit = context.read<PaymentCubit>();
    final quote = state.quote;

    return BlocListener<PaymentCubit, PaymentState>(
      // Into the code dialog only from sending it, not back from a wrong
      // code (the dialog is still open then).
      listenWhen: (previous, current) =>
          previous.step != current.step &&
          (current.step != PaymentStep.otp ||
              previous.step == PaymentStep.sendingOtp),
      listener: _onStep,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              0,
              Spacing.md,
              Spacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.baPaymentTitle,
                  style: textTheme.titleLarge?.copyWith(
                    color: AppPalette.inkStrong,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Expanded(
                  child: switch ((state.step, quote)) {
                    (PaymentStep.loadFailed, _) => _LoadFailed(
                      message:
                          state.failure?.localize(l10n) ?? l10n.errorUnexpected,
                      onRetry: cubit.load,
                    ),
                    (_, null) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    (_, final quote?) => ListView(
                      children: [
                        _ModeTabs(
                          mode: state.mode,
                          onChanged: state.isBusy ? null : cubit.modeChanged,
                        ),
                        const SizedBox(height: Spacing.lg),
                        if (state.mode == PaymentMode.makePayment)
                          _MakePayment(state: state, quote: quote)
                        else
                          _EnterReference(state: state),
                        ..._messages(context, state),
                        if (state.mode == PaymentMode.makePayment) ...[
                          const SizedBox(height: Spacing.xl),
                          _Summary(quote: quote),
                        ],
                      ],
                    ),
                  },
                ),
                if (quote != null)
                  if (state.mode == PaymentMode.makePayment) ...[
                    AppButton(
                      label: l10n.baPay(
                        formatNaira(
                          context,
                          quote.total,
                          currency: quote.currency,
                        ),
                      ),
                      isLoading: state.isBusy,
                      onPressed: state.canPay ? cubit.pay : null,
                    ),
                    if (state.hasPendingPayment)
                      TextButton(
                        onPressed: state.step == PaymentStep.ready
                            ? cubit.recheck
                            : null,
                        child: Text(l10n.baCheckPayment),
                      ),
                  ] else
                    AppButton(
                      label: l10n.baVerifyReference,
                      isLoading: state.isBusy,
                      onPressed: state.canVerifyReference
                          ? cubit.verifyReference
                          : null,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _messages(BuildContext context, PaymentState state) {
    final l10n = context.l10n;
    final message = switch (state.notice) {
      PaymentNotice.notReceived => l10n.baPaymentNotReceived,
      PaymentNotice.failed => l10n.baPaymentFailed,
      PaymentNotice.emailCannotReceive => l10n.baEmailCannotReceive,
      // A wrong code shows in its dialog.
      null when state.step == PaymentStep.otp => null,
      null => state.failure?.localize(l10n),
    };
    if (message == null) return const [];
    return [
      const SizedBox(height: Spacing.md),
      Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ];
  }
}
