import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// The only logger; silent in release. Run payloads through `Redactor`.
class AppLogger {
  AppLogger()
    : _logger = Logger(
        level: kReleaseMode ? Level.off : Level.debug,
        printer: PrettyPrinter(methodCount: 0),
      );

  final Logger _logger;

  void debug(String message) => _logger.d(message);

  void info(String message) => _logger.i(message);

  void warning(String message) => _logger.w(message);

  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
