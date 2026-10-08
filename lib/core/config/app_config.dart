import 'package:vital_reg_mobile/core/feature_flags/feature_flags.dart';

enum Flavor { dev, staging, prod }

/// Public runtime configuration, from
/// `--dart-define-from-file=config/<flavor>.json`. NEVER put secrets here:
/// anything compiled into the app can be extracted.
final class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiBaseUrl,
    required this.sessionTimeout,
    required this.enabledFeatures,
    this.sentryDsn = '',
  });

  factory AppConfig.fromEnvironment(Flavor flavor) {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const timeoutMinutes = int.fromEnvironment(
      'SESSION_TIMEOUT_MINUTES',
      defaultValue: 15,
    );
    const sentryDsn = String.fromEnvironment('SENTRY_DSN');
    const features = String.fromEnvironment('FEATURES');

    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not set. Run with '
        '--dart-define-from-file=config/${flavor.name}.json',
      );
    }
    if (flavor != Flavor.dev && !apiBaseUrl.startsWith('https://')) {
      throw StateError('Non-dev builds must use an https:// API_BASE_URL.');
    }

    return AppConfig(
      flavor: flavor,
      apiBaseUrl: apiBaseUrl,
      sessionTimeout: const Duration(minutes: timeoutMinutes),
      enabledFeatures: Feature.parseList(features),
      sentryDsn: sentryDsn,
    );
  }

  final Flavor flavor;
  final String apiBaseUrl;
  final Duration sessionTimeout;
  final Set<Feature> enabledFeatures;
  final String sentryDsn;
}
