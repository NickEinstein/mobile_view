import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/birth_attestation_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/face_verifier.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/cubit/applications_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/view/birth_registration_home_page.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_birth_attestation_repository.dart';

/// The real repository against the demo backend, recording request paths.
/// The last JSON body sent to each path by a [_demo] repository.
final _sentBodies = <String, Object?>{};

(BirthAttestationRepositoryImpl, List<String>) _demo() {
  final paths = <String>[];
  _sentBodies.clear();
  final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
    ..interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) {
          paths.add('${options.method} ${options.path}');
          if (options.data is Map) _sentBodies[options.path] = options.data;
          handler.next(options);
        },
      ),
      FakeBackendInterceptor(latency: Duration.zero),
    ]);
  final client = ApiClient(dio, LoggingCrashReporter(AppLogger()));
  final repository = BirthAttestationRepositoryImpl(
    client: client,
    storage: signedInUserStorage(),
    faces: FaceVerifier(client: client, url: demoFaceUrl),
  );
  return (repository, paths);
}

T _ok<T>(Result<T> result) => (result as Ok<T>).value;

void main() {
  test('faces are matched by the face service', () async {
    final (repository, paths) = _demo();
    final dir = await Directory.systemTemp.createTemp('face');
    addTearDown(() => dir.delete(recursive: true));
    final face = File('${dir.path}/face.jpg')..writeAsBytesSync([1, 2, 3]);

    // Straight after a restart: the NIN photo is fetched again first.
    final matched = _ok(
      await repository.matchFace(face.path, nin: '12345678901'),
    );

    expect(matched, isTrue);
    expect(paths, ['GET /verify-nin/12345678901', 'POST $demoFaceUrl']);
    final body = _sentBodies[demoFaceUrl]! as Map;
    expect(body['level'], 'HIGH');
    expect((body['image'] as Map)['template'], startsWith('/9j/'));
    expect((body['imageToVerifyAgainst'] as Map)['template'], 'AQID');
  });

  test('reads attestation records on the API paths', () async {
    final (repository, paths) = _demo();

    final counts = _ok(await repository.counts());
    final list = _ok(
      await repository.applications(status: ApplicationStatus.approved),
    );

    expect(paths, [
      'GET /birth-attestation/stats/self',
      'GET /birth-attestation/list',
    ]);
    expect(counts.of(ApplicationStatus.approved), 3);
    expect(counts.of(ApplicationStatus.printed), 4);
    // Rows open by attestation number.
    expect(list.first.id, list.first.trackingId);
    expect(list.first.childName, 'Lee Michael');

    final record = _ok(await repository.details(list.first.id));
    expect(record.summary.trackingId, list.first.trackingId);
    expect(record.summary.status, ApplicationStatus.approved);
    expect(record.applicant[ApplicantField.stateOfOrigin], '15');
    expect(record.additional[AdditionalField.educationLevel], '7');
    expect(record.father[ParentInfoField.nationality], '63');
  });

  test('the demo backend takes a payment through to verified', () async {
    final (repository, paths) = _demo();

    final quote = _ok(await repository.payments.quote());
    expect(
      _ok(await repository.payments.sendPaymentOtp('payer@mail.com')),
      isTrue,
    );
    expect(
      await repository.payments.confirmPaymentOtp(
        email: 'payer@mail.com',
        code: '1',
      ),
      isA<Err<void>>(),
    );
    expect(
      await repository.payments.confirmPaymentOtp(
        email: 'payer@mail.com',
        code: FakeBackendInterceptor.demoPaymentOtp,
      ),
      isA<Ok<void>>(),
    );
    final session = _ok(
      await repository.payments.startPayment('payer@mail.com'),
    );
    // The gateway's own check.
    final before = _ok(
      await repository.payments.verifyPayment(
        session.reference,
        gateway: session.gateway,
      ),
    );
    FakeBackendInterceptor.paidReferences.add(session.reference);
    final after = _ok(
      await repository.payments.verifyPayment(
        session.reference,
        gateway: session.gateway,
      ),
    );
    // A typed-in reference is only looked up.
    final typed = _ok(
      await repository.payments.verifyPayment(session.reference),
    );

    expect(quote.total, 210000);
    expect(quote.currency, 'NGN');
    expect(session.checkoutUrl.scheme, 'https');
    expect(session.gateway, 'alatpay');
    expect(before, PaymentStatus.pending);
    expect(after, PaymentStatus.paid);
    expect(typed, PaymentStatus.paid);
    expect(paths, contains('POST /payments/initiate'));
    expect(paths.where((p) => p == 'POST /payments/alat/verify'), hasLength(2));
    expect(paths.last, 'GET /payments/verify');
  });

  test('an email that cannot receive mail gets no code', () async {
    final (repository, paths) = _demo();
    expect(
      _ok(await repository.payments.sendPaymentOtp('invalid@mail.com')),
      isFalse,
    );
    expect(paths, isNot(contains('POST /validation/send-otp')));
  });

  test('reads a NIN record from the identity service', () async {
    final (repository, _) = _demo();

    final adult = _ok(await repository.verifyNin('12345678901'));
    final child = _ok(await repository.verifyNin('11111111111'));
    final none = await repository.verifyNin('00000000000');

    expect(adult.surname, 'Ogunlade');
    expect(adult.dateOfBirth, DateTime(1990, 6, 14));
    expect(adult.sex, Sex.male);
    expect(adult.stateOfOrigin, 'Bauchi');
    expect(adult.isAdultOn(DateTime(2026, 10, 3)), isTrue);
    expect(child.isAdultOn(DateTime(2026, 10, 3)), isFalse);
    expect(none, const Err<ApplicantNinRecord>(NotFoundFailure()));
  });

  test(
    'the demo backend serves the form lists and takes submissions',
    () async {
      final (repository, paths) = _demo();
      // Only places from the API, LGAs per state.
      final base = _ok(await repository.referenceData());
      expect(
        base.identityTypes.first,
        const Option('1', 'Immigration Document'),
      );
      final state = base.states.first.option;
      expect(base.stateIdNamed(state.label.toUpperCase()), state.id);
      expect(base.lgasOf(state.id), isEmpty);
      final data = _ok(await repository.referenceData(withLgasOf: [state.id]));
      final lga = data.lgasOf(state.id).first;
      expect(data.lgaIdNamed(state.id, lga.label), lga.id);
      expect(paths.where((p) => p.startsWith('GET /')), [
        'GET /option/country',
        'GET /option/states/63',
        'GET /option/registration-centres',
        'GET /option/lga/${state.id}',
      ]);

      final dir = await Directory.systemTemp.createTemp('attestation');
      addTearDown(() => dir.delete(recursive: true));
      final face = File('${dir.path}/face.jpg')..writeAsBytesSync([1, 2, 3]);
      final record = _ok(await repository.verifyNin('12345678901'));
      final withNin = AttestationDraft(
        startedOn: DateTime(2026, 10, 3),
        hasNin: true,
        ninRecord: record,
        facePhoto: face.path,
      );
      final withoutNin = AttestationDraft(
        startedOn: DateTime(2026, 10, 3),
        hasNin: false,
        facePhoto: face.path,
      );

      final first = _ok(
        await repository.submit(withNin, paymentReference: 'REF1'),
      );
      final second = _ok(
        await repository.submit(withoutNin, paymentReference: 'REF2'),
      );

      // Each answer's own number field.
      expect(first, isNotEmpty);
      expect(second, isNotEmpty);
      // Files go to storage first; the applications carry their keys,
      // with each endpoint's own field names.
      expect(paths.where((p) => p.contains('/file-upload-url/')), hasLength(2));
      final add = _sentBodies['/birth-attestation/add']! as Map;
      expect(add['reference'], 'REF1');
      expect(add['face'], startsWith('modifications/BA-APPLICANT-FACE-'));
      expect(add['country_of_birth'], 63);
      expect(add['nin'], '12345678901');
      expect(add.containsKey('state_code'), isTrue);
      final noNin = _sentBodies['/self-attestation/no-nin']! as Map;
      expect(noNin['payment_reference'], 'REF2');
      expect(noNin.containsKey('State_Code'), isTrue);
      expect(noNin['nin'], isNull);
      expect(paths, contains('POST /birth-attestation/add'));
      expect(paths, contains('POST /self-attestation/no-nin'));
    },
  );

  testWidgets('the home is titled Birth Attestation and starts a new one', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 2000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var started = 0;

    await tester.pumpApp(
      BlocProvider(
        create: (_) =>
            ApplicationsCubit(FakeBirthAttestationRepository())
              ..load().ignore(),
        child: BirthRegistrationHomeView(
          title: 'Birth Attestation',
          onStartApplication: () async => started++,
          onResumeApplication: () async {},
          onOpenApplication: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Birth Attestation'), findsOneWidget);
    expect(find.text('Birth Registration'), findsNothing);
    await tester.tap(find.byTooltip('New application'));
    await tester.pumpAndSettle();
    expect(started, 1);
  });
}
