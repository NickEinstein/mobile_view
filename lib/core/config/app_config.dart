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
    this.useFakeApi = false,
    this.deviceIdOverride,
  });

  factory AppConfig.fromEnvironment(Flavor flavor) {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const timeoutMinutes = int.fromEnvironment(
      'SESSION_TIMEOUT_MINUTES',
      defaultValue: 15,
    );
    const sentryDsn = String.fromEnvironment('SENTRY_DSN');
    const features = String.fromEnvironment('FEATURES');
    const useFakeApi = bool.fromEnvironment('USE_FAKE_API');
    const deviceId = String.fromEnvironment('DEVICE_ID');

    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not set. Run with '
        '--dart-define-from-file=config/${flavor.name}.json',
      );
    }
    if (useFakeApi && flavor != Flavor.dev) {
      throw StateError('USE_FAKE_API is only allowed in the dev flavor.');
    }
    if (deviceId.isNotEmpty && flavor == Flavor.prod) {
      throw StateError('DEVICE_ID is not allowed in the prod flavor.');
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
      useFakeApi: useFakeApi,
      deviceIdOverride: deviceId.isEmpty ? null : deviceId,
    );
  }

  final Flavor flavor;
  final String apiBaseUrl;
  final Duration sessionTimeout;
  final Set<Feature> enabledFeatures;
  final String sentryDsn;

  /// Dev only: answer API calls from `FakeBackendInterceptor` instead of a
  /// server, for demos before the backend exists.
  final bool useFakeApi;

  /// Dev and staging only: a fixed device id, so testers can reuse the one
  /// their account is bound to. Keep it in the git-ignored config file.
  final String? deviceIdOverride;
}
