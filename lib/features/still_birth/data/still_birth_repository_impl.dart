import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/storage/draft_files.dart';
import 'package:vital_reg_mobile/core/storage/draft_store.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/api_places.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/form_settlements.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/option_lists.dart'
    as option_lists;
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/still_birth/data/dtos/still_birth_dtos.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_draft.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_form.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_record.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_reference_data.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_summary.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/still_birth_repository.dart';

// Not connected yet: the module only runs against the demo backend.
class StillBirthRepositoryImpl implements StillBirthRepository {
  StillBirthRepositoryImpl({
    required ApiClient client,
    required UserStorage storage,
  }) : _client = client,
       _storage = storage;

  final ApiClient _client;

  /// The draft holds personal data, so it is kept in the
  /// Keychain/Keystore, never in plain preferences.
  final UserStorage _storage;

  late final _drafts = DraftStore<StillBirthDraft>(
    _storage,
    key: 'still_birth_draft',
    fromJson: StillBirthDraft.fromJson,
    toJson: (draft) => draft.toJson(),
    files: (draft) => draft.files,
  );
  DraftFiles get _files => _storage.files;

  @override
  Future<Result<int>> count() =>
      _client.get('/stillbirth/stats', decode: countFromJson);

  @override
  Future<Result<List<StillBirthSummary>>> registrations({String query = ''}) =>
      _client.get(
        '/stillbirth/list/',
        query: {'search': query, 'page': 1},
        decode: registrationsFromJson,
      );

  @override
  Future<Result<StillBirthRecord>> details(String id) => _client.get(
    // Chosen for Certificate Details: the backend's `single`.
    '/stillbirth/${Uri.encodeComponent(id)}',
    // `single` doesn't return the record's own id.
    decode: (json) => stillBirthRecordFromJson(json, id: id),
  );

  late final _places = ApiPlaces(client: _client, scope: _storage.scope);

  /// Only places come from the API; the other lists
  /// are fixed in the app.
  @override
  Future<Result<StillBirthReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  }) async {
    final base = await _places.base();
    if (base case Err(:final failure)) return Err(failure);
    final places = (base as Ok<ApiPlacesBase>).value;
    final lgas = await _places.lgas(withLgasOf);
    if (lgas case Err(:final failure)) return Err(failure);
    return Ok(
      StillBirthReferenceData(
        placesOfOccurrence: option_lists.placesOfOccurrence,
        sexes: option_lists.sexes,
        typesOfDelivery: option_lists.typesOfBirth,
        countries: places.countries,
        nationalities: places.nationalities,
        states: places.states,
        settlements: formSettlements,
        ethnicGroups: option_lists.ethnicGroups,
        relationships: option_lists.relationships,
      ).withLgas((lgas as Ok<Map<String, List<LgaOption>>>).value),
    );
  }

  @override
  Future<StillBirthDraft?> loadDraft() => _drafts.load();

  @override
  Future<void> saveDraft(StillBirthDraft draft) => _drafts.save(draft);

  @override
  Future<bool> hasResumableDraft() async =>
      (await loadDraft())?.hasAnswers ?? false;

  @override
  Future<void> discardDraft() => _drafts.discard();

  @override
  Future<String> keepSignature(Uint8List png, {String? replacing}) =>
      _files.keepSignature(png, replacing: replacing);

  @override
  Future<void> deleteFile(String path) => _files.delete(path);

  /// The signature goes to storage first, and its key is
  /// sent as the informant's acknowledgement.
  @override
  Future<Result<String?>> submit(StillBirthDraft draft) async {
    final signature = draft.informant[InformantField.signature];
    if (signature == null) {
      throw ArgumentError('The informant has not signed.');
    }
    final uploaded = await _upload(signature);
    if (uploaded case Err(:final failure)) return Err(failure);
    return _client.post(
      '/stillbirth/add',
      body: stillBirthToJson(draft, signature: (uploaded as Ok<String>).value),
      headers: {'Idempotency-Key': ?draft.submissionKey},
      decode: addedFromJson,
    );
  }

  /// Asks for a storage URL, then puts the PNG there. Returns its key.
  Future<Result<String>> _upload(String path) async {
    final name =
        'BR-STILLBIRTH-INFORMANT-sign-'
        '${DateTime.now().millisecondsSinceEpoch}.png';
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
        Headers.contentTypeHeader: 'image/png',
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
}
