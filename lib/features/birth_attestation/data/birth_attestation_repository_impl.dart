import 'dart:io';

import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/network/cancellation.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/storage/draft_files.dart';
import 'package:vital_reg_mobile/core/storage/draft_store.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/dtos/attestation_dtos.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/dtos/nin_dtos.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/face_verifier.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/birth_attestation_repository.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/api_places.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/application_payload.dart'
    show uploadTargetFromJson;
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/birth_registration_dtos.dart'
    show countsFromJson;
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/option_lists.dart'
    as option_lists;
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/payments/data/gateway_payments.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

// Paths and shapes follow the backend (NPC_ECRVS_API_V2,
// src/app/birth-attestation).
class BirthAttestationRepositoryImpl implements BirthAttestationRepository {
  BirthAttestationRepositoryImpl({
    required ApiClient client,
    required UserStorage storage,
    required FaceVerifier faces,
  }) : _client = client,
       _storage = storage,
       _faces = faces,
       payments = GatewayPayments(
         client: client,
         storage: storage,
         type: 'attestation_payment',
         description: 'payment for attestation',
       );

  final ApiClient _client;
  final FaceVerifier _faces;

  /// The draft and payment hold personal data, so they are kept in the
  /// Keychain/Keystore, never in plain preferences.
  final UserStorage _storage;

  late final _drafts = DraftStore<AttestationDraft>(
    _storage,
    key: 'birth_attestation_draft',
    fromJson: AttestationDraft.fromJson,
    toJson: (draft) => draft.toJson(),
    files: (draft) => draft.files,
  );

  DraftFiles get _files => _storage.files;

  /// Kept apart from the draft, so discarding a draft never loses a
  /// payment someone already made.
  @override
  final PaymentSource payments;

  /// The same shape as Birth Registration's.
  @override
  Future<Result<ApplicationCounts>> counts() =>
      _client.get('/birth-attestation/stats/self', decode: countsFromJson);

  @override
  Future<Result<List<BirthApplicationSummary>>> applications({
    required ApplicationStatus status,
    String query = '',
  }) => _client.get(
    '/birth-attestation/list',
    query: {
      'type': status.name,
      if (query.isNotEmpty) 'search': query,
      'page': 1,
    },
    decode: (json) => attestationSummariesFromJson(json, status: status),
  );

  /// NIN photos from `/verify-nin`, for [matchFace]. Kept in memory only:
  /// a biometric photo never goes into the stored draft.
  final _ninPhotos = <String, String>{};

  @override
  Future<Result<ApplicantNinRecord>> verifyNin(String nin) async {
    final result = await _client.get(
      '/verify-nin/${Uri.encodeComponent(nin)}',
      decode: (json) => (
        record: ninRecordFromJson(json, nin: nin),
        photo: ninPhotoFromJson(json),
      ),
    );
    switch (result) {
      case Ok(value: (record: final record?, :final photo)):
        if (photo != null) _ninPhotos[nin] = photo;
        return Ok(record);
      case Ok():
        return const Err(NotFoundFailure());
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// The face service compares the NIN photo with the
  /// capture. After a restart the photo is fetched again.
  @override
  Future<Result<bool>> matchFace(
    String photoPath, {
    required String nin,
  }) async {
    if (!_ninPhotos.containsKey(nin)) {
      final verified = await verifyNin(nin);
      if (verified case Err(:final failure)) return Err(failure);
    }
    final ninPhoto = _ninPhotos[nin];
    // With no NIN photo there is nothing to match: the capture is kept.
    if (ninPhoto == null) return const Ok(true);
    return _faces.matches(ninPhoto: ninPhoto, photoPath: photoPath);
  }

  late final _places = ApiPlaces(client: _client, scope: _storage.scope);

  /// Only places come from the API; the other lists
  /// are fixed in the app.
  @override
  Future<Result<AttestationReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  }) async {
    final base = await _places.base();
    if (base case Err(:final failure)) return Err(failure);
    final places = (base as Ok<ApiPlacesBase>).value;
    final lgas = await _places.lgas(withLgasOf);
    if (lgas case Err(:final failure)) return Err(failure);
    return Ok(
      AttestationReferenceData(
        sexes: option_lists.sexes,
        maritalStatuses: option_lists.maritalStatuses,
        identityTypes: option_lists.identityTypes,
        states: places.states,
        placesOfBirth: option_lists.placesOfOccurrence,
        educationLevels: option_lists.educationLevels,
        occupations: option_lists.occupations,
        requestReasons: option_lists.requestReasons,
        requirements: option_lists.requirements,
        countries: places.countries,
        nationalities: places.nationalities,
      ).withLgas((lgas as Ok<Map<String, List<LgaOption>>>).value),
    );
  }

  /// Files go to storage first, then the application to
  /// `/birth-attestation/add`, or `/self-attestation/no-nin` without a NIN.
  @override
  Future<Result<String?>> submit(
    AttestationDraft draft, {
    required String paymentReference,
    void Function(int sent, int total)? onProgress,
    Cancellation? cancellation,
  }) async {
    // The registration LGA's code goes into the application.
    final places = await referenceData(withLgasOf: draft.chosenStates);
    if (places case Err(:final failure)) return Err(failure);
    final uploads = await _uploadFiles(
      draft,
      onProgress: onProgress,
      cancellation: cancellation,
    );
    if (uploads case Err(:final failure)) return Err(failure);
    return _client.post(
      draft.ninRecord == null
          ? '/self-attestation/no-nin'
          : '/birth-attestation/add',
      body: attestationToJson(
        draft,
        paymentReference: paymentReference,
        places: (places as Ok<AttestationReferenceData>).value,
        uploads: (uploads as Ok<AttestationUploads>).value,
      ),
      headers: {'Idempotency-Key': ?draft.submissionKey},
      cancellation: cancellation,
      decode: attestationNumberFromJson,
    );
  }

  /// Uploads the face (a correction keeps the one on file) and each
  /// document the draft holds. Names carry no personal data.
  Future<Result<AttestationUploads>> _uploadFiles(
    AttestationDraft draft, {
    void Function(int done, int total)? onProgress,
    Cancellation? cancellation,
  }) async {
    final tag =
        draft.submissionKey ?? '${draft.startedOn.millisecondsSinceEpoch}';
    final face = draft.queried == null ? draft.facePhoto : null;
    final documents = draft.documents.files;
    final total = documents.length + (face == null ? 0 : 1);
    var done = 0;
    Future<Result<String>> send(String path, String name) async {
      final result = await _upload(
        path,
        name: '$name-$tag${_extension(path)}',
        cancellation: cancellation,
      );
      if (result is Ok) onProgress?.call(++done, total);
      return result;
    }

    String? faceKey;
    if (face != null) {
      switch (await send(face, 'BA-APPLICANT-FACE')) {
        case Ok(:final value):
          faceKey = value;
        case Err(:final failure):
          return Err(failure);
      }
    }
    final keys = <AttestationDocument, String>{};
    for (final MapEntry(key: document, value: file) in documents.entries) {
      final name = 'BA-${document.name.toUpperCase()}';
      switch (await send(file.path, name)) {
        case Ok(:final value):
          keys[document] = value;
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Ok((face: faceKey, documents: keys));
  }

  static String _extension(String path) =>
      path.toLowerCase().endsWith('.png') ? '.png' : '.jpg';

  /// Asks for a storage URL, then puts the file there. Returns its key.
  Future<Result<String>> _upload(
    String path, {
    required String name,
    Cancellation? cancellation,
  }) async {
    final target = await _client.get(
      '/file-upload-url/${Uri.encodeComponent(name)}',
      cancellation: cancellation,
      decode: uploadTargetFromJson,
    );
    if (target case Err(:final failure)) return Err(failure);
    final (:url, :key) = (target as Ok<({Uri url, String key})>).value;
    final bytes = await File(path).readAsBytes();
    final put = await _client.put(
      url.toString(),
      // Storage authorises by the URL; our token must not go there.
      authenticated: false,
      headers: {
        Headers.contentTypeHeader: _extension(path) == '.png'
            ? 'image/png'
            : 'image/jpeg',
        Headers.contentLengthHeader: bytes.length,
      },
      body: Stream.value(bytes),
      cancellation: cancellation,
      decode: (_) {},
    );
    return switch (put) {
      Ok() => Ok(key),
      Err(:final failure) => Err(failure),
    };
  }

  /// [id] is the attestation number, which the list gives as each row's
  /// id; a record is opened by it.
  @override
  Future<Result<AttestationRecord>> details(String id) => _client.get(
    '/birth-attestation/cert/${Uri.encodeComponent(id)}',
    decode: attestationRecordFromJson,
  );

  /// A queried record's correction: replaced documents go
  /// to storage first; the others keep their keys on file.
  @override
  Future<Result<void>> updateQueried(AttestationDraft draft) async {
    if (draft.queried == null) {
      throw ArgumentError('Not the correction of a queried record.');
    }
    final uploads = await _uploadFiles(draft);
    if (uploads case Err(:final failure)) return Err(failure);
    return _client.patch(
      '/birth-attestation/update',
      body: attestationUpdateToJson(
        draft,
        uploads: (uploads as Ok<AttestationUploads>).value,
      ),
      decode: (_) {},
    );
  }

  @override
  Future<AttestationDraft?> loadDraft() => _drafts.load();

  @override
  Future<void> saveDraft(AttestationDraft draft) => _drafts.save(draft);

  /// Worth resuming once the NIN question is answered.
  @override
  Future<bool> hasResumableDraft() async => (await loadDraft())?.hasNin != null;

  @override
  Future<void> discardDraft() => _drafts.discard();

  @override
  Future<String> keepPhoto(String capturedPath, {String? replacing}) =>
      _files.keepPhoto(capturedPath, replacing: replacing);

  @override
  Future<String> keepDocument(String pickedPath, {String? replacing}) =>
      _files.keepDocument(pickedPath, replacing: replacing);

  @override
  Future<void> deleteFile(String path) => _files.delete(path);
}
