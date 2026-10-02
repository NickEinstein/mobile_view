import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';
import 'package:vital_reg_mobile/features/payments/presentation/checkout/payment_checkout.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The gateway's checkout page in a web view, so card details never enter
/// the app (out of PCI scope).
class GatewayPaymentCheckout implements PaymentCheckout {
  const GatewayPaymentCheckout();

  @override
  Future<void> open(BuildContext context, PaymentSession session) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => GatewayCheckoutPage(session: session),
        ),
      );
}

class GatewayCheckoutPage extends StatefulWidget {
  const GatewayCheckoutPage({required this.session, super.key});

  final PaymentSession session;

  @override
  State<GatewayCheckoutPage> createState() => _GatewayCheckoutPageState();
}

class _GatewayCheckoutPageState extends State<GatewayCheckoutPage> {
  final _controller = WebViewController();
  var _progress = 0;
  var _loadFailed = false;
  var _closed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: _onNavigation,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        onWebResourceError: (error) {
          if ((error.isForMainFrame ?? true) && mounted) {
            setState(() => _loadFailed = true);
          }
        },
      ),
    );
    await _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loadFailed = false);
    await _controller.loadRequest(widget.session.checkoutUrl);
  }

  /// Done at our return URL. Only HTTPS pages may open.
  NavigationDecision _onNavigation(NavigationRequest request) {
    final url = Uri.tryParse(request.url);
    if (url == null) return NavigationDecision.prevent;
    final returnUrl = widget.session.returnUrl;
    if (url.scheme == returnUrl.scheme &&
        url.host == returnUrl.host &&
        url.path == returnUrl.path) {
      _close();
      return NavigationDecision.prevent;
    }
    return url.scheme == 'https'
        ? NavigationDecision.navigate
        : NavigationDecision.prevent;
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.baCheckoutTitle),
        leading: IconButton(
          tooltip: l10n.baCloseCheckout,
          icon: const Icon(Icons.close),
          onPressed: _close,
        ),
        bottom: _progress < 100 && !_loadFailed
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: _loadFailed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.baCheckoutLoadFailed,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => unawaited(_load()),
                      child: Text(l10n.tryAgain),
                    ),
                  ],
                ),
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}
