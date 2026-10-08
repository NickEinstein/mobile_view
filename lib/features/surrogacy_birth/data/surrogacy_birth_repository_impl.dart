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
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/api_places.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/option_lists.dart'
    as option_lists;
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/payments/data/gateway_payments.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/data/dtos/surrogacy_dtos.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_form.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_record.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_reference_data.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/surrogacy_birth_repository.dart';

// Not connected yet: the module only runs against the demo backend.
class SurrogacyBirthRepositoryImpl implements SurrogacyBirthRepository {
  SurrogacyBirthRepositoryImpl({
    required ApiClient client,
    required UserStorage storage,
  }) : _client = client,
       _storage = storage,
       payments = GatewayPayments(
         client: client,
         storage: storage,
         // The backend's transaction type for this fee.
         type: 'surrogacy_registration_payment',
         description: 'payment for surrogate birth registration',
         // The "Enter reference" check for this module.
         referenceCheckPath: '/surrogacy-birth-registration/payment',
       );

  final ApiClient _client;

  /// The draft holds personal data, so it is kept in the
  /// Keychain/Keystore, never in plain preferences.
  final UserStorage _storage;

  @override
  final PaymentSource payments;

  static const _basePath = '/surrogacy-birth-registration';
  late final _drafts = DraftStore<SurrogacyDraft>(
    _storage,
    key: 'surrogacy_birth_draft',
    fromJson: SurrogacyDraft.fromJson,
    toJson: (draft) => draft.toJson(),
    files: (draft) => draft.files,
  );
  DraftFiles get _files => _storage.files;

  static String _application(String referenceId) =>
      '$_basePath/${Uri.encodeComponent(referenceId)}';

  @override
  Future<Result<ApplicationCounts>> counts() =>
      _client.get('$_basePath/stats', decode: countsFromJson);

  @override
  Future<Result<List<BirthApplicationSummary>>> applications({
    required ApplicationStatus status,
    String query = '',
  }) => _client.get(
    _basePath,
    query: {'status': status.name, 'search': query, 'page': 1},
    decode: (json) => applicationsFromJson(json, requested: status),
  );

  @override
  Future<Result<String>> initiate() =>
      _client.post('$_basePath/initiate', decode: referenceIdFromJson);

  @override
  Future<Result<ApplicantNinRecord>> lookupNin(String nin) async {
    final result = await _client.get(
      '/verify-nin/${Uri.encodeComponent(nin)}',
      decode: (json) => ninRecordFromJson(json, nin: nin),
    );
    return switch (result) {
      Ok(value: final record?) => Ok(record),
      Ok() => const Err(NotFoundFailure()),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> verifyChildNin({
    required String referenceId,
    required String nin,
  }) => _client.post(
    '${_application(referenceId)}/verify-child-nin',
    body: {'nin': nin},
    decode: (_) {},
  );

  @override
  Future<Result<void>> skipChildNin(String referenceId) => _client.post(
    '${_application(referenceId)}/skip-nin-verification',
    decode: (_) {},
  );

  @override
  Future<Result<void>> attachPayment({
    required String referenceId,
    required String reference,
  }) => _client.post(
    '${_application(referenceId)}/payment',
    body: {'reference': reference},
    decode: (_) {},
  );

  /// Reference data rarely changes; load it once per app run.
  late final _places = ApiPlaces(client: _client, scope: _storage.scope);

  /// Only places come from the API; the other lists are fixed in the app.
  @override
  Future<Result<SurrogacyReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  }) async {
    final base = await _places.base();
    if (base case Err(:final failure)) return Err(failure);
    final places = (base as Ok<ApiPlacesBase>).value;
    final lgas = await _places.lgas(withLgasOf);
    if (lgas case Err(:final failure)) return Err(failure);
    return Ok(
      SurrogacyReferenceData(
        sexes: option_lists.sexes,
        birthOrders: option_lists.birthOrders,
        typesOfBirth: option_lists.typesOfBirth,
        placesOfBirth: option_lists.placesOfOccurrence,
        localityTypes: option_lists.localityTypes,
        arrangementTypes: option_lists.arrangementTypes,
        states: places.states,
        countries: places.countries,
        nationalities: places.nationalities,
        maritalStatuses: option_lists.maritalStatuses,
        occupations: option_lists.occupations,
        literacyLevels: option_lists.literacyLevels,
        educationLevels: option_lists.educationLevels,
        relationships: option_lists.relationships,
        centres: places.centres,
      ).withLgas((lgas as Ok<Map<String, List<LgaOption>>>).value),
    );
  }

  @override
  Future<Result<SurrogacyRecord>> details(String id) => _client.get(
    '$_basePath/${Uri.encodeComponent(id)}',
    decode: surrogacyRecordFromJson,
  );

  @override
  Future<Result<List<BirthApplicationSummary>>> drafts() => _client.get(
    _basePath,
    query: {'status': 'drafted', 'page': 1},
    decode: (json) =>
        applicationsFromJson(json, requested: ApplicationStatus.pending),
  );

  @override
  Future<Result<SurrogacyRecord>> resume(String referenceId) => _client.get(
    '${_application(referenceId)}/resume',
    decode: surrogacyRecordFromJson,
  );

  /// "Respond to Query": the whole application, by its
  /// reference, without a section number.
  @override
  Future<Result<void>> amend(SurrogacyDraft draft) async {
    final uploaded = await _uploadPending(draft);
    return switch (uploaded) {
      Ok(value: final ready) => _client.patch(
        '${_application(draft.referenceId)}/update',
        body: surrogacySectionToJson(ready, section: null),
        decode: (_) {},
      ),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<SurrogacyDraft>> saveSection(
    SurrogacyDraft draft,
    SurrogacySection section,
  ) async {
    final uploaded = await _uploadPending(draft);
    if (uploaded case Err(:final failure)) return Err(failure);
    final ready = (uploaded as Ok<SurrogacyDraft>).value;
    final saved = await _client.patch(
      '${_application(draft.referenceId)}/section',
      body: surrogacySectionToJson(ready, section: section),
      decode: (_) {},
    );
    return switch (saved) {
      Ok() => Ok(ready),
      Err(:final failure) => Err(failure),
    };
  }

  /// Uploads every file not yet uploaded; returns the draft with them.
  Future<Result<SurrogacyDraft>> _uploadPending(SurrogacyDraft draft) async {
    var uploaded = draft;
    for (final path in draft.filesToUpload) {
      if (uploaded.uploads.containsKey(path)) continue;
      final result = await _upload(path);
      switch (result) {
        case Ok(value: final key):
          uploaded = uploaded.copyWith(
            uploads: {...uploaded.uploads, path: key},
          );
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Ok(uploaded);
  }

  /// A file goes to storage first, and its key is sent.
  /// Asks for a storage URL, then puts the file there.
  Future<Result<String>> _upload(String path) async {
    final extension = path.substring(path.lastIndexOf('.') + 1).toLowerCase();
    final name =
        'surrogate-birth-${DateTime.now().millisecondsSinceEpoch}.$extension';
    final target = await _client.get(
      '/file-upload-url/${Uri.encodeComponent(name)}',
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
        Headers.contentTypeHeader: switch (extension) {
          'png' => 'image/png',
          'pdf' => 'application/pdf',
          _ => 'image/jpeg',
        },
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

  @override
  Future<SurrogacyDraft?> loadDraft() => _drafts.load();

  @override
  Future<void> saveDraft(SurrogacyDraft draft) => _drafts.save(draft);

  /// Every unfinished registration is worth resuming: the server already
  /// holds it.
  @override
  Future<bool> hasResumableDraft() async => await loadDraft() != null;

  /// Deletes the draft and its files; a payment not yet attached is kept.
  @override
  Future<void> discardDraft() async {
    final draft = await _drafts.discard();
    if (draft?.paymentReference != null) await payments.clearPayment();
  }

  @override
  Future<String> keepPhoto(String capturedPath, {String? replacing}) =>
      _files.keepPhoto(capturedPath, replacing: replacing);

  @override
  Future<String> keepSignature(Uint8List png, {String? replacing}) =>
      _files.keepSignature(png, replacing: replacing);

  @override
  Future<String> keepDocument(String pickedPath, {String? replacing}) =>
      _files.keepDocument(pickedPath, replacing: replacing);

  @override
  Future<void> deleteFile(String path) => _files.delete(path);

  @override
  Future<Result<String?>> submit(String referenceId) => _client.post(
    '${_application(referenceId)}/submit',
    decode: submittedFromJson,
  );
}
