import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/storage/draft_files.dart';
import 'package:vital_reg_mobile/core/storage/draft_store.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/dtos/nin_dtos.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/face_verifier.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/face_source.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/form_settlements.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/option_lists.dart'
    as option_lists;
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/data/dtos/reissuance_dtos.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/attestation_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_options.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/reissuance_repository.dart';
import 'package:vital_reg_mobile/features/payments/data/gateway_payments.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

/// The backend's endpoints (NPC_ECRVS_API_V2,
/// src/app/cert-reissuance-assisted).
class ReissuanceRepositoryImpl implements ReissuanceRepository {
  ReissuanceRepositoryImpl({
    required ApiClient client,
    required UserStorage storage,
    required FaceVerifier faces,
  }) : _client = client,
       _storage = storage,
       _faces = faces,
       payments = GatewayPayments(
         client: client,
         storage: storage,
         type: 'cert_reissuance_payment',
         description: 'payment for certificate-reissuance',
       );

  static const _base = '/certificate-reissuance-assisted';

  final FaceVerifier _faces;

  /// NIN photos from `/verify-nin`, for [_matchFace]. Kept in memory only:
  /// a biometric photo never goes into the stored draft.
  final _ninPhotos = <String, String>{};

  /// The draft, in secure storage; the payment is kept apart from it.
  late final _drafts = DraftStore<ReissuanceDraft>(
    _storage,
    key: 'certificate_reissuance_draft',
    fromJson: ReissuanceDraft.fromJson,
    toJson: (draft) => draft.toJson(),
    files: (draft) => draft.files,
  );
  DraftFiles get _files => _storage.files;

  final ApiClient _client;
  final UserStorage _storage;

  @override
  final PaymentSource payments;

  @override
  late final FaceSource face = _ReissuanceFace(this);

  @override
  Future<Result<ReissuanceCounts>> counts(ReissuanceKind kind) =>
      _client.get('$_base/${kind.apiPath}-stats', decode: countsFromJson);

  @override
  Future<Result<List<ReissuanceSummary>>> requests({
    required ReissuanceKind kind,
    ReissuanceStatus? status,
    String query = '',
  }) => _client.get(
    '$_base/${kind.apiPath}-list',
    query: {
      'page': 1,
      'type': ?status?.name,
      if (query.isNotEmpty) 'search': query,
    },
    decode: requestsFromJson,
  );

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

  /// Matches the capture against the NIN photo (refetched after a restart;
  /// none means nothing to match).
  Future<Result<bool>> _matchFace(String photoPath, String nin) async {
    if (!_ninPhotos.containsKey(nin)) {
      final verified = await verifyNin(nin);
      if (verified case Err(:final failure)) return Err(failure);
    }
    final ninPhoto = _ninPhotos[nin];
    if (ninPhoto == null) return const Ok(true);
    return _faces.matches(ninPhoto: ninPhoto, photoPath: photoPath);
  }

  /// Options rarely change; load each list once per app run.
  ReissuanceOptions? _options;
  final Map<String, List<Option>> _states = {};
  final Map<String, List<Option>> _lgas = {};

  @override
  Future<Result<ReissuanceOptions>> options() async {
    final cached = _options;
    if (cached != null) return Ok(cached);
    // Only places come from the API; the other lists
    // are fixed in the app.
    final (countries, centres) = await (
      _client.get('/option/country', decode: countriesFromJson),
      _client.get('/option/registration-centres', decode: centresFromJson),
    ).wait;
    final result = switch ((countries, centres)) {
      (Ok(value: final c), Ok(value: final r)) => Ok(
        ReissuanceOptions(
          typesOfBirth: option_lists.typesOfBirth,
          birthOrders: option_lists.birthOrders,
          sexes: option_lists.sexes,
          placesOfOccurrence: option_lists.placesOfOccurrence,
          localityTypes: formSettlements,
          maritalStatuses: option_lists.maritalStatuses,
          ethnicGroups: option_lists.ethnicGroups,
          literacyLevels: option_lists.literacyLevels,
          educationLevels: option_lists.educationLevels,
          occupations: option_lists.occupations,
          identityTypes: option_lists.identityTypes,
          requestReasons: option_lists.requestReasons,
          requirements: option_lists.requirements,
          countries: c.countries,
          nationalities: c.nationalities,
          centres: r,
        ),
      ),
      (Err(:final failure), _) ||
      (_, Err(:final failure)) => Err<ReissuanceOptions>(failure),
    };
    if (result case Ok(:final value)) _options = value;
    return result;
  }

  @override
  Future<Result<List<Option>>> states(String countryCode) =>
      _cached(_states, countryCode, '/option/states/', statesFromJson);

  @override
  Future<Result<List<Option>>> lgas(String stateId) =>
      _cached(_lgas, stateId, '/option/lga/', lgasFromJson);

  Future<Result<List<Option>>> _cached(
    Map<String, List<Option>> cache,
    String id,
    String path,
    List<Option> Function(Object?) decode,
  ) async {
    final cached = cache[id];
    if (cached != null) return Ok(cached);
    final result = await _client.get(
      '$path${Uri.encodeComponent(id)}',
      decode: decode,
    );
    if (result case Ok(:final value)) cache[id] = value;
    return result;
  }

  @override
  Future<ReissuanceDraft?> loadDraft() => _drafts.load();

  @override
  Future<void> saveDraft(ReissuanceDraft draft) => _drafts.save(draft);

  @override
  Future<void> discardDraft() => _drafts.discard();

  @override
  Future<String> keepDocument(String pickedPath, {String? replacing}) =>
      _files.keepDocument(pickedPath, replacing: replacing);

  @override
  Future<void> deleteFile(String path) => _files.delete(path);

  @override
  Future<String> keepSignature(Uint8List png, {String? replacing}) =>
      _files.keepSignature(png, replacing: replacing);

  @override
  Future<Result<void>> sendEmailCode(String email) => _client.post(
    '/validation/send-otp',
    body: {'email': email},
    decode: (_) {},
  );

  @override
  Future<Result<void>> resendEmailCode(String email) => _client.post(
    '/validation/resend-otp',
    body: {'email': email},
    decode: (_) {},
  );

  @override
  Future<Result<void>> confirmEmailCode({
    required String email,
    required String code,
  }) => _client.post(
    '/validation/validate-otp',
    body: {'email': email, 'otp': code},
    decode: (_) {},
  );

  /// Each file goes to storage first, and its key is sent.
  @override
  Future<Result<String?>> submitBirth(
    ReissuanceDraft draft, {
    required String email,
  }) async {
    final certificate = draft.certificate;
    final form = draft.birthForm;
    final face = draft.facePhoto;
    final signature = form?.signature;
    if (certificate == null || form == null || face == null) {
      throw ArgumentError('The request is not complete.');
    }
    if (signature == null) throw ArgumentError('The parent has not signed.');
    final payment = await payments.storedPayment();
    if (payment == null || !payment.isPaid) {
      return const Err(ValidationFailure(message: 'No payment was found.'));
    }

    final nin = draft.ninRecord.nin;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final document = form.document;
    final uploads = await Future.wait([
      _upload(certificate.filePath, 'REISSUANCE-CERT-$nin-$stamp'),
      _upload(face, 'REISSUANCE-FACE-$nin-$stamp'),
      _upload(signature, 'REISSUANCE-SIGNATURE-$nin-$stamp'),
      if (document != null)
        _upload(document.path, 'REISSUANCE-SUPPORT-DOC-$nin-$stamp'),
    ]);
    for (final upload in uploads) {
      if (upload case Err(:final failure)) return Err(failure);
    }
    String key(int i) => (uploads[i] as Ok<String>).value;

    final result = await _client.post(
      '$_base/add-birth-reg',
      body: birthReissuanceToJson(
        (
          kind: certificate.kind,
          number: certificate.number,
          issuedOn: certificate.issuedOn,
          nin: nin,
        ),
        form,
        files: (
          certificate: key(0),
          face: key(1),
          signature: key(2),
          document: document == null
              ? null
              : (key: key(3), mimeType: _mimeType(document.path)),
        ),
        paymentReference: payment.reference,
        email: email,
        today: DateTime.now(),
      ),
      decode: submittedFromJson,
    );
    if (result is Ok) {
      // Used: a new request needs a new payment.
      await payments.clearPayment();
      await discardDraft();
    }
    return result;
  }

  @override
  Future<Result<BirthReissuanceRecord>> birthRecord(String id) => _client.get(
    '$_base/single-birth-reg/${Uri.encodeComponent(id)}',
    decode: birthRecordFromJson,
  );

  /// A queried request's update: the same fields with the request's
  /// `id` and payment reference. Files already in storage keep their keys.
  @override
  Future<Result<String?>> updateBirth(
    BirthReissuanceRecord record,
    BirthReissuanceForm form, {
    required String email,
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final nin = record.nin;

    Future<Result<String>?> uploadNew(String? path, String name) async =>
        path == null ? null : _upload(path, '$name-$nin-$stamp');
    final (signature, document) = await (
      uploadNew(form.signature, 'REISSUANCE-SIGNATURE'),
      uploadNew(form.document?.path, 'REISSUANCE-SUPPORT-DOC'),
    ).wait;
    for (final upload in [signature, document]) {
      if (upload case Err(:final failure)) return Err(failure);
    }
    final signatureKey = switch (signature) {
      Ok(:final value) => value,
      _ => form.keptSignature?.key,
    };
    if (signatureKey == null) {
      throw ArgumentError('The parent has not signed.');
    }
    final newDocument = form.document;
    final documentFile = switch (document) {
      Ok(:final value) when newDocument != null => (
        key: value,
        mimeType: _mimeType(newDocument.path),
      ),
      _ => switch (form.keptDocument) {
        final kept? => (key: kept.key, mimeType: kept.mimeType),
        null => null,
      },
    };

    final result = await _client.patch(
      '$_base/update-birth-reg',
      body: {
        'id': int.tryParse(record.id) ?? record.id,
        ...birthReissuanceToJson(
          (
            kind: ReissuanceKind.birth,
            number: record.certificateNumber,
            issuedOn: record.issuedOn,
            nin: nin,
          ),
          form,
          files: (
            certificate: record.certificateKey,
            face: record.faceKey ?? '',
            signature: signatureKey,
            document: documentFile,
          ),
          paymentReference: record.reference,
          email: email,
          today: DateTime.now(),
        ),
      },
      decode: submittedFromJson,
    );
    if (result is Ok) {
      // The new files were only kept for sending.
      for (final path in form.files) {
        await _files.delete(path);
      }
    }
    return result;
  }

  @override
  Future<Result<String?>> submitAttestation(ReissuanceDraft draft) async {
    final certificate = draft.certificate;
    final form = draft.attestationForm;
    final face = draft.facePhoto;
    final signature = form?.signature;
    final affidavit = form?.affidavit;
    if (certificate == null ||
        form == null ||
        face == null ||
        signature == null ||
        affidavit == null) {
      throw ArgumentError('The request is not complete.');
    }
    final payment = await payments.storedPayment();
    if (payment == null || !payment.isPaid) {
      return const Err(ValidationFailure(message: 'No payment was found.'));
    }

    final nin = draft.ninRecord.nin;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final uploads = await Future.wait([
      _upload(certificate.filePath, 'REISSUANCE-CERT-$nin-$stamp'),
      _upload(face, 'ASSISTED_REISSUANCE-FACE-$nin-$stamp'),
      _upload(signature, 'REISSUANCE-SIGNATURE-$nin-$stamp'),
      _upload(affidavit.path, 'court-affidavit-$nin-$stamp'),
    ]);
    for (final upload in uploads) {
      if (upload case Err(:final failure)) return Err(failure);
    }
    String key(int i) => (uploads[i] as Ok<String>).value;

    final result = await _client.post(
      '$_base/add-birth-attest',
      body: attestationReissuanceToJson(
        (
          kind: certificate.kind,
          number: certificate.number,
          issuedOn: certificate.issuedOn,
          nin: nin,
        ),
        form,
        files: (
          certificate: key(0),
          face: key(1),
          signature: key(2),
          affidavit: (key: key(3), mimeType: _mimeType(affidavit.path)),
        ),
        paymentReference: payment.reference,
      ),
      decode: submittedFromJson,
    );
    if (result is Ok) {
      // Used: a new request needs a new payment.
      await payments.clearPayment();
      await discardDraft();
    }
    return result;
  }

  @override
  Future<Result<AttestationReissuanceRecord>> attestationRecord(String id) =>
      _client.get(
        '$_base/single-birth-attest/${Uri.encodeComponent(id)}',
        decode: attestationRecordFromJson,
      );

  @override
  Future<Result<String?>> updateAttestation(
    AttestationReissuanceRecord record,
    AttestationReissuanceForm form,
  ) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final nin = record.nin;
    Future<Result<String>?> uploadNew(String? path, String name) async =>
        path == null ? null : _upload(path, '$name-$nin-$stamp');
    final newAffidavit = form.affidavit;
    final (signature, affidavit) = await (
      uploadNew(form.signature, 'REISSUANCE-SIGNATURE'),
      uploadNew(newAffidavit?.path, 'court-affidavit'),
    ).wait;
    for (final upload in [signature, affidavit]) {
      if (upload case Err(:final failure)) return Err(failure);
    }
    final signatureKey = switch (signature) {
      Ok(:final value) => value,
      _ => form.keptSignature?.key,
    };
    final affidavitFile = switch (affidavit) {
      Ok(:final value) when newAffidavit != null => (
        key: value,
        mimeType: _mimeType(newAffidavit.path),
      ),
      _ => switch (form.keptAffidavit) {
        final kept? => (key: kept.key, mimeType: kept.mimeType),
        null => null,
      },
    };
    if (signatureKey == null || affidavitFile == null) {
      throw ArgumentError('The request is not complete.');
    }

    final result = await _client.patch(
      '$_base/update-birth-attest',
      body: {
        'id': int.tryParse(record.id) ?? record.id,
        ...attestationReissuanceToJson(
          (
            kind: ReissuanceKind.attestation,
            number: record.certificateNumber,
            issuedOn: record.issuedOn,
            nin: nin,
          ),
          form,
          files: (
            certificate: record.certificateKey,
            face: record.faceKey ?? '',
            signature: signatureKey,
            affidavit: affidavitFile,
          ),
          paymentReference: record.reference,
        ),
      },
      decode: submittedFromJson,
    );
    if (result is Ok) {
      // The new files were only kept for sending.
      for (final path in form.files) {
        await _files.delete(path);
      }
    }
    return result;
  }

  /// A base64 JPEG. Birth certificates come from the
  /// self-service print path, attestations from the attestation one.
  @override
  Future<Result<Uint8List>> download(ReissuanceKind kind, String reference) {
    final path = switch (kind) {
      ReissuanceKind.birth => '/birth-registration/selfservice/print',
      ReissuanceKind.attestation => '/self-attestation/print',
    };
    return _client.get(
      '$path/${Uri.encodeComponent(reference)}',
      decode: certificateImageFromJson,
    );
  }

  /// Asks for a storage URL, then puts the file there. Returns its key.
  Future<Result<String>> _upload(String path, String name) async {
    final dot = path.lastIndexOf('.');
    final fileName = '$name${dot < 0 ? '' : path.substring(dot)}';
    final target = await _client.get(
      '/file-upload-url/${Uri.encodeComponent(fileName)}',
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
        Headers.contentTypeHeader: _mimeType(path),
        Headers.contentLengthHeader: bytes.length,
      },
      body: Stream.value(bytes),
      decode: (_) {},
    );
    return switch (put) {
      Ok() => Ok(key),
      Err(:final failure) => Err(failure),
    };
  }

  static String _mimeType(String path) =>
      path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
}

/// The face of the draft started at the NIN step; it must match the NIN
/// photo.
class _ReissuanceFace implements FaceSource {
  _ReissuanceFace(this._repository);

  final ReissuanceRepositoryImpl _repository;

  @override
  Future<FaceSubject?> subject() async {
    final draft = await _repository.loadDraft();
    return draft == null ? null : (nin: draft.ninRecord.nin);
  }

  @override
  Future<Result<bool>> matchFace(String photoPath, {required String nin}) =>
      _repository._matchFace(photoPath, nin);

  @override
  Future<String> keepPhoto(String capturedPath, {String? replacing}) =>
      _repository._files.keepPhoto(capturedPath, replacing: replacing);

  @override
  Future<void> deleteFile(String path) => _repository.deleteFile(path);

  @override
  Future<void> keepFace(String photo, {required bool matched}) async {
    final draft = await _repository.loadDraft();
    if (draft == null) return;
    await _repository.saveDraft(draft.withFace(photo));
    final previous = draft.facePhoto;
    if (previous != null && previous != photo) {
      await _repository.deleteFile(previous);
    }
  }
}
