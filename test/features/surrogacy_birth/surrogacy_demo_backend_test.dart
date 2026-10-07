import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/data/surrogacy_birth_repository_impl.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_form.dart';

import '../../helpers/fakes.dart';
import 'fake_surrogacy_birth_repository.dart';

/// The real repository against the demo backend, recording request paths.
(SurrogacyBirthRepositoryImpl, List<String>) _demo() {
  final paths = <String>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
    ..interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) {
          paths.add('${options.method} ${options.path}');
          handler.next(options);
        },
      ),
      FakeBackendInterceptor(latency: Duration.zero),
    ]);
  final repository = SurrogacyBirthRepositoryImpl(
    client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
    storage: signedInUserStorage(),
  );
  return (repository, paths);
}

T _ok<T>(Result<T> result) => (result as Ok<T>).value;

void main() {
  test('reads applications on the API paths', () async {
    final (repository, paths) = _demo();
    final counts = _ok(await repository.counts());
    final queried = _ok(
      await repository.applications(status: ApplicationStatus.queried),
    );
    expect(counts.of(ApplicationStatus.printed), 4);
    expect(queried.single.status, ApplicationStatus.queried);
    expect(queried.single.trackingId, startsWith('SBR-'));
    expect(paths, [
      'GET /surrogacy-birth-registration/stats',
      'GET /surrogacy-birth-registration',
    ]);
  });

  test(
    'starts an application, records the NIN, payment and a section',
    () async {
      final (repository, paths) = _demo();
      final referenceId = _ok(await repository.initiate());
      expect(referenceId, matches(RegExp(r'^SBR-\d{4}-\d{7}$')));

      final record = _ok(await repository.lookupNin('12345678901'));
      expect(record.surname, isNotEmpty);
      _ok(
        await repository.verifyChildNin(
          referenceId: referenceId,
          nin: '12345678901',
        ),
      );
      _ok(await repository.skipChildNin(referenceId));
      _ok(
        await repository.attachPayment(
          referenceId: referenceId,
          reference: 'PAIDDEMO',
        ),
      );
      // A state's LGAs once it is chosen; centres by
      // their LGA.
      final data = _ok(await repository.referenceData(withLgasOf: ['25']));
      expect(data.arrangementTypes, hasLength(2));
      final lga = data.lgasOf('25').first.id;
      expect(data.centersOf('25', lga), isNotEmpty);

      final dir = await Directory.systemTemp.createTemp('surrogacy');
      addTearDown(() => dir.delete(recursive: true));
      final face = File('${dir.path}/face.jpg')..writeAsBytesSync([1, 2, 3]);
      final draft = paidDraft().copyWith(
        child: completeChild().set(ChildField.facePhoto, face.path),
      );
      final saved = _ok(
        await repository.saveSection(draft, SurrogacySection.child),
      );
      expect(saved.uploads[face.path], isNotNull);

      // Saving again doesn't upload the photo again.
      paths.clear();
      _ok(await repository.saveSection(saved, SurrogacySection.child));
      expect(paths, [
        'PATCH /surrogacy-birth-registration/SBR-2026-0004821/section',
      ]);
    },
  );
}
