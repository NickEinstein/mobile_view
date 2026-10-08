import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:vital_reg_mobile/core/session/user_scope.dart';

/// Photos, signatures and documents of drafts, in app-private storage, one
/// folder per user.
class DraftFiles {
  /// [root] is the app-private folder the drafts live in; tests pass a
  /// temporary one.
  DraftFiles(this._scope, {Future<Directory> Function()? root})
    : _root = root ?? getApplicationSupportDirectory;

  final UserScope _scope;
  final Future<Directory> Function() _root;

  Future<Directory> _directory() async => Directory(
    '${(await _root()).path}/drafts/'
    '${_scope.segment}',
  );

  Future<String> _newFile(String prefix, String extension) async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}'
        '.$extension';
  }

  /// Moves a just-captured photo (the camera writes to a shared cache)
  /// here and returns its new path. [replacing] is deleted.
  Future<String> keepPhoto(String capturedPath, {String? replacing}) async {
    final target = await _newFile('face', 'jpg');
    await File(capturedPath).copy(target);
    await delete(capturedPath);
    if (replacing != null) await delete(replacing);
    return target;
  }

  /// Stores a drawn signature (PNG). [replacing] is deleted.
  Future<String> keepSignature(Uint8List png, {String? replacing}) async {
    final target = await _newFile('signature', 'png');
    await File(target).writeAsBytes(png, flush: true);
    if (replacing != null) await delete(replacing);
    return target;
  }

  /// Moves a picked document here. [replacing] is deleted.
  Future<String> keepDocument(String pickedPath, {String? replacing}) async {
    final dot = pickedPath.lastIndexOf('.');
    final extension = dot < 0 ? 'bin' : pickedPath.substring(dot + 1);
    final target = await _newFile('document', extension.toLowerCase());
    await File(pickedPath).copy(target);
    // The picker hands us a temporary copy; don't leave one in the cache.
    await delete(pickedPath);
    if (replacing != null) await delete(replacing);
    return target;
  }

  Future<void> delete(String path) async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }

  /// Deletes every file of the current user's drafts.
  Future<void> clear() async {
    final dir = await _directory();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
