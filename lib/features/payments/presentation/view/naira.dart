import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// [kobo] as naira, e.g. ₦2,100 (or ₦2,100.50 when there are kobo). In
/// another [currency] (minor units too), with that currency's symbol.
String formatNaira(BuildContext context, int kobo, {String currency = 'NGN'}) =>
    NumberFormat.currency(
      locale: Localizations.localeOf(context).toString(),
      name: currency,
      symbol: currency == 'NGN'
          ? '₦'
          : NumberFormat.simpleCurrency(name: currency).currencySymbol,
      decimalDigits: kobo % 100 == 0 ? 0 : 2,
    ).format(kobo / 100);
