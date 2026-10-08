import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/face_verifier.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/data/dtos/reissuance_dtos.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/data/reissuance_repository_impl.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/birth_form/cubit/birth_reissuance_form_cubit.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/birth_form/view/birth_reissuance_form_page.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/email_code.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_reissuance_repository.dart';

final _child = const ChildParticulars()
    .set(ChildField.surname, 'Ogunlade')
    .set(ChildField.firstName, 'Bolaji')
    .set(ChildField.dateOfBirth, DateTime(2016, 3, 12).toIso8601String())
    .set(ChildField.typeOfBirth, '1')
    .set(ChildField.birthOrder, '2')
    .set(ChildField.sex, '1')
    .set(ChildField.placeOfOccurrence, '1')
    .set(ChildField.stateOfBirth, '5')
    .set(ChildField.lgaOfBirth, '51')
    .set(ChildField.townOfBirth, 'Bogoro')
    .set(ChildField.locality, '2')
    .set(ChildField.registrationState, '5')
    .set(ChildField.registrationLga, '51')
    .set(ChildField.registrationCenter, '510');

ParentParticulars _parent({bool mother = true}) {
  var parent = const ParentParticulars()
      .set(ParentDetail.surname, 'Ogunlade')
      .set(ParentDetail.firstName, mother ? 'Amina' : 'Musa')
      .set(ParentDetail.country, '31')
      .set(ParentDetail.state, '901')
      .set(ParentDetail.address, 'No 2 Agwada Str')
      .set(ParentDetail.age, '30')
      .set(ParentDetail.maritalStatus, '1')
      .set(ParentDetail.nationality, '63')
      .set(ParentDetail.stateOfOrigin, '5')
      .set(ParentDetail.lgaOfOrigin, '51')
      .set(ParentDetail.ethnicGroup, '4')
      .set(ParentDetail.literacy, '2')
      .set(ParentDetail.occupation, '3')
      .set(ParentDetail.phone, '08130845852');
  if (mother) parent = parent.set(ParentDetail.maidenName, 'Alice');
  return parent;
}

ReissuanceDraft _draft({
  BirthReissuanceStep step = BirthReissuanceStep.review,
  String? signature = 'sign.png',
  AttachedFile? document,
  String face = 'face.jpg',
  String certificate = 'old.jpg',
}) => ReissuanceDraft(
  startedOn: DateTime(2026, 10, 4),
  mode: ValidationMode.nin,
  ninRecord: ninRecord,
  facePhoto: face,
  certificate: LegacyCertificate(
    kind: ReissuanceKind.birth,
    number: 'CR603/2609-15',
    issuedOn: DateTime(2010, 3, 1),
    filePath: certificate,
    fileName: 'old.jpg',
    sizeBytes: 10,
  ),
  birthForm: BirthReissuanceForm(
    step: step,
    child: _child,
    mother: _parent(),
    father: _parent(mother: false),
    document: document,
    signature: signature,
  ),
);

void main() {
  test('the request goes in the API\'s field names and number ids', () {
    final draft = _draft();
    final json = birthReissuanceToJson(
      (
        kind: ReissuanceKind.birth,
        number: draft.certificate!.number,
        issuedOn: draft.certificate!.issuedOn,
        nin: ninRecord.nin,
      ),
      draft.birthForm!,
      files: (
        certificate: 'cert-key',
        face: 'face-key',
        signature: 'sign-key',
        document: (key: 'doc-key', mimeType: 'image/png'),
      ),
      paymentReference: 'BRT1',
      email: 'parent@mail.com',
      today: DateTime(2026, 3, 11),
    );

    expect(json, containsPair('certType', 'birth_reissuance'));
    expect(json, containsPair('nin', ninRecord.nin));
    expect(json, containsPair('paymentReference', 'BRT1'));
    expect(json, containsPair('legacyCertNumber', 'CR603/2609-15'));
    expect(json, containsPair('legacyCertLink', 'cert-key'));
    expect(json, containsPair('legacyCertIssuedDate', '2010-03-01'));
    expect(json, containsPair('dateOfBirth', '2016-03-12'));
    // The day before the birthday: still 9.
    expect(json, containsPair('childAge', 9));
    expect(json, containsPair('childFace', 'face-key'));
    expect(json, containsPair('childMiddleName', null));
    expect(json, containsPair('childSex', 1));
    expect(json, containsPair('birthOrder', 2));
    expect(json, containsPair('localityOfBirth', 2));
    expect(json, containsPair('townOfBirth', 'Bogoro'));
    expect(json, containsPair('motherMaidenName', 'Alice'));
    expect(json, containsPair('motherCountryOfResidence', 31));
    expect(json, containsPair('motherLgaOfResidence', null));
    expect(json, containsPair('motherEducationLevel', null));
    expect(json, containsPair('fatherFirstName', 'Musa'));
    expect(json, containsPair('fatherOriginLga', 51));
    expect(json.containsKey('fatherMaidenName'), isFalse);
    expect(json, containsPair('regCenter', 510));
    expect(json, containsPair('signature', 'sign-key'));
    expect(json, containsPair('email', 'parent@mail.com'));
    expect(json['supportingDocument'], [
      {'type': 'support-document', 'file': 'doc-key', 'mimeType': 'image/png'},
    ]);
  });

  group('BirthReissuanceFormCubit', () {
    late FakeReissuanceRepository repository;
    setUp(() => repository = FakeReissuanceRepository());

    BirthReissuanceFormCubit build() => BirthReissuanceFormCubit(repository);

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      "supporting documents need the parent's signature; the document is "
      'optional',
      setUp: () => repository.draft = _draft(
        step: BirthReissuanceStep.documents,
        signature: null,
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.next();
        expect(cubit.state.showErrors, isTrue);
        expect(cubit.state.step, BirthReissuanceStep.documents);
        await cubit.signatureDrawn(Uint8List(4));
        await cubit.signatureDrawn(Uint8List(4));
        cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.step, BirthReissuanceStep.review);
        expect(cubit.state.form?.signature, 'signature-2.png');
        expect(repository.deleted, ['signature-1.png']);
      },
    );

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      'the document: photos only; a new one replaces it',
      setUp: () =>
          repository.draft = _draft(step: BirthReissuanceStep.documents),
      build: build,
      act: (cubit) async {
        await cubit.load();
        expect(
          await cubit.documentPicked(
            path: 'a.pdf',
            name: 'a.pdf',
            sizeBytes: 10,
          ),
          DocumentError.unsupportedType,
        );
        await cubit.documentPicked(path: 'a.jpg', name: 'a.jpg', sizeBytes: 9);
        await cubit.documentPicked(path: 'b.jpg', name: 'b.jpg', sizeBytes: 9);
      },
      verify: (cubit) {
        expect(cubit.state.form?.document?.path, 'b.jpg');
        expect(repository.deleted, ['a.jpg']);
      },
    );

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      'Edit on the preview opens the step; Next returns to the preview',
      setUp: () => repository.draft = _draft(),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.editStep(BirthReissuanceStep.child);
        expect(cubit.state.step, BirthReissuanceStep.child);
        cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.step, BirthReissuanceStep.review);
        expect(cubit.state.returnToReview, isFalse);
      },
    );

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      'Submit needs a confirmed email, then sends the request',
      setUp: () => repository.draft = _draft(),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.submit(email: null);
        expect(cubit.state.showErrors, isTrue);
        expect(repository.submitted, isEmpty);
        await cubit.submit(email: 'parent@mail.com');
      },
      verify: (cubit) {
        expect(cubit.state.submitStatus, SubmitStatus.submitted);
        expect(cubit.state.submitMessage, 'Submitted');
        expect(repository.submitted.single.$2, 'parent@mail.com');
      },
    );

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      'a failed submit says so and keeps the request',
      setUp: () => repository
        ..draft = _draft()
        ..submitResult = const Err(NetworkFailure()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.submit(email: 'parent@mail.com');
      },
      verify: (cubit) {
        expect(cubit.state.submitStatus, SubmitStatus.failed);
        expect(cubit.state.submitFailure, const NetworkFailure());
        expect(repository.draft, isNotNull);
      },
    );
  });

  test('an email is confirmed with a code; editing it undoes that', () async {
    final repository = FakeReissuanceRepository();
    final cubit = EmailCodeCubit(repository)..emailChanged('not-an-email');
    addTearDown(cubit.close);
    await cubit.send();
    expect(repository.codesSent, isEmpty);

    cubit.emailChanged(' parent@mail.com ');
    await cubit.send();
    expect(cubit.state.status, EmailStatus.codeSent);

    repository.confirmCodeResult = const Err(
      ValidationFailure(message: 'Wrong code'),
    );
    cubit.codeChanged('111111');
    await cubit.confirm();
    expect(cubit.state.status, EmailStatus.codeSent);
    expect(cubit.state.failure, isNotNull);

    repository.confirmCodeResult = const Ok(null);
    cubit.codeChanged('123456');
    await cubit.confirm();
    expect(cubit.state.verifiedEmail, 'parent@mail.com');
    expect(repository.codesConfirmed.last, ('parent@mail.com', '123456'));

    cubit.emailChanged('other@mail.com');
    expect(cubit.state.verifiedEmail, isNull);
    expect(repository.codesSent, ['parent@mail.com']);
  });

  group('the demo backend', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    late Directory dir;
    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('reissuance');
    });
    tearDown(() => dir.delete(recursive: true));

    test('uploads the files, sends the request, then clears it', () async {
      final requests = <(String, Object?)>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
        ..interceptors.addAll([
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add((options.path, options.data));
              handler.next(options);
            },
          ),
          FakeBackendInterceptor(latency: Duration.zero),
        ]);
      final repository = ReissuanceRepositoryImpl(
        client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
        storage: signedInUserStorage(),
        faces: FaceVerifier(
          client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
          url: demoFaceUrl,
        ),
      );
      Future<String> file(String name) async {
        final f = File('${dir.path}/$name');
        await f.writeAsBytes([1, 2, 3]);
        return f.path;
      }

      final draft = _draft(
        face: await file('face.jpg'),
        certificate: await file('old.jpg'),
        signature: await file('sign.png'),
        document: AttachedFile(
          path: await file('doc.png'),
          name: 'doc.png',
          sizeBytes: 3,
        ),
      );
      await repository.saveDraft(draft);

      // Without a payment nothing is sent.
      final unpaid = await repository.submitBirth(draft, email: 'p@mail.com');
      expect(unpaid, isA<Err<String?>>());
      expect(requests, isEmpty);

      await repository.payments.keepPayment(
        const StoredPayment(reference: 'BRT1', isPaid: true),
      );
      final result = await repository.submitBirth(draft, email: 'p@mail.com');

      expect(result, const Ok<String?>('Application submitted successfully.'));
      final paths = [for (final (path, _) in requests) path];
      expect(
        paths.where((p) => p.startsWith('/file-upload-url/')),
        hasLength(4),
      );
      expect(paths.where((p) => p.startsWith('https://')), hasLength(4));
      expect(paths.last, '/certificate-reissuance-assisted/add-birth-reg');
      final body = requests.last.$2! as Map<String, Object?>;
      expect(body['paymentReference'], 'BRT1');
      expect(body['email'], 'p@mail.com');
      expect(body['supportingDocument'], hasLength(1));
      // Used: the payment, the request and its files are gone.
      expect(await repository.payments.storedPayment(), isNull);
      expect(await repository.loadDraft(), isNull);
      expect(File(draft.facePhoto!).existsSync(), isFalse);
    });
  });

  group('preview page', () {
    Future<(FakeReissuanceRepository, List<String>)> pumpReview(
      WidgetTester tester,
    ) async {
      tester.view
        ..physicalSize = const Size(400, 6000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = FakeReissuanceRepository()..draft = _draft();
      final exits = <String>[];
      await tester.pumpApp(
        BirthReissuanceFormPage(
          repository: repository,
          onExit: () => exits.add('exit'),
        ),
      );
      await tester.pumpAndSettle();
      return (repository, exits);
    }

    testWidgets('shows every section, and Submit waits for the email', (
      tester,
    ) async {
      final (repository, _) = await pumpReview(tester);

      expect(find.text('Step 5 of 5'), findsOneWidget);
      for (final title in [
        'Certificate Details',
        'Particulars of Child',
        'Particulars of Mother',
        'Particulars of Father',
        'Supporting Documents',
        "Recipient's Email Address",
      ]) {
        expect(find.text(title), findsWidgets, reason: title);
      }
      expect(find.text('CR603/2609-15'), findsOneWidget);
      expect(find.text('Bogoro PHC'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(
        find.text("Validate the recipient's email before submitting."),
        findsOneWidget,
      );
      expect(repository.submitted, isEmpty);
    });

    testWidgets('email code, Submit, then the success dialog and home', (
      tester,
    ) async {
      final (repository, exits) = await pumpReview(tester);

      await tester.enterText(find.byType(TextField).last, 'parent@mail.com');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Validate'));
      await tester.pumpAndSettle();

      expect(find.text('Validate Email'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Validate Email'), findsNothing);
      expect(find.text('Email validated'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Application Successfully Submitted'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(repository.submitted, hasLength(1));
      expect(exits, ['exit']);
    });
  });
}
