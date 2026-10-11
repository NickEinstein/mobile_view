import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// The last answer of each `/option/*` place list, kept on the device for
/// offline use. Lists never downloaded fall back to the copies bundled in
/// `assets/reference/` (registration centres have none).
class SavedPlaces {
  /// Tests pass a temporary [root] and their own [bundle].
  SavedPlaces({Future<Directory> Function()? root, AssetBundle? bundle})
    : _root = root ?? getApplicationSupportDirectory,
      _bundle = bundle ?? rootBundle;

  final Future<Directory> Function() _root;
  final AssetBundle _bundle;

  static final _lgaPath = RegExp(r'^/option/lga/(.+)$');

  Future<File> _file(String path) async => File(
    '${(await _root()).path}/reference/${Uri.encodeComponent(path)}.json',
  );

  /// Keeps [json], the API's answer to [path]. Failing to save only means
  /// an older copy is used offline.
  Future<void> save(String path, Object? json) async {
    try {
      final file = await _file(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(json), flush: true);
    } on Object {
      return;
    }
  }

  /// The saved answer to [path], else the bundled one, else null.
  Future<Object?> read(String path) async {
    try {
      final file = await _file(path);
      if (file.existsSync()) return jsonDecode(await file.readAsString());
    } on Object {
      // A damaged copy is replaced by the next download.
    }
    return _bundled(path);
  }

  Future<Object?> _bundled(String path) async {
    if (path == '/option/country') return _asset('countries');
    if (path.startsWith('/option/states/')) return _asset('states');
    if (_lgaPath.firstMatch(path) case final match?) {
      final stateId = Uri.decodeComponent(match.group(1)!);
      final lgas = await _asset('lgas');
      return [
        for (final lga in lgas! as List<Object?>)
          if (lga is Map && '${lga['State_ID']}' == stateId) lga,
      ];
    }
    return null;
  }

  Future<Object?> _asset(String name) async =>
      jsonDecode(await _bundle.loadString('assets/reference/$name.json'));
}
