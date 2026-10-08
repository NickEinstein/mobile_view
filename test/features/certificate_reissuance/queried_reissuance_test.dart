import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/face_verifier.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/data/reissuance_repository_impl.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/birth_form/cubit/birth_reissuance_form_cubit.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/details/view/reissuance_details_page.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/home/view/reissuance_home_page.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_reissuance_repository.dart';

T _ok<T>(Result<T> result) => (result as Ok<T>).value;

/// The real repository against the demo backend, recording requests.
(ReissuanceRepositoryImpl, List<(String, String, Object?)>) _demo() {
  final requests = <(String, String, Object?)>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
    ..interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add((options.method, options.path, options.data));
          handler.next(options);
        },
      ),
      FakeBackendInterceptor(latency: Duration.zero),
    ]);
  return (
    ReissuanceRepositoryImpl(
      client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
      storage: signedInUserStorage(),
      faces: FaceVerifier(
        client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
        url: demoFaceUrl,
      ),
    ),
    requests,
  );
}

void main() {
  group('the demo backend, in the API shapes', () {
    test('reads a queried request as the API sends it', () async {
      final (repository, requests) = _demo();
      final record = _ok(await repository.birthRecord('4103'));

      expect(
        requests.single.$2,
        '/certificate-reissuance-assisted/single-birth-reg/4103',
      );
      expect(record.status, ReissuanceStatus.queried);
      expect(record.reference, 'BRTFA30087680');
      expect(record.query?.title, 'Age mismatch');
      expect(record.query?.reason, contains("mother's age"));
      expect(record.certificateKey, 'reissuance/cert-3.jpg');
      expect(record.faceKey, 'reissuance/face-3.jpg');
      expect(record.issuedOn, DateTime(2010, 3, 1));
      final form = record.form;
      expect(form.step, BirthReissuanceStep.review);
      expect(form.child[ChildField.surname], 'Garba');
      expect(form.child[ChildField.registrationState], '1');
      expect(form.child[ChildField.registrationLga], '11');
      expect(form.child[ChildField.registrationCenter], '110');
      expect(form.child.dateOfBirth, DateTime(2016, 3, 12));
      expect(form.mother[ParentDetail.maidenName], 'Bello');
      expect(form.father[ParentDetail.age], '34');
      expect(form.keptSignature?.key, 'reissuance/sign-3.png');
      expect(form.keptDocument?.key, 'reissuance/doc-3.png');
      expect(form.isComplete(BirthReissuanceStep.review), isTrue);
    });

    test('an unknown request is not found', () async {
      final (repository, _) = _demo();
      expect(
        await repository.birthRecord('1'),
        isA<Err<BirthReissuanceRecord>>(),
      );
    });

    test(
      'a correction is resent with its id, reference and kept files',
      () async {
        final (repository, requests) = _demo();
        final record = _ok(await repository.birthRecord('4103'));
        requests.clear();

        final result = await repository.updateBirth(
          record,
          record.form,
          email: 'p@mail.com',
        );

        expect(result, const Ok<String?>('Record updated successfully.'));
        // Nothing new to upload.
        expect(requests.single.$1, 'PATCH');
        expect(
          requests.single.$2,
          '/certificate-reissuance-assisted/update-birth-reg',
        );
        final body = requests.single.$3! as Map<String, Object?>;
        expect(body['id'], 4103);
        expect(body['paymentReference'], 'BRTFA30087680');
        expect(body['legacyCertLink'], 'reissuance/cert-3.jpg');
        expect(body['childFace'], 'reissuance/face-3.jpg');
        expect(body['signature'], 'reissuance/sign-3.png');
        expect(body['supportingDocument'], [
          {
            'type': 'support-document',
            'file': 'reissuance/doc-3.png',
            'mimeType': 'image/png',
          },
        ]);
        expect(body['email'], 'p@mail.com');
      },
    );

    test('a new signature is uploaded and replaces the kept one', () async {
      final (repository, requests) = _demo();
      final record = _ok(await repository.birthRecord('4103'));
      final dir = await Directory.systemTemp.createTemp('queried');
      addTearDown(() => dir.delete(recursive: true));
      final signature = File('${dir.path}/sign.png')..writeAsBytesSync([1]);
      requests.clear();

      await repository.updateBirth(
        record,
        record.form.copyWith(
          signature: () => signature.path,
          keptSignature: () => null,
        ),
        email: 'p@mail.com',
      );

      final body = requests.last.$3! as Map<String, Object?>;
      expect(
        requests.where((r) => r.$2.startsWith('/file-upload-url/')),
        hasLength(1),
      );
      expect(
        body['signature'],
        startsWith('modifications/REISSUANCE-SIGNATURE'),
      );
      // Sent: the new file isn't kept on the device.
      expect(signature.existsSync(), isFalse);
    });

    test('downloads the certificate by reference, per kind', () async {
      final (repository, requests) = _demo();
      final birth = _ok(
        await repository.download(ReissuanceKind.birth, 'BRT1'),
      );
      await repository.download(ReissuanceKind.attestation, 'BRT2');

      expect(birth.sublist(1, 4), 'PNG'.codeUnits);
      expect(
        [for (final r in requests) r.$2],
        [
          '/birth-registration/selfservice/print/BRT1',
          '/self-attestation/print/BRT2',
        ],
      );
    });
  });

  group('correcting a queried request', () {
    late FakeReissuanceRepository repository;
    setUp(() => repository = FakeReissuanceRepository());

    BirthReissuanceFormCubit build() =>
        BirthReissuanceFormCubit(repository, queriedId: '4103');

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      'opens at the preview, with the sex locked; changes stay in memory',
      build: build,
      act: (cubit) async {
        await cubit.load();
        expect(cubit.state.step, BirthReissuanceStep.review);
        expect(cubit.state.isQueried, isTrue);
        expect(cubit.state.sexLocked, isTrue);
        expect(cubit.state.certificate?.number, 'CR1');
        cubit
          ..editStep(BirthReissuanceStep.mother)
          ..parentChanged(ParentRole.mother, ParentDetail.age, '31')
          ..next();
        await cubit.flush();
      },
      verify: (cubit) {
        expect(cubit.state.step, BirthReissuanceStep.review);
        expect(cubit.state.form?.mother[ParentDetail.age], '31');
        expect(repository.draft, isNull, reason: 'nothing saved on device');
      },
    );

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      'the signature sent with it counts until cleared',
      build: build,
      act: (cubit) async {
        await cubit.load();
        expect(
          cubit.state.form?.isComplete(BirthReissuanceStep.documents),
          isTrue,
        );
        await cubit.signatureCleared();
      },
      verify: (cubit) {
        expect(cubit.state.form?.hasSignature, isFalse);
        expect(cubit.state.canSubmit, isFalse);
        expect(repository.deleted, isEmpty, reason: 'nothing local to delete');
      },
    );

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      'Submit resends it, with no new payment',
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.submit(email: 'parent@mail.com');
      },
      verify: (cubit) {
        expect(cubit.state.submitStatus, SubmitStatus.submitted);
        expect(repository.submitted, isEmpty);
        final (record, form, email) = repository.updated.single;
        expect(record.id, '4103');
        expect(form.keptSignature?.key, 'sign-key');
        expect(email, 'parent@mail.com');
      },
    );

    test('a new signature left unsent is deleted on leaving', () async {
      final cubit = build();
      await cubit.load();
      await cubit.signatureDrawn(Uint8List(4));
      await cubit.close();

      expect(repository.deleted, ['signature-1.png']);
    });
  });

  group('Certificate Details', () {
    Future<(FakeReissuanceRepository, List<String>)> pumpDetails(
      WidgetTester tester, {
      BirthReissuanceRecord? record,
    }) async {
      tester.view
        ..physicalSize = const Size(400, 5000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = FakeReissuanceRepository();
      if (record != null) repository.recordResult = Ok(record);
      final updates = <String>[];
      await tester.pumpApp(
        ReissuanceDetailsPage(
          kind: ReissuanceKind.birth,
          id: '4103',
          repository: repository,
          onUpdate: () => updates.add('update'),
        ),
      );
      await tester.pumpAndSettle();
      return (repository, updates);
    }

    testWidgets('a queried request shows why, everything sent, and Update', (
      tester,
    ) async {
      final (_, updates) = await pumpDetails(tester);

      expect(find.text('Certificate Details'), findsWidgets);
      expect(find.text('Queried'), findsOneWidget);
      expect(find.text('Wrong age'), findsOneWidget);
      expect(
        find.text("Reason: The mother's age doesn't match the record."),
        findsOneWidget,
      );
      expect(find.text('Bogoro PHC'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Download'), findsNothing);

      await tester.tap(find.text('Update'));
      expect(updates, ['update']);
    });

    testWidgets('an approved one can be downloaded', (tester) async {
      final approved = BirthReissuanceRecord(
        id: queriedRecord.id,
        status: ReissuanceStatus.approved,
        reference: 'BRT4',
        nin: queriedRecord.nin,
        certificateNumber: 'CR1',
        issuedOn: queriedRecord.issuedOn,
        certificateKey: 'cert-key',
        form: queriedRecord.form,
      );
      final (repository, _) = await pumpDetails(tester, record: approved);

      expect(find.text('Update'), findsNothing);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      expect(repository.downloads, [(ReissuanceKind.birth, 'BRT4')]);
      expect(find.text('Reissued certificate'), findsOneWidget);
    });
  });

  testWidgets('home: a request opens its details; ⋮ offers Update', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(400, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = FakeReissuanceRepository()
      ..requestsResult = const Ok([
        ReissuanceSummary(
          id: '7',
          name: 'Garba Amina',
          reference: 'BRT7',
          status: ReissuanceStatus.queried,
        ),
      ]);
    final opened = <String>[];
    await tester.pumpApp(
      ReissuanceHomePage(
        repository: repository,
        onStart: () async {},
        onResume: (_) async {},
        onOpenDetails: (kind, id) async => opened.add('details $id'),
        onUpdate: (kind, id) async => opened.add('update $id'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Garba Amina'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsNothing);
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(opened, ['details 7', 'update 7']);
  });
}
