import 'package:vital_reg_mobile/core/result/result.dart';

/// Who the "Face Validation" screen photographs: the NIN whose photo the
/// face must match, or none (the face is only captured).
typedef FaceSubject = ({String? nin});

/// The application "Face Validation" is for, and where its photo goes.
abstract interface class FaceSource {
  /// The application in progress; null when none was started.
  Future<FaceSubject?> subject();

  /// Whether the face in [photoPath] matches the photo held for [nin].
  Future<Result<bool>> matchFace(String photoPath, {required String nin});

  /// Moves a just-captured photo to private storage. [replacing] is
  /// deleted.
  Future<String> keepPhoto(String capturedPath, {String? replacing});

  Future<void> deleteFile(String path);

  /// Keeps [photo] as the application's face, dropping the previous one.
  Future<void> keepFace(String photo, {required bool matched});
}
