import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/network/cancellation.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/storage/draft_files.dart';
import 'package:vital_reg_mobile/core/storage/draft_store.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/dtos/nin_dtos.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/api_places.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/form_settlements.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/option_lists.dart'
    as option_lists;
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/death_registration/data/dtos/death_dtos.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/death_registration_repository.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_draft.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_form.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_record.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_reference_data.dart';

// Not connected yet: the module only runs against the demo backend.
class DeathRegistrationRepositoryImpl implements DeathRegistrationRepository {
  DeathRegistrationRepositoryImpl({
    required ApiClient client,
    required UserStorage storage,
  }) : _client = client,
       _storage = storage;

  final ApiClient _client;

  /// The draft holds personal data, so it is kept in the
  /// Keychain/Keystore, never in plain preferences.
  final UserStorage _storage;

  late final _drafts = DraftStore<DeathDraft>(
    _storage,
    key: 'death_registration_draft',
    fromJson: DeathDraft.fromJson,
    toJson: (draft) => draft.toJson(),
    files: (draft) => draft.files,
  );
  DraftFiles get _files => _storage.files;

  @override
  Future<Result<ApplicationCounts>> counts() =>
      _client.get('/death-registration/stats', decode: deathCountsFromJson);

  @override
  Future<Result<List<BirthApplicationSummary>>> applications({
    required ApplicationStatus status,
    String query = '',
  }) => _client.get(
    '/death-registration/list/',
    query: {'type': status.name, 'search': query, 'page': 1},
    decode: (json) => deathRegistrationsFromJson(json, status: status),
  );

  @override
  Future<Result<ApplicantNinRecord>> verifyNin(String nin) async {
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
  Future<Result<DeathRecord>> details(String id) => _client.get(
    '/death-registration/${Uri.encodeComponent(id)}',
    decode: deathRecordFromJson,
  );

  /// A queried record's correction.
  @override
  Future<Result<void>> updateQueried(DeathDraft draft) async {
    final queried = draft.queried;
    if (queried == null) {
      throw ArgumentError('Not a recorded registration.');
    }
    final places = await referenceData(withLgasOf: draft.chosenStates);
    if (places case Err(:final failure)) return Err(failure);
    final uploaded = await _uploadFiles(draft);
    if (uploaded case Err(:final failure)) return Err(failure);
    final (
      :documents,
      :signature,
    ) = (uploaded
            as Ok<({Map<DeathDocument, String> documents, String? signature})>)
        .value;
    return _client.patch(
      '/death-registration/update',
      body: deathUpdateToJson(
        draft,
        places: (places as Ok<DeathReferenceData>).value,
        documents: {...queried.documentKeys, ...documents},
        signature: signature ?? queried.signatureKey,
      ),
      decode: (_) {},
    );
  }

  late final _places = ApiPlaces(client: _client, scope: _storage.scope);

  /// Only places come from the API; the other lists
  /// are fixed in the app.
  @override
  Future<Result<DeathReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  }) async {
    final base = await _places.base();
    if (base case Err(:final failure)) return Err(failure);
    final places = (base as Ok<ApiPlacesBase>).value;
    final lgas = await _places.lgas(withLgasOf);
    if (lgas case Err(:final failure)) return Err(failure);
    return Ok(
      DeathReferenceData(
        sexes: option_lists.sexes,
        countries: places.countries,
        nationalities: places.nationalities,
        states: places.states,
        settlements: formSettlements,
        occupations: option_lists.occupations,
        placesOfDeath: option_lists.placesOfOccurrence,
        ethnicGroups: option_lists.ethnicGroups,
        maritalStatuses: option_lists.maritalStatuses,
        literacy: option_lists.literacyLevels,
        educationLevels: option_lists.educationLevels,
        yesNo: option_lists.yesNo,
        causesOfDeath: option_lists.causesOfDeath,
        relationships: option_lists.relationships,
      ).withLgas((lgas as Ok<Map<String, List<LgaOption>>>).value),
    );
  }

  @override
  Future<DeathDraft?> loadDraft() => _drafts.load();

  @override
  Future<void> saveDraft(DeathDraft draft) => _drafts.save(draft);

  @override
  Future<bool> hasResumableDraft() async =>
      (await loadDraft())?.hasAnswers ?? false;

  @override
  Future<void> discardDraft() => _drafts.discard();

  @override
  Future<String> keepSignature(Uint8List png, {String? replacing}) =>
      _files.keepSignature(png, replacing: replacing);

  @override
  Future<String> keepDocument(String pickedPath, {String? replacing}) =>
      _files.keepDocument(pickedPath, replacing: replacing);

  @override
  Future<void> deleteFile(String path) => _files.delete(path);

  /// Each document and the signature go to storage first,
  /// and their keys are sent with the registration.
  @override
  Future<Result<String?>> submit(
    DeathDraft draft, {
    void Function(int done, int total)? onProgress,
    Cancellation? cancellation,
  }) async {
    if (draft.signature == null) {
      throw ArgumentError('The informant has not signed.');
    }
    // The registration state's and LGA's codes go into the registration.
    final places = await referenceData(withLgasOf: draft.chosenStates);
    if (places case Err(:final failure)) return Err(failure);
    final uploaded = await _uploadFiles(
      draft,
      onProgress: onProgress,
      cancellation: cancellation,
    );
    if (uploaded case Err(:final failure)) return Err(failure);
    final (
      :documents,
      :signature,
    ) = (uploaded
            as Ok<({Map<DeathDocument, String> documents, String? signature})>)
        .value;
    return _client.post(
      '/death-registration/add',
      body: deathToJson(
        draft,
        places: (places as Ok<DeathReferenceData>).value,
        documents: documents,
        signature: signature,
      ),
      headers: {'Idempotency-Key': ?draft.submissionKey},
      cancellation: cancellation,
      decode: deathAddedFromJson,
    );
  }

  /// Uploads the draft's attached documents and signature. Returns their
  /// keys.
  Future<Result<({Map<DeathDocument, String> documents, String? signature})>>
  _uploadFiles(
    DeathDraft draft, {
    void Function(int done, int total)? onProgress,
    Cancellation? cancellation,
  }) async {
    final signature = draft.signature;
    final tag =
        draft.submissionKey ?? '${draft.startedOn.millisecondsSinceEpoch}';
    final total = draft.documents.files.length + (signature == null ? 0 : 1);
    var done = 0;
    final keys = <DeathDocument, String>{};
    for (final MapEntry(key: document, value: file)
        in draft.documents.files.entries) {
      final uploaded = await _upload(
        file.path,
        // Names carry no personal data (a picked file's name might).
        name:
            'DN-INFORMANT-DOC-${document.apiType}-$tag${_extension(file.path)}',
        cancellation: cancellation,
      );
      if (uploaded case Err(:final failure)) return Err(failure);
      keys[document] = (uploaded as Ok<String>).value;
      onProgress?.call(++done, total);
    }
    if (signature == null) return Ok((documents: keys, signature: null));
    final signed = await _upload(
      signature,
      name: 'DN-INFORMANT-sign-$tag.png',
      cancellation: cancellation,
    );
    if (signed case Err(:final failure)) return Err(failure);
    onProgress?.call(++done, total);
    return Ok((documents: keys, signature: (signed as Ok<String>).value));
  }

  static String _extension(String path) =>
      path.toLowerCase().endsWith('.png') ? '.png' : '.jpg';

  /// Asks for a storage URL, then puts the image there. Returns its key.
  Future<Result<String>> _upload(
    String path, {
    required String name,
    Cancellation? cancellation,
  }) async {
    final target = await _client.get(
      '/file-upload-url/${Uri.encodeComponent(name)}',
      cancellation: cancellation,
      decode: deathUploadTargetFromJson,
    );
    if (target case Err(:final failure)) return Err(failure);
    final (:url, :key) = (target as Ok<({Uri url, String key})>).value;
    final bytes = await File(path).readAsBytes();
    final put = await _client.put(
      url.toString(),
      // Storage authorises by the URL; our token must not go there.
      authenticated: false,
      headers: {
        Headers.contentTypeHeader: path.toLowerCase().endsWith('.png')
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
}
