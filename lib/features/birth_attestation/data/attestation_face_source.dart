import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/face_source.dart';

/// The face of the Birth Attestation draft started at the NIN step.
class AttestationFaceSource implements FaceSource {
  AttestationFaceSource(this._repository);

  final BirthAttestationRepository _repository;
  AttestationDraft? _draft;

  @override
  Future<FaceSubject?> subject() async {
    final draft = _draft = await _repository.loadDraft();
    return draft == null ? null : (nin: draft.ninRecord?.nin);
  }

  @override
  Future<Result<bool>> matchFace(String photoPath, {required String nin}) =>
      _repository.matchFace(photoPath, nin: nin);

  @override
  Future<String> keepPhoto(String capturedPath, {String? replacing}) =>
      _repository.keepPhoto(capturedPath, replacing: replacing);

  @override
  Future<void> deleteFile(String path) => _repository.deleteFile(path);

  @override
  Future<void> keepFace(String photo, {required bool matched}) async {
    final draft = _draft ?? await _repository.loadDraft();
    if (draft == null) return;
    final previous = draft.facePhoto;
    final next = draft.withFace(photo, matched: matched);
    await _repository.saveDraft(next);
    _draft = next;
    if (previous != null && previous != photo) {
      await _repository.deleteFile(previous);
    }
  }
}
