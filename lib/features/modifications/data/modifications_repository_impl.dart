import 'dart:io';

import 'package:dio/dio.dart' show Headers;
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/storage/draft_files.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/modifications/data/dtos/modification_dtos.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_submission.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_summary.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/queried_modification.dart';
import 'package:vital_reg_mobile/features/modifications/domain/modifications_repository.dart';
import 'package:vital_reg_mobile/features/payments/data/gateway_payments.dart';
import 'package:vital_reg_mobile/features/payments/domain/payment_source.dart';

/// The backend's modification endpoints.
class ModificationsRepositoryImpl implements ModificationsRepository {
  ModificationsRepositoryImpl({
    required ApiClient client,
    required UserStorage storage,
  }) : _client = client,
       _storage = storage;

  final ApiClient _client;
  final UserStorage _storage;
  DraftFiles get _files => _storage.files;

  @override
  Future<Result<int>> count(ModificationKind kind) =>
      _client.get('/modification/${kind.apiPath}/stats', decode: countFromJson);

  @override
  Future<Result<List<ModificationSummary>>> requests({
    required ModificationKind kind,
    required ModificationStatus status,
    String query = '',
  }) => _client.get(
    '/modification/${kind.apiPath}/list',
    query: {
      'type': status.name,
      'page': 1,
      if (query.isNotEmpty) 'search': query,
    },
    decode: (json) => requestsFromJson(json, kind: kind, status: status),
  );

  @override
  PaymentSource payments(ModificationRequest request) => GatewayPayments(
    client: _client,
    storage: _storage,
    type: request.paymentType,
    description: request.kind.paymentDescription,
  );

  @override
  Future<Result<ModificationRecord>> findRecord(
    ModificationKind kind,
    String certificateNumber,
  ) async {
    final result = await _client.get(
      '/modification/${kind.apiPath}/cert/'
      '${Uri.encodeComponent(certificateNumber)}',
      decode: (json) => recordFromJson(
        json,
        kind: kind,
        certificateNumber: certificateNumber,
      ),
    );
    return switch (result) {
      Ok(value: final record?) => Ok(record),
      Ok() => const Err(NotFoundFailure()),
      Err(:final failure) => Err(failure),
    };
  }

  /// Nigeria's id.
  static const _nigeria = '63';

  /// Options rarely change; load each list once per app run.
  List<Option>? _states;
  final Map<String, List<Option>> _lgas = {};

  @override
  Future<Result<List<Option>>> states() async {
    final cached = _states;
    if (cached != null) return Ok(cached);
    final result = await _client.get(
      '/option/states/$_nigeria',
      decode: statesFromJson,
    );
    if (result case Ok(:final value)) _states = value;
    return result;
  }

  @override
  Future<Result<List<Option>>> lgas(String stateId) async {
    final cached = _lgas[stateId];
    if (cached != null) return Ok(cached);
    final result = await _client.get(
      '/option/lga/${Uri.encodeComponent(stateId)}',
      decode: lgasFromJson,
    );
    if (result case Ok(:final value)) _lgas[stateId] = value;
    return result;
  }

  @override
  Future<String> keepDocument(String pickedPath, {String? replacing}) =>
      _files.keepDocument(pickedPath, replacing: replacing);

  @override
  Future<void> deleteFile(String path) => _files.delete(path);

  @override
  Future<Result<String?>> submit(ModificationSubmission submission) async {
    final uploaded = <UploadedDocument>[];
    for (final MapEntry(key: type, value: file)
        in submission.documents.files.entries) {
      final result = await _upload(
        file,
        name: 'MOD-${type.apiValue}-${submission.edit.record.recordId}',
      );
      switch (result) {
        case Ok(value: final key):
          uploaded.add((
            type: type.apiValue,
            key: key,
            mimeType: _mimeType(file.name),
          ));
        case Err(:final failure):
          return Err(failure);
      }
    }
    final path = '/modification/${submission.request.kind.apiPath}';
    final body = submissionToJson(submission, documents: uploaded);
    return submission.modificationId == null
        ? _client.post(path, body: body, decode: messageFromJson)
        : _client.patch(path, body: body, decode: messageFromJson);
  }

  @override
  Future<Result<QueriedModification>> queried(
    ModificationKind kind,
    String id,
  ) async {
    final result = await _client.get(
      '/modification/${kind.apiPath}/single/${Uri.encodeComponent(id)}',
      decode: (json) => queriedFromJson(json, kind: kind),
    );
    return switch (result) {
      Ok(value: final queried?) => Ok(queried),
      Ok() => const Err(
        UnexpectedFailure('This request can only be answered on the web.'),
      ),
      Err(:final failure) => Err(failure),
    };
  }

  /// Asks for a storage URL, then puts the file
  /// there. Returns the stored file's key.
  Future<Result<String>> _upload(
    AttachedFile file, {
    required String name,
  }) async {
    final target = await _client.get(
      '/file-upload-url/${Uri.encodeComponent(name)}',
      decode: uploadUrlFromJson,
    );
    if (target case Err(:final failure)) return Err(failure);
    final (:url, :key) = (target as Ok<({Uri url, String key})>).value;
    final bytes = await File(file.path).readAsBytes();
    final put = await _client.put(
      url.toString(),
      // Storage authorises by the URL; our token must not go there.
      authenticated: false,
      headers: {
        Headers.contentTypeHeader: _mimeType(file.name),
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

  static String _mimeType(String name) =>
      name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
}
