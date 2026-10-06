import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/face_verifier.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/data/dtos/reissuance_dtos.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/data/reissuance_repository_impl.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/attestation_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/attestation_form/cubit/attestation_reissuance_form_cubit.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/attestation_form/view/attestation_reissuance_form_page.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/details/view/reissuance_details_page.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_reissuance_repository.dart';

final _today = DateTime(2026, 10, 4);

final _applicant = const ApplicantParticulars()
    .set(ApplicantDetail.surname, 'Ogunlade')
    .set(ApplicantDetail.firstName, 'Bolaji')
    .set(ApplicantDetail.sex, '1')
    .set(ApplicantDetail.dateOfBirth, DateTime(1988, 4, 12).toIso8601String())
    .set(ApplicantDetail.maritalStatus, '1')
    .set(ApplicantDetail.stateOfOrigin, '5')
    .set(ApplicantDetail.lgaOfOrigin, '51')
    .set(ApplicantDetail.town, 'Gobbiya')
    .set(ApplicantDetail.idType, '2')
    .set(ApplicantDetail.idNumber, 'A12345678')
    .set(ApplicantDetail.email, 'applicant@mail.com')
    .set(ApplicantDetail.phone, '08130845852');

final _additional = const AdditionalInformation()
    .set(AdditionalDetail.placeOfBirth, '1')
    .set(AdditionalDetail.typeOfBirth, '1')
    .set(AdditionalDetail.stateOfBirth, '5')
    .set(AdditionalDetail.lgaOfBirth, '51')
    .set(AdditionalDetail.townOfBirth, 'Bogoro')
    .set(AdditionalDetail.registrationState, '5')
    .set(AdditionalDetail.registrationLga, '51')
    .set(AdditionalDetail.registrationCenter, '510')
    .set(AdditionalDetail.currentAddress, 'No 2 Agwada Str')
    .set(AdditionalDetail.educationLevel, '9')
    .set(AdditionalDetail.occupation, '3')
    .set(AdditionalDetail.workAddress, 'Central Market')
    .set(AdditionalDetail.requestReason, '3')
    .set(AdditionalDetail.requiredFor, 'job in nigeria')
    .set(AdditionalDetail.requesterAddress, 'Federal Secretariat');

AttestationParent _parent({bool mother = false}) {
  var parent = const AttestationParent()
      .set(AttestationParentDetail.surname, 'Ogunlade')
      .set(AttestationParentDetail.firstName, mother ? 'Amina' : 'Musa')
      .set(AttestationParentDetail.state, '5')
      .set(AttestationParentDetail.lga, '51')
      .set(AttestationParentDetail.town, 'Gobbiya');
  if (mother) parent = parent.set(AttestationParentDetail.maidenName, 'Bello');
  return parent;
}

AttestationReissuanceForm _complete({
  AttestationReissuanceStep step = AttestationReissuanceStep.review,
  AttachedFile? affidavit = const AttachedFile(
    path: 'affidavit.jpg',
    name: 'affidavit.jpg',
    sizeBytes: 10,
  ),
  String? signature = 'sign.png',
}) => AttestationReissuanceForm(
  step: step,
  applicant: _applicant,
  additional: _additional,
  mother: _parent(mother: true),
  father: _parent(),
  affidavit: affidavit,
  signature: signature,
);

ReissuanceDraft _draft({
  AttestationReissuanceForm? form,
  String face = 'face.jpg',
  String certificate = 'old.jpg',
}) => ReissuanceDraft(
  startedOn: _today,
  mode: ValidationMode.nin,
  ninRecord: ninRecord,
  facePhoto: face,
  certificate: LegacyCertificate(
    kind: ReissuanceKind.attestation,
    number: 'AT1',
    issuedOn: DateTime(2012, 5, 14),
    filePath: certificate,
    fileName: 'old.jpg',
    sizeBytes: 10,
  ),
  attestationForm: form,
);

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

T _ok<T>(Result<T> result) => (result as Ok<T>).value;

void main() {
  group('rules', () {
    test('the applicant: 18 or older, born by the commission date', () {
      expect(_applicant.isComplete(today: _today), isTrue);
      String born(DateTime date) => date.toIso8601String();
      final minor = _applicant.set(
        ApplicantDetail.dateOfBirth,
        born(DateTime(2010)),
      );
      expect(
        minor.errorOf(ApplicantDetail.dateOfBirth, today: _today),
        ReissuanceFieldError.underAge,
      );
      // 18 tomorrow.
      expect(
        _applicant
            .set(ApplicantDetail.dateOfBirth, born(DateTime(2008, 10, 5)))
            .errorOf(ApplicantDetail.dateOfBirth, today: _today),
        ReissuanceFieldError.underAge,
      );
      expect(
        _applicant
            .set(ApplicantDetail.dateOfBirth, born(DateTime(2023, 12)))
            .errorOf(ApplicantDetail.dateOfBirth, today: DateTime(2045)),
        ReissuanceFieldError.tooLate,
      );
      expect(
        _applicant
            .set(ApplicantDetail.email, 'nope')
            .errorOf(ApplicantDetail.email, today: _today),
        ReissuanceFieldError.invalidEmail,
      );
      expect(
        _applicant
            .set(ApplicantDetail.middleName, null)
            .isComplete(today: _today),
        isTrue,
      );
    });

    test('a requirement abroad asks for the country; locality is optional', () {
      final abroad = _additional.set(
        AdditionalDetail.requiredFor,
        'job abroad',
      );
      expect(
        abroad.errorOf(AdditionalDetail.country),
        ReissuanceFieldError.required,
      );
      expect(abroad.set(AdditionalDetail.country, '31').isComplete, isTrue);
      expect(_additional.applies(AdditionalDetail.country), isFalse);
      expect(
        _additional.set(AdditionalDetail.townOfBirth, null).isComplete,
        isTrue,
      );
    });

    test('documents need the affidavit and the signature', () {
      bool complete(AttestationReissuanceForm form) =>
          form.isComplete(AttestationReissuanceStep.documents, today: _today);
      expect(complete(_complete()), isTrue);
      expect(complete(_complete(affidavit: null)), isFalse);
      expect(complete(_complete(signature: null)), isFalse);
      expect(
        complete(
          _complete(affidavit: null).copyWith(
            keptAffidavit: () =>
                const KeptFile(key: 'k', mimeType: 'image/png'),
          ),
        ),
        isTrue,
      );
    });

    test('a draft with the form reads back the same', () {
      final draft = _draft(form: _complete());
      expect(ReissuanceDraft.fromJson(draft.toJson()), draft);
      expect(draft.files, ['face.jpg', 'old.jpg', 'affidavit.jpg', 'sign.png']);
    });
  });

  test('the request goes in the API\'s names and types', () {
    final json = attestationReissuanceToJson(
      (
        kind: ReissuanceKind.attestation,
        number: 'AT1',
        issuedOn: DateTime(2012, 5, 14),
        nin: '12345678901',
      ),
      _complete(),
      files: (
        certificate: 'cert-key',
        face: 'face-key',
        signature: 'sign-key',
        affidavit: (key: 'affidavit-key', mimeType: 'image/jpeg'),
      ),
      paymentReference: 'BRT1',
    );

    expect(json, containsPair('certType', 'attest_reissuance'));
    expect(json, containsPair('legacyCertIssuedDate', '2012-05-14'));
    expect(json, containsPair('applicantDateOfBirth', '1988-04-12'));
    expect(json, containsPair('applicantSex', 1));
    expect(json, containsPair('applicantOriginLga', 51));
    expect(json, containsPair('applicantRegCenter', 510));
    expect(json, containsPair('applicantTown', 'Gobbiya'));
    expect(json, containsPair('townOfBirth', 'Bogoro'));
    expect(json, containsPair('idType', 2));
    expect(json, containsPair('idNumber', 'A12345678'));
    expect(json, containsPair('applicantEmail', 'applicant@mail.com'));
    expect(json, containsPair('requestRequiredFor', 'job in nigeria'));
    expect(json, containsPair('fatherName', 'Ogunlade Musa'));
    expect(json, containsPair('motherName', 'Ogunlade Amina Bello'));
    expect(json, containsPair('motherState', 5));
    expect(json, containsPair('motherLga', 51));
    expect(json, containsPair('face', 'face-key'));
    expect(json, containsPair('signature', 'sign-key'));
    expect(json['supportingDocument'], [
      {
        'type': 'court-affidavit',
        'file': 'affidavit-key',
        'mimeType': 'image/jpeg',
      },
    ]);
  });

  group('the demo backend', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('reads a queried request, splitting the parents\' names', () async {
      final (repository, requests) = _demo();
      final record = _ok(await repository.attestationRecord('4103'));

      expect(
        requests.single.$2,
        '/certificate-reissuance-assisted/single-birth-attest/4103',
      );
      expect(record.status, ReissuanceStatus.queried);
      expect(record.query?.reason, 'The court affidavit is not readable.');
      expect(record.nin, '12345678901');
      expect(record.faceKey, 'reissuance/face-3.jpg');
      final form = record.form;
      expect(form.applicant[ApplicantDetail.town], 'Isiukwuato');
      expect(form.applicant.dateOfBirth, DateTime(1988, 4, 12));
      expect(form.additional[AdditionalDetail.registrationLga], '11');
      expect(form.father[AttestationParentDetail.surname], 'Garba');
      expect(form.father[AttestationParentDetail.firstName], 'Musa');
      expect(form.mother[AttestationParentDetail.firstName], 'Amina');
      expect(form.mother[AttestationParentDetail.maidenName], 'Bello');
      expect(form.keptAffidavit?.key, 'reissuance/affidavit-3.png');
      // The API doesn't send back the type of birth, so a correction
      // asks for it again; everything else is filled in.
      expect(
        form.additional.errorOf(AdditionalDetail.typeOfBirth),
        ReissuanceFieldError.required,
      );
      expect(
        form
            .copyWith(
              additional: form.additional.set(
                AdditionalDetail.typeOfBirth,
                '1',
              ),
            )
            .isComplete(AttestationReissuanceStep.review, today: _today),
        isTrue,
      );
    });

    test('uploads the files, sends the request, then clears it', () async {
      final (repository, requests) = _demo();
      final dir = await Directory.systemTemp.createTemp('attest');
      addTearDown(() => dir.delete(recursive: true));
      Future<String> file(String name) async {
        final f = File('${dir.path}/$name');
        await f.writeAsBytes([1, 2, 3]);
        return f.path;
      }

      final draft = _draft(
        face: await file('face.jpg'),
        certificate: await file('old.jpg'),
        form: _complete(
          affidavit: AttachedFile(
            path: await file('affidavit.png'),
            name: 'affidavit.png',
            sizeBytes: 3,
          ),
          signature: await file('sign.png'),
        ),
      );
      await repository.saveDraft(draft);
      await repository.payments.keepPayment(
        const StoredPayment(reference: 'BRT1', isPaid: true),
      );

      final result = await repository.submitAttestation(draft);

      expect(result, const Ok<String?>('Application submitted successfully.'));
      final paths = [for (final r in requests) r.$2];
      expect(
        paths.where((p) => p.startsWith('/file-upload-url/')),
        hasLength(4),
      );
      expect(paths.last, '/certificate-reissuance-assisted/add-birth-attest');
      final body = requests.last.$3! as Map<String, Object?>;
      expect(body['paymentReference'], 'BRT1');
      expect(body['nin'], ninRecord.nin);
      expect(await repository.payments.storedPayment(), isNull);
      expect(await repository.loadDraft(), isNull);
    });

    test('a correction is resent with its id and kept files', () async {
      final (repository, requests) = _demo();
      final record = _ok(await repository.attestationRecord('4103'));
      requests.clear();

      await repository.updateAttestation(record, record.form);

      expect(requests.single.$1, 'PATCH');
      final body = requests.single.$3! as Map<String, Object?>;
      expect(body['id'], 4103);
      expect(body['paymentReference'], 'BRTFA30087680');
      expect(body['face'], 'reissuance/face-3.jpg');
      expect(body['signature'], 'reissuance/sign-3.png');
      expect(
        (body['supportingDocument']! as List).single,
        containsPair('file', 'reissuance/affidavit-3.png'),
      );
    });
  });

  group('AttestationReissuanceFormCubit', () {
    late FakeReissuanceRepository repository;
    setUp(() => repository = FakeReissuanceRepository()..draft = _draft());

    AttestationReissuanceFormCubit build() =>
        AttestationReissuanceFormCubit(repository, now: () => _today);

    blocTest<AttestationReissuanceFormCubit, AttestationReissuanceFormState>(
      'a new form starts from the NIN, its state and LGA matched by name',
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.flush();
      },
      verify: (cubit) {
        final applicant = cubit.state.form!.applicant;
        expect(applicant[ApplicantDetail.surname], 'Ogunlade');
        expect(applicant[ApplicantDetail.sex], '1');
        expect(applicant[ApplicantDetail.stateOfOrigin], '5');
        expect(applicant[ApplicantDetail.lgaOfOrigin], '51');
        expect(cubit.state.sexLocked, isTrue);
        expect(repository.draft?.attestationForm, cubit.state.form);
      },
    );

    blocTest<AttestationReissuanceFormCubit, AttestationReissuanceFormState>(
      'step 1 needs the applicant\'s email confirmed',
      setUp: () => repository.draft = _draft(
        form: _complete(step: AttestationReissuanceStep.applicant),
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.next(emailVerified: false);
        expect(cubit.state.step, AttestationReissuanceStep.applicant);
        expect(cubit.state.showErrors, isTrue);
        cubit.next(emailVerified: true);
      },
      verify: (cubit) =>
          expect(cubit.state.step, AttestationReissuanceStep.additional),
    );

    blocTest<AttestationReissuanceFormCubit, AttestationReissuanceFormState>(
      'Submit needs the declaration, then sends the request',
      setUp: () => repository.draft = _draft(form: _complete()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.submit();
        expect(cubit.state.showErrors, isTrue);
        expect(repository.attestationsSubmitted, isEmpty);
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.submitStatus, SubmitStatus.submitted);
        expect(repository.attestationsSubmitted, hasLength(1));
      },
    );

    blocTest<AttestationReissuanceFormCubit, AttestationReissuanceFormState>(
      'a queried one opens at the preview and is resent, not saved',
      setUp: () => repository.attestationRecordResult = Ok(
        AttestationReissuanceRecord(
          id: '4103',
          status: ReissuanceStatus.queried,
          reference: 'BRT4',
          nin: '12345678901',
          certificateNumber: 'AT1',
          issuedOn: DateTime(2012, 5, 14),
          certificateKey: 'cert-key',
          faceKey: 'face-key',
          form: _complete(affidavit: null, signature: null).copyWith(
            keptAffidavit: () =>
                const KeptFile(key: 'affidavit-key', mimeType: 'image/png'),
            keptSignature: () =>
                const KeptFile(key: 'sign-key', mimeType: 'image/png'),
          ),
        ),
      ),
      build: () => AttestationReissuanceFormCubit(
        repository,
        queriedId: '4103',
        now: () => _today,
      ),
      act: (cubit) async {
        await cubit.load();
        expect(cubit.state.step, AttestationReissuanceStep.review);
        cubit
          ..applicantChanged(ApplicantDetail.town, 'Bogoro')
          ..declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        final (record, form) = repository.attestationsUpdated.single;
        expect(record.id, '4103');
        expect(form.applicant[ApplicantDetail.town], 'Bogoro');
        expect(repository.draft?.attestationForm, isNull);
      },
    );
  });

  group('form page', () {
    Future<FakeReissuanceRepository> pumpForm(
      WidgetTester tester, {
      AttestationReissuanceForm? form,
    }) async {
      tester.view
        ..physicalSize = const Size(400, 6000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = FakeReissuanceRepository()..draft = _draft(form: form);
      await tester.pumpApp(
        AttestationReissuanceFormPage(repository: repository, onExit: () {}),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('step 1 waits for the applicant\'s email to be validated', (
      tester,
    ) async {
      await pumpForm(
        tester,
        form: _complete(step: AttestationReissuanceStep.applicant),
      );

      expect(find.text('Particulars of Applicant'), findsWidgets);
      expect(find.text('applicant@mail.com'), findsOneWidget);
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text("Validate the applicant's email to continue."),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Validate'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 5'), findsOneWidget);
    });

    testWidgets("both parents' fields are on step 3", (tester) async {
      await pumpForm(
        tester,
        form: _complete(step: AttestationReissuanceStep.parents),
      );

      expect(find.text('Particulars of Father'), findsOneWidget);
      expect(find.text('Particulars of Mother'), findsOneWidget);
      expect(find.text('Musa'), findsOneWidget);
      expect(find.text('Bello'), findsOneWidget);
    });

    testWidgets('the preview shows every section and needs the declaration', (
      tester,
    ) async {
      final repository = await pumpForm(tester, form: _complete());

      for (final title in [
        'Certificate Details',
        'Particulars of Applicant',
        'Additional Information',
        "Parent's Information",
        'Supporting Documents',
      ]) {
        expect(find.text(title), findsWidgets, reason: title);
      }
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Tick the declaration to submit.'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('Application Successfully Submitted'), findsOneWidget);
      expect(repository.attestationsSubmitted, hasLength(1));
    });
  });

  testWidgets('Certificate Details for an attestation', (tester) async {
    tester.view
      ..physicalSize = const Size(400, 5000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = FakeReissuanceRepository()
      ..attestationRecordResult = Ok(
        AttestationReissuanceRecord(
          id: '4101',
          status: ReissuanceStatus.approved,
          reference: 'BRT2',
          nin: '12345678901',
          certificateNumber: 'AT1',
          issuedOn: DateTime(2012, 5, 14),
          certificateKey: 'cert-key',
          form: _complete(),
        ),
      );
    await tester.pumpApp(
      ReissuanceDetailsPage(
        kind: ReissuanceKind.attestation,
        id: '4101',
        repository: repository,
        onUpdate: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Attestation Certificate'), findsOneWidget);
    expect(find.text('Loss of Letter of Attestation'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(repository.downloads, [(ReissuanceKind.attestation, 'BRT2')]);
  });
}
