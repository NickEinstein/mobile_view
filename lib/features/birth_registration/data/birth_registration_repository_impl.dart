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
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/application_payload.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/birth_registration_dtos.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/form_settlements.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/option_lists.dart'
    as option_lists;
import 'package:vital_reg_mobile/features/birth_registration/domain/birth_registration_repository.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/application_details.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/payments/data/gateway_payments.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

/// The backend's `/birth-registration/*` routes.
class BirthRegistrationRepositoryImpl implements BirthRegistrationRepository {
  BirthRegistrationRepositoryImpl({
    required ApiClient client,
    required UserStorage storage,
  }) : _client = client,
       _storage = storage,
       payments = GatewayPayments(
         client: client,
         storage: storage,
         // The backend's transaction type for a birth registration fee.
         type: 'birth_registration_payment',
         description: 'Payment for New Birth Registration',
       );

  final ApiClient _client;

  /// The draft holds personal data (names, NINs, photo paths), so it is kept
  /// in the Keychain/Keystore, never in plain preferences.
  final UserStorage _storage;
  late final _drafts = DraftStore<RegistrationDraft>(
    _storage,
    key: 'birth_registration_draft',
    fromJson: RegistrationDraft.fromJson,
    toJson: (draft) => draft.toJson(),
    files: (draft) => draft.files,
  );
  static const _basePath = '/birth-registration';
  DraftFiles get _files => _storage.files;

  @override
  final PaymentSource payments;

  late final _places = ApiPlaces(client: _client, scope: _storage.scope);

  @override
  Future<Result<ApplicationCounts>> counts() =>
      _client.get('$_basePath/stats/self', decode: countsFromJson);

  @override
  Future<Result<List<BirthApplicationSummary>>> applications({
    required ApplicationStatus status,
    String query = '',
  }) => _client.get(
    '$_basePath/list',
    query: {
      'type': status.name,
      if (query.isNotEmpty) 'search': query,
      'page': 1,
    },
    decode: (json) => applicationsFromJson(json, status: status),
  );

  @override
  Future<Result<ApplicationDetails>> details(String id) => _client.get(
    '$_basePath/${Uri.encodeComponent(id)}',
    decode: applicationDetailsFromJson,
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
  Future<Result<ReferenceData>> referenceData({
    Iterable<String> withLgasOf = const [],
  }) async {
    final base = await _places.base();
    if (base case Err(:final failure)) return Err(failure);
    final places = (base as Ok<ApiPlacesBase>).value;
    final lgas = await _places.lgas(withLgasOf);
    if (lgas case Err(:final failure)) return Err(failure);
    // Only places come from the API; the other lists
    // are fixed in the app.
    return Ok(
      ReferenceData(
        typesOfBirth: option_lists.typesOfBirth,
        birthOrders: option_lists.birthOrders,
        sexes: option_lists.sexes,
        placesOfOccurrence: option_lists.placesOfOccurrence,
        localityTypes: formSettlements,
        states: places.states,
        countries: places.countries,
        nationalities: places.nationalities,
        maritalStatuses: option_lists.maritalStatuses,
        ethnicGroups: option_lists.ethnicGroups,
        literacyLevels: option_lists.literacyLevels,
        educationLevels: option_lists.educationLevels,
        occupations: option_lists.occupations,
        relationships: option_lists.relationships,
      ).withLgas((lgas as Ok<Map<String, List<LgaOption>>>).value),
    );
  }

  @override
  Future<RegistrationDraft?> loadDraft() => _drafts.load();

  /// Drafts that never got past the NIN question aren't worth resuming.
  @override
  Future<bool> hasResumableDraft() async =>
      (await loadDraft())?.childHasNin != null;

  @override
  Future<void> saveDraft(RegistrationDraft draft) => _drafts.save(draft);

  @override
  Future<String> keepPhoto(String capturedPath, {String? replacing}) =>
      _files.keepPhoto(capturedPath, replacing: replacing);

  @override
  Future<String> keepSignature(Uint8List png, {String? replacing}) =>
      _files.keepSignature(png, replacing: replacing);

  @override
  Future<String> keepDocument(String pickedPath, {String? replacing}) =>
      _files.keepDocument(pickedPath, replacing: replacing);

  /// Each file goes to storage first, and the registration
  /// carries their keys.
  @override
  Future<Result<String?>> submit(
    RegistrationDraft draft, {
    void Function(int sent, int total)? onProgress,
    Cancellation? cancellation,
  }) async {
    // The registration LGA's code goes into the payload.
    final places = await referenceData(withLgasOf: draft.chosenStates);
    if (places case Err(:final failure)) return Err(failure);
    final uploaded = await _uploadFiles(
      draft,
      onProgress: onProgress,
      cancellation: cancellation,
    );
    if (uploaded case Err(:final failure)) return Err(failure);

    final result = await _client.post(
      '$_basePath/add',
      body: registrationToJson(
        draft,
        places: (places as Ok<ReferenceData>).value,
        uploads: (uploaded as Ok<RegistrationUploads>).value,
      ),
      headers: {'Idempotency-Key': ?draft.submissionKey},
      cancellation: cancellation,
      decode: registrationAddedFromJson,
    );
    if (result is Ok && draft.paymentReference != null) {
      await payments.clearPayment();
    }
    return result;
  }

  @override
  Future<Result<void>> updateQueried(
    RegistrationDraft draft, {
    void Function(int sent, int total)? onProgress,
    Cancellation? cancellation,
  }) async {
    final queried = draft.queried;
    if (queried == null) {
      throw ArgumentError('Not the correction of a queried record.');
    }
    final places = await referenceData(withLgasOf: draft.chosenStates);
    if (places case Err(:final failure)) return Err(failure);
    final uploaded = await _uploadFiles(
      draft,
      onProgress: onProgress,
      cancellation: cancellation,
    );
    if (uploaded case Err(:final failure)) return Err(failure);
    return _client.patch(
      '$_basePath/update',
      body: registrationUpdateToJson(
        draft,
        queried: queried,
        places: (places as Ok<ReferenceData>).value,
        uploads: (uploaded as Ok<RegistrationUploads>).value,
      ),
      cancellation: cancellation,
      decode: (_) {},
    );
  }

  /// Uploads the draft's files (names carry no personal data). Files still
  /// in storage are sent by key.
  Future<Result<RegistrationUploads>> _uploadFiles(
    RegistrationDraft draft, {
    void Function(int done, int total)? onProgress,
    Cancellation? cancellation,
  }) async {
    final tag =
        draft.submissionKey ?? '${draft.startedOn.millisecondsSinceEpoch}';
    final informant = draft.informant;
    final identity = switch (informant.identityMode) {
      IdentityMode.signature => informant[InformantField.signature],
      IdentityMode.face => informant[InformantField.facePhoto],
    };
    final childFace = draft.child[ChildField.facePhoto];
    final documents = {
      for (final type in draft.documentTypes) type: ?draft.documents[type],
    };
    final total = [
      childFace,
      identity,
      for (final file in documents.values) file.path,
    ].where((path) => path != null && !isOnServer(path)).length;
    var done = 0;
    Future<Result<String?>> send(String? path, String name) async {
      if (path == null) return const Ok(null);
      if (isOnServer(path)) return Ok(serverKeyOf(path));
      final result = await _upload(
        path,
        name: '$name-$tag${_extension(path)}',
        cancellation: cancellation,
      );
      if (result is Ok) onProgress?.call(++done, total);
      return result;
    }

    final face = await send(childFace, 'BR-CHILD-FACE');
    if (face case Err(:final failure)) return Err(failure);
    final signed = await send(identity, 'BR-INFORMANT-IDENTITY');
    if (signed case Err(:final failure)) return Err(failure);
    final keys = <DocumentType, String>{};
    for (final MapEntry(key: type, value: file) in documents.entries) {
      switch (await send(file.path, 'BR-SUPPORT-DOC-${type.apiType}')) {
        case Ok(value: final key?):
          keys[type] = key;
        case Ok():
          break;
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Ok((
      childFace: (face as Ok<String?>).value,
      informantIdentity: (signed as Ok<String?>).value,
      documents: keys,
    ));
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

  @override
  Future<void> deleteFile(String path) => _files.delete(path);

  @override
  Future<void> discardDraft() => _drafts.discard();
}
