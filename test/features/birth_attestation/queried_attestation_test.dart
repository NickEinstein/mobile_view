import 'package:bloc_test/bloc_test.dart';
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
import 'package:vital_reg_mobile/features/birth_attestation/data/dtos/attestation_dtos.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/face_verifier.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/details/cubit/attestation_details_cubit.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/details/view/attestation_details_page.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/form/cubit/attestation_form_cubit.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/home/view/birth_attestation_home_page.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_birth_attestation_repository.dart';

/// The demo backend's queried sample, read through the real repository.
Future<AttestationRecord> _demoRecord(String id) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
    ..interceptors.add(FakeBackendInterceptor(latency: Duration.zero));
  final client = ApiClient(dio, LoggingCrashReporter(AppLogger()));
  final repository = BirthAttestationRepositoryImpl(
    client: client,
    storage: signedInUserStorage(),
    faces: FaceVerifier(client: client, url: demoFaceUrl),
  );
  return ((await repository.details(id)) as Ok<AttestationRecord>).value;
}

final _queriedSummary = BirthApplicationSummary(
  id: 'queried-0',
  childName: 'Michael Lee',
  trackingId: 'FA30087677',
  submittedOn: DateTime(2026, 9, 23),
  status: ApplicationStatus.queried,
);

void main() {
  late AttestationRecord queried;

  setUpAll(() async => queried = await _demoRecord('ATT20000'));

  test('the demo backend records a queried attestation with its reason', () {
    expect(queried.summary.status, ApplicationStatus.queried);
    expect(queried.queryReason, 'Wrong document uploaded');
    expect(queried.providedDocuments, {AttestationDocument.affidavit});
    expect(queried.applicant[ApplicantField.surname], 'Lee');
  });

  test(
    'a correction sends the files on file, uploading only replaced ones',
    () {
      final draft = queried.toQueriedDraft();
      final kept = attestationUpdateToJson(
        draft,
        uploads: (face: null, documents: const {}),
      );
      final replaced = attestationUpdateToJson(
        draft,
        uploads: (
          face: null,
          documents: const {AttestationDocument.affidavit: 'new/aff.jpg'},
        ),
      );

      expect(kept['id'], 7020);
      expect(kept['reference'], 'ATT20000');
      expect((kept['SupportingDocument']! as List).single, {
        'type': 'affidavit',
        'file': 'attestation/aff.jpg',
        'mimeType': 'image/jpeg',
      });
      expect(
        ((replaced['SupportingDocument']! as List).single as Map)['file'],
        'new/aff.jpg',
      );
      // Both parents are Nigerian.
      expect(kept['mother_passport'], isNull);
    },
  );

  group('correcting a queried record', () {
    late FakeBirthAttestationRepository repository;

    setUp(
      () => repository = FakeBirthAttestationRepository()
        ..detailsResult = Ok(queried)
        ..payments.stored = const StoredPayment(
          reference: 'UNUSED',
          isPaid: true,
        ),
    );

    AttestationFormCubit build() => AttestationFormCubit(
      repository,
      queriedRecordId: 'ATT20000',
      now: () => DateTime(2026, 10, 3),
      newSubmissionKey: () => 'key',
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'opens the record, with what is on file counting as provided',
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        final state = cubit.state;
        expect(state.status, FormStatus.ready);
        expect(state.isCorrection, isTrue);
        expect(state.queryReason, 'Wrong document uploaded');
        expect(state.draft!.applicant, queried.applicant);
        // Face and affidavit are on the server already.
        expect(state.isComplete(AttestationStep.review, cubit.today), isTrue);
      },
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'keeps the correction off the device',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.additionalChanged(AdditionalField.workAddress, 'New office');
      },
      verify: (cubit) {
        expect(repository.saves, 0);
        expect(repository.draft, isNull);
      },
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'sends the update, with no payment involved',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit
          ..additionalChanged(AdditionalField.workAddress, 'New office')
          ..declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.submitStatus, SubmitStatus.submitted);
        expect(cubit.state.trackingId, 'ATT20000');
        final sent = repository.corrections.single;
        expect(sent.queried?.recordId, '7020');
        expect(sent.additional[AdditionalField.workAddress], 'New office');
        expect(repository.submitted, isEmpty);
        expect(repository.payments.stored, isNotNull);
      },
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'a record that cannot load offers to retry',
      setUp: () => repository.detailsResult = const Err(NetworkFailure()),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.status, FormStatus.failure),
    );
  });

  group('home', () {
    late FakeBirthAttestationRepository repository;
    late List<String> opened;
    late List<String> updated;

    setUp(() {
      repository = FakeBirthAttestationRepository()
        ..items = [_queriedSummary]
        ..detailsResult = Ok(queried);
      opened = [];
      updated = [];
    });

    Future<void> pumpHome(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(400, 2000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        BirthAttestationHomePage(
          repository: repository,
          onStartApplication: () async {},
          onResumeAtFace: () async {},
          onResumeAtForm: () async {},
          onOpenApplication: (id) async => opened.add(id),
          onUpdateQueried: (id) async => updated.add(id),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a queried application shows the Queried Record dialog', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.tap(find.text('Michael Lee'));
      await tester.pumpAndSettle();

      expect(find.text('Queried Record'), findsOneWidget);
      expect(find.textContaining('Wrong document uploaded'), findsOneWidget);
      expect(find.textContaining('FA30087677'), findsWidgets);

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(updated, ['queried-0']);
      expect(opened, isEmpty);
    });

    testWidgets('Cancel closes the dialog without updating', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('Michael Lee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Queried Record'), findsNothing);
      expect(updated, isEmpty);
    });

    testWidgets('other applications open their details', (tester) async {
      repository.items = [
        BirthApplicationSummary(
          id: 'approved-0',
          childName: 'Sofia Martinez',
          trackingId: 'FA1',
          submittedOn: DateTime(2026, 9),
          status: ApplicationStatus.approved,
        ),
      ];
      await pumpHome(tester);
      await tester.tap(find.text('Sofia Martinez'));
      await tester.pumpAndSettle();
      expect(opened, ['approved-0']);
    });
  });

  group('Certificate Details', () {
    testWidgets('shows the record read-only; a queried one offers Update', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(400, 6000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = FakeBirthAttestationRepository()
        ..detailsResult = Ok(queried);
      var updates = 0;

      await tester.pumpApp(
        BlocProvider(
          create: (_) =>
              AttestationDetailsCubit(repository, id: 'queried-0')
                ..load().ignore(),
          child: AttestationDetailsView(onUpdate: () => updates++),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Certificate Details'), findsOneWidget);
      expect(find.text('Particulars of Applicant'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.textContaining('Wrong document uploaded'), findsOneWidget);
      await tester.tap(find.text('Update'));
      expect(updates, 1);
    });

    blocTest<AttestationDetailsCubit, AttestationDetailsState>(
      'reports a record that cannot load',
      build: () =>
          AttestationDetailsCubit(FakeBirthAttestationRepository(), id: 'x'),
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.failure, const NotFoundFailure()),
    );
  });
}
