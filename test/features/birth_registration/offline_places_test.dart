import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/offline/offline_mode.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/core/session/user_scope.dart';
import 'package:vital_reg_mobile/core/storage/user_storage.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/birth_registration_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/saved_places.dart';

import '../../helpers/demo_backend.dart';
import '../../helpers/fakes.dart';

/// An [ApiClient] with no connection; [paths] records each attempt.
({ApiClient client, List<String> paths}) _noConnection() {
  final paths = <String>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          paths.add('${options.method} ${options.path}');
          handler.reject(
            DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            ),
          );
        },
      ),
    );
  return (
    client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
    paths: paths,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late SavedPlaces saved;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('saved_places_test');
    saved = SavedPlaces(root: () async => root);
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('SavedPlaces', () {
    test('keeps what it saves', () async {
      await saved.save('/option/registration-centres', [
        {'Reg_Center_id': 1, 'Reg_Center_Name': 'Ikeja', 'LGA_ID': 249},
      ]);
      expect(await saved.read('/option/registration-centres'), [
        {'Reg_Center_id': 1, 'Reg_Center_Name': 'Ikeja', 'LGA_ID': 249},
      ]);
    });

    test('falls back to the bundled lists, but has no centres', () async {
      final countries = await saved.read('/option/country') as List<Object?>;
      final states = await saved.read('/option/states/63') as List<Object?>;
      final lgas = await saved.read('/option/lga/25') as List<Object?>;

      expect(countries, contains(containsPair('Country_Code', 63)));
      expect(states, hasLength(37));
      expect(lgas, isNotEmpty);
      expect(lgas, everyElement(containsPair('State_ID', 25)));
      expect(await saved.read('/option/registration-centres'), isNull);
    });
  });

  group('places offline', () {
    test('online answers are saved for later', () async {
      final backend = demoBackend();
      final online = BirthRegistrationRepositoryImpl(
        client: backend.client,
        storage: signedInUserStorage(),
        savedPlaces: saved,
      );
      final places = ok(await online.referenceData());
      final state = places.states.first.option.id;
      await online.referenceData(withLgasOf: [state]);
      // Saving doesn't hold up the answer.
      await pumpEventQueue();

      final offline = _noConnection();
      final later = BirthRegistrationRepositoryImpl(
        client: offline.client,
        storage: signedInUserStorage(),
        savedPlaces: saved,
      );
      final reloaded = ok(await later.referenceData(withLgasOf: [state]));

      expect(
        reloaded.states.map((s) => s.option),
        places.states.map((s) => s.option),
      );
      expect(reloaded.lgasOf(state), isNotEmpty);
    });

    test('in offline mode the API is never asked', () async {
      await saved.save('/option/registration-centres', const <Object?>[]);
      final storage = signedInUserStorage();
      final mode = OfflineMode(storage);
      await mode.turn(on: true);
      final backend = _noConnection();
      final repository = BirthRegistrationRepositoryImpl(
        client: backend.client,
        storage: storage,
        savedPlaces: saved,
        offlineMode: mode,
      );

      final places = ok(await repository.referenceData(withLgasOf: ['25']));

      expect(backend.paths, isEmpty);
      expect(places.states, hasLength(37));
      expect(places.lgasOf('25'), isNotEmpty);
    });

    test('without saved centres there is nothing to register at', () async {
      final repository = BirthRegistrationRepositoryImpl(
        client: _noConnection().client,
        storage: signedInUserStorage(),
        savedPlaces: saved,
      );

      final result = await repository.referenceData();

      expect(result, isA<Err<Object?>>());
      expect((result as Err).failure, const NetworkFailure());
    });
  });

  group('OfflineMode', () {
    test("is each user's own and survives a restart", () async {
      final ada = UserScope()..enter('ada');
      await OfflineMode(
        UserStorage(const FlutterSecureStorage(), ada),
      ).turn(on: true);

      final restarted = OfflineMode(
        UserStorage(const FlutterSecureStorage(), ada),
      );
      expect(restarted.isOn, isFalse);
      expect(await restarted.load(), isTrue);
      expect(restarted.isOn, isTrue);

      ada.enter('bola');
      expect(restarted.isOn, isFalse);
      expect(await restarted.load(), isFalse);
    });
  });
}
