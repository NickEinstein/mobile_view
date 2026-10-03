import 'dart:convert';
import 'dart:io';

import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/core/result/result.dart';

/// The face service (`FACE_VERIFICATION_URL`): it compares the NIN photo with a
/// captured face and answers `{"possibleMatch": bool, "score", …}`.
class FaceVerifier {
  FaceVerifier({required ApiClient client, required String? url})
    : _client = client,
      _url = url;

  final ApiClient _client;
  final String? _url;

  /// Whether the face in [photoPath] matches [ninPhoto], the NIN record's
  /// photo (base64, as `/verify-nin` gives it).
  Future<Result<bool>> matches({
    required String ninPhoto,
    required String photoPath,
  }) async {
    final url = _url;
    if (url == null) {
      return const Err(
        UnexpectedFailure('Face verification is not configured.'),
      );
    }
    final face = base64Encode(await File(photoPath).readAsBytes());
    return _client.post(
      url,
      // A separate service: our token must not go there.
      authenticated: false,
      body: {
        'image': {'format': 'JPEG', 'template': ninPhoto},
        'imageToVerifyAgainst': {'format': 'JPEG', 'template': face},
        'level': 'HIGH',
      },
      decode: (json) => json.asJsonMap()['possibleMatch'] == true,
    );
  }
}
