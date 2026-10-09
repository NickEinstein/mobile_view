import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/session/user_scope.dart';
import 'package:vital_reg_mobile/core/storage/draft_files.dart';
import 'package:vital_reg_mobile/core/storage/draft_store.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/dtos/nin_dtos.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/option_lists.dart'
    as option_lists;
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/data/dtos/reissuance_dtos.dart'
    show lgasFromJson, statesFromJson;
import 'package:vital_reg_mobile/features/foreign_birth/data/dtos/foreign_birth_dtos.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_draft.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_record.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_reference_data.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/foreign_birth_repository.dart';
import 'package:vital_reg_mobile/features/payments/data/gateway_payments.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

// Not connected yet: the module only runs against the demo backend.
class ForeignBirthRepositoryImpl implements ForeignBirthRepository {
  ForeignBirthRepositoryImpl({
    required ApiClient client,
    required UserStorage storage,
  }) : _client = client,
       _storage = storage,
       payments = GatewayPayments(
         client: client,
         storage: storage,
         // The backend's transaction type for this fee.
         type: 'birthnoti_payment',
         description: 'payment for foreign birth notification',
       );

  final ApiClient _client;

  /// The draft holds personal data, so it is kept in the
  /// Keychain/Keystore, never in plain preferences.
  final UserStorage _storage;

  @override
  final PaymentSource payments;

  static const _basePath = '/birth-notification';
  late final _drafts = DraftStore<ForeignBirthDraft>(
    _storage,
    key: 'foreign_birth_draft',
    fromJson: ForeignBirthDraft.fromJson,
    toJson: (draft) => draft.toJson(),
    files: (draft) => draft.files,
  );
  DraftFiles get _files => _storage.files;

  @override
  Future<Result<ApplicationCounts>> counts() =>
      _client.get('$_basePath/stats/self', decode: countsFromJson);

  // The backend filters by `type`.
  @override
  Future<Result<List<BirthApplicationSummary>>> applications({
    required ApplicationStatus status,
    String query = '',
  }) => _client.get(
    _basePath,
    query: {
      'type': status.name,
      if (query.isNotEmpty) 'search': query,
      'page': 1,
    },
    decode: (json) {
      final rows = applicationsFromJson(json, requested: status);
      for (final row in rows) {
        _statuses[row.id] = row.status;
      }
      return rows;
    },
  );

  /// Each listed record's status, by notification number: `/cert` doesn't
  /// return it, so it comes from the list row.
  final _statuses = <String, ApplicationStatus>{};

  /// Reference data rarely changes; load it once per app run.
  late final _referenceData = UserCache<ForeignBirthReferenceData>(
    _storage.scope,
  );
  final _states = <String, List<Option>>{};
  final _lgas = <String, List<Option>>{};

  /// The fixed option lists for the foreign-birth form.
  static const _optionLists = ForeignBirthReferenceData(
    sexes: option_lists.sexes,
    typesOfBirth: option_lists.typesOfBirth,
    birthOrders: option_lists.birthOrders,
    placesOfOccurrence: option_lists.placesOfOccurrence,
    maritalStatuses: option_lists.maritalStatuses,
    occupations: option_lists.occupations,
    literacyLevels: option_lists.literacyLevels,
    educationLevels: option_lists.educationLevels,
    ethnicGroups: option_lists.ethnicGroups,
    relationships: option_lists.relationships,
    countries: [],
  );

  @override
  Future<Result<ForeignBirthReferenceData>> referenceData() async {
    final cached = _referenceData.value;
    if (cached != null) return Ok(cached);
    // Only places come from the API; the other lists
    // are fixed in the app.
    final countries = await _client.get(
      '/option/country',
      decode: countriesFromJson,
    );
    switch (countries) {
      case Ok(value: final countries):
        final data = _optionLists.withCountries(countries);
        _referenceData.value = data;
        return Ok(data);
      case Err(:final failure):
        return Err(failure);
    }
  }

  @override
  Future<Result<List<Option>>> states(String countryId) =>
      _cached(_states, countryId, '/option/states/', statesFromJson);

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
  Future<ForeignBirthDraft?> loadDraft() => _drafts.load();

  @override
  Future<void> saveDraft(ForeignBirthDraft draft) => _drafts.save(draft);

  @override
  Future<bool> hasResumableDraft() async => await loadDraft() != null;

  /// Deletes the draft and its files; an unused payment is kept.
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
  Future<Result<ForeignBirthDraft>> uploadFiles(ForeignBirthDraft draft) async {
    var uploaded = draft;
    for (final path in draft.filesToUpload) {
      if (uploaded.uploads.containsKey(path)) continue;
      switch (await _upload(path)) {
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
        'foreign-birth-${DateTime.now().millisecondsSinceEpoch}.$extension';
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
        Headers.contentTypeHeader: extension == 'png'
            ? 'image/png'
            : 'image/jpeg',
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
  Future<Result<String?>> submit(ForeignBirthDraft draft) async {
    // The country's ISO code comes from the reference data.
    final data = await referenceData();
    if (data case Err(:final failure)) return Err(failure);
    return _client.post(
      '$_basePath/add',
      body: foreignBirthPayloadToJson(
        draft,
        data: (data as Ok<ForeignBirthReferenceData>).value,
      ),
      decode: submittedFromJson,
    );
  }

  @override
  /// [id] is the notification number, which records are opened by.
  @override
  Future<Result<ForeignBirthRecord>> details(String id) => _client.get(
    '$_basePath/cert/${Uri.encodeComponent(id)}',
    decode: (json) => foreignBirthRecordFromJson(json, status: _statuses[id]),
  );

  // The method (PATCH) is confirmed by the backend's controller.
  @override
  Future<Result<void>> amend(
    ForeignBirthDraft draft, {
    required ForeignBirthRecord record,
  }) async {
    final data = await referenceData();
    if (data case Err(:final failure)) return Err(failure);
    return _client.patch(
      '$_basePath/update',
      body: foreignBirthAmendToJson(
        draft,
        record: record,
        data: (data as Ok<ForeignBirthReferenceData>).value,
      ),
      decode: (_) {},
    );
  }
}
