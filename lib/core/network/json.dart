typedef JsonMap = Map<String, Object?>;

/// Type-checked JSON reading: a mismatch throws [FormatException], which
/// `ApiClient` turns into an `UnexpectedFailure`.
extension JsonDecoding on Object? {
  JsonMap asJsonMap() {
    final self = this;
    if (self is Map<String, Object?>) return self;
    throw const FormatException('Expected a JSON object.');
  }
}

extension JsonMapReader on JsonMap {
  String requireString(String key) {
    final value = this[key];
    if (value is String) return value;
    throw FormatException('Expected "$key" to be a string.');
  }

  String? optionalString(String key) {
    final value = this[key];
    return value is String ? value : null;
  }

  int requireInt(String key) {
    final value = this[key];
    if (value is int) return value;
    throw FormatException('Expected "$key" to be an integer.');
  }

  JsonMap requireMap(String key) => this[key].asJsonMap();
}
