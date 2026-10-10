import 'dart:convert';

import 'package:flutter/services.dart';

/// State and LGA names by id, from the place lists bundled with the app
/// (`assets/reference/`).
class BundledPlaceNames {
  BundledPlaceNames({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<String?> state(String? id) =>
      _name('states', idKey: 'State_ID', nameKey: 'State_Name', id: id);

  Future<String?> lga(String? id) =>
      _name('lgas', idKey: 'LGA_ID', nameKey: 'LGA_Name', id: id);

  Future<String?> _name(
    String list, {
    required String idKey,
    required String nameKey,
    required String? id,
  }) async {
    if (id == null) return null;
    try {
      final rows = jsonDecode(
        await _bundle.loadString('assets/reference/$list.json'),
      );
      for (final row in rows as List<Object?>) {
        if (row is Map && '${row[idKey]}' == id) return row[nameKey] as String?;
      }
    } on Object {
      return null;
    }
    return null;
  }
}
