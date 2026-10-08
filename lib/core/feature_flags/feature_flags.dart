/// Every module ships behind a flag, OFF by default, so unfinished modules
/// never reach users.
enum Feature {
  birthRegistration,
  birthAttestation,
  modifications,
  stillBirthRegistration,
  deathRegistration,
  surrogacyBirthRegistration,
  adoptedChildRegistration,
  singleParentBirthRegistration,
  foreignBirthNotification,
  reissuance,
  approvals,
  reports;

  /// Parses a comma-separated list such as `birthRegistration,reports`.
  /// Unknown names are ignored.
  static Set<Feature> parseList(String raw) => {
    for (final name in raw.split(',')) ?_byName[name.trim()],
  };

  static final Map<String, Feature> _byName = {
    for (final feature in values) feature.name: feature,
  };
}

abstract interface class FeatureFlags {
  bool isEnabled(Feature feature);
}

/// Flags fixed at build time from `FEATURES`.
final class StaticFeatureFlags implements FeatureFlags {
  const StaticFeatureFlags(this._enabled);

  final Set<Feature> _enabled;

  @override
  bool isEnabled(Feature feature) => _enabled.contains(feature);
}
