/// Strips tokens, passwords and personal data (NINs, names, dates, photos)
/// before anything is logged.
abstract final class Redactor {
  static const mask = '***';

  static const _sensitiveKeys = {
    'authorization',
    'cookie',
    'setcookie',
    'apikey',
    'xapikey',
    'pin',
    'otp',
    'code',
    'nin',
    'bvn',
    'phone',
    'phonenumber',
    'email',
    'dob',
    'dateofbirth',
    'photo',
    'image',
    'base64image',
    // A face image sent to the face service.
    'template',
    'fingerprint',
    'signature',
  };

  static bool isSensitive(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp('[-_]'), '');
    return _sensitiveKeys.contains(normalized) ||
        normalized.contains('password') ||
        normalized.contains('token') ||
        normalized.contains('secret');
  }

  static final _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');

  /// NINs, BVNs and phone numbers are 11 digits; masking every run of 7 or
  /// more also catches them inside longer text.
  static final _longNumber = RegExp(r'\d{7,}');

  /// Masks emails and long numbers in free text that has no keys to go by,
  /// such as an exception message.
  static String redactText(String text) =>
      text.replaceAll(_email, mask).replaceAll(_longNumber, mask);

  static Object? redact(Object? value) => switch (value) {
    final Map<Object?, Object?> map => {
      for (final MapEntry(key: k, value: v) in map.entries)
        k: isSensitive('$k') ? mask : redact(v),
    },
    final List<Object?> list => [for (final item in list) redact(item)],
    final String text when text.length > 200 =>
      '${text.substring(0, 20)}… (${text.length} chars)',
    _ => value,
  };
}
