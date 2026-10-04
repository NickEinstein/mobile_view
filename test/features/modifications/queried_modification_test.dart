import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/modifications/data/dtos/modification_dtos.dart';
import 'package:vital_reg_mobile/features/modifications/data/modifications_repository_impl.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_documents.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_submission.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_summary.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/queried_modification.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/record_edit.dart';
import 'package:vital_reg_mobile/features/modifications/domain/modifications_repository.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/form/cubit/modification_form_cubit.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/form/view/modification_form_page.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/form/view/queried_modification_page.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/home/cubit/modifications_cubit.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/home/view/modifications_home_page.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_modifications_repository.dart';

final _today = DateTime(2026, 10, 3);

/// A date of birth change sent back for its request letter.
final _queried = QueriedModification(
  id: '9',
  request: ModificationRequest.fromApi(
    ModificationKind.birth,
    type: 'child particulars',
    field: 'applicant_dob',
    reason: 'incorrect age entered',
  )!,
  record: const ModificationRecord(
    kind: ModificationKind.birth,
    recordId: '40',
    certificateNumber: 'B123',
    name: 'Lee Michael',
    values: {RecordField.dateOfBirth: '2020-09-08'},
  ),
  paymentReference: 'BRTFIRST',
  queryReason: 'The request letter is missing.',
  documents: const {
    ModificationDocument.dateOfBirthAffidavit: UploadedFile(
      key: 'modifications/a1',
      mimeType: 'image/jpeg',
    ),
  },
);

void main() {
  group('ModificationRequest.fromApi', () {
    test('rebuilds what was asked, ignoring case', () {
      final request = ModificationRequest.fromApi(
        ModificationKind.birth,
        type: 'child particulars',
        field: 'child_place_of_birth',
        reason: 'incorrect place of birth',
        comment: 'Wrong LGA',
      );
      expect(request?.field, ModificationField.childPlaceOfBirth);
      expect(request?.reason, ModificationReason.incorrectPlaceOfBirth);
      expect(request?.comment, 'Wrong LGA');
      expect(request?.isComplete, isTrue);

      final father = ModificationRequest.fromApi(
        ModificationKind.birth,
        type: 'father_name',
        field: 'father_name',
        reason: 'switching of name order',
      );
      expect(father?.reason, ModificationReason.switchedNameOrder);
    });

    test('is null for a type or field the app does not offer', () {
      expect(
        ModificationRequest.fromApi(
          ModificationKind.birth,
          type: 'child particulars',
          field: 'child_state_of_origin',
          reason: null,
        ),
        isNull,
      );
      expect(
        ModificationRequest.fromApi(
          ModificationKind.birth,
          type: 'deceased_name',
          field: null,
          reason: null,
        ),
        isNull,
      );
    });
  });

  group('DTOs', () {
    test('reads a queried request', () {
      final queried = queriedFromJson({
        'data': {
          'Birth_Reg_ID': 40,
          'Certificate_No': 'B123',
          'child_surname': 'Lee',
          'child_firstname': 'Michael',
          'Modification': [
            {
              'id': 9,
              'reference': 'BRTFIRST',
              'mod_type': 'child particulars',
              'mod_field': 'applicant_dob',
              'mod_reason': 'incorrect age entered',
              'child_age': '2020-09-08T00:00:00.000Z',
              'supportingDocument': [
                {
                  'type': 'date-of-birth-affidavit',
                  'file':
                      'https://bucket.s3.amazonaws.com/modifications/a1?X-Sig=1',
                  'mimeType': 'image/png',
                },
                {'type': 'unknown-type', 'file': 'x'},
              ],
            },
          ],
        },
        'queried': {'reason': 'The request letter is missing.'},
      }, kind: ModificationKind.birth)!;

      expect(queried.id, '9');
      expect(queried.paymentReference, 'BRTFIRST');
      expect(queried.queryReason, 'The request letter is missing.');
      expect(queried.request.field, ModificationField.childDateOfBirth);
      expect(queried.record.recordId, '40');
      expect(queried.record[RecordField.dateOfBirth], '2020-09-08');
      expect(queried.documents, {
        ModificationDocument.dateOfBirthAffidavit: const UploadedFile(
          key: 'modifications/a1',
          mimeType: 'image/png',
        ),
      });
    });

    test('a resend adds its id and keeps the documents sent before', () {
      final json = submissionToJson(
        ModificationSubmission(
          request: _queried.request,
          edit: RecordEdit.start(
            _queried.record,
            _queried.request.editableFields,
          ),
          paymentReference: 'BRTFIRST',
          modificationId: '9',
          documents: ModificationDocuments(const {}, _queried.documents),
        ),
        documents: [
          (type: 'request-letter', key: 'modifications/new', mimeType: 'x'),
        ],
      );
      expect(json['id'], 9);
      expect(json['reference'], 'BRTFIRST');
      expect(json['child_age'], '2020-09-08');
      expect(json['supportingDocument'], [
        {
          'type': 'date-of-birth-affidavit',
          'file': 'modifications/a1',
          'mimeType': 'image/jpeg',
        },
        {
          'type': 'request-letter',
          'file': 'modifications/new',
          'mimeType': 'x',
        },
      ]);
    });
  });

  test('loads and resends through the API endpoints', () async {
    final calls = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
      ..interceptors.addAll([
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add('${options.method} ${options.path}');
            handler.next(options);
          },
        ),
        FakeBackendInterceptor(latency: Duration.zero),
      ]);
    final repository = ModificationsRepositoryImpl(
      client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
      storage: signedInUserStorage(),
    );

    final loaded = await repository.queried(ModificationKind.birth, 'q-0');
    final queried = (loaded as Ok<QueriedModification>).value;
    final sent = await repository.submit(
      ModificationSubmission(
        request: queried.request,
        edit: RecordEdit.start(queried.record, queried.request.editableFields),
        paymentReference: queried.paymentReference,
        modificationId: queried.id,
      ),
    );

    expect(sent, isA<Ok<String?>>());
    expect(calls, [
      'GET /modification/birth-registration/single/q-0',
      'PATCH /modification/birth-registration',
    ]);
  });

  group('ModificationFormCubit.queried', () {
    late FakeModificationsRepository repository;
    setUp(() => repository = FakeModificationsRepository());

    ModificationFormCubit build() => ModificationFormCubit.queried(
      repository,
      _queried,
      today: () => _today,
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'may be resent unchanged, but needs the missing document',
      build: build,
      act: (cubit) async {
        cubit.declaredChanged(true);
        await cubit.modify();
        await cubit.submitDocuments();
      },
      verify: (cubit) {
        expect(cubit.state.step, ModificationFormStep.documents);
        expect(
          cubit.state.documents.has(ModificationDocument.dateOfBirthAffidavit),
          isTrue,
        );
        expect(cubit.state.showErrors, isTrue);
        expect(repository.submitted, isEmpty);
      },
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'resends under its own payment, without touching a new one',
      build: build,
      act: (cubit) async {
        cubit.declaredChanged(true);
        await cubit.modify();
        await cubit.documentPicked(
          ModificationDocument.requestLetter,
          path: 'letter.jpg',
          name: 'letter.jpg',
          sizeBytes: 100,
        );
        await cubit.submitDocuments();
      },
      verify: (cubit) {
        final sent = repository.submitted.single;
        expect(sent.modificationId, '9');
        expect(sent.paymentReference, 'BRTFIRST');
        expect(sent.documents.uploaded.keys, {
          ModificationDocument.dateOfBirthAffidavit,
        });
        expect(sent.documents.files.keys, {ModificationDocument.requestLetter});
        expect(repository.paidFor, isEmpty);
        expect(cubit.state.submitted, isTrue);
      },
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'a document sent before can be removed',
      build: build,
      act: (cubit) =>
          cubit.documentRemoved(ModificationDocument.dateOfBirthAffidavit),
      verify: (cubit) {
        expect(cubit.state.documents.uploaded, isEmpty);
        expect(repository.deleted, isEmpty);
      },
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'only loads options when the place of birth is being changed',
      build: build,
      act: (cubit) => cubit.load(),
      verify: (_) => expect(repository.lgasAsked, isEmpty),
    );
  });

  group('views', () {
    testWidgets('the queried form shows why, and only what it changes', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1170, 2532)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        BlocProvider(
          create: (_) => ModificationFormCubit.queried(
            FakeModificationsRepository(),
            _queried,
            today: () => _today,
          ),
          child: ModificationFormView(onDone: () {}, onExit: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Queried Record'), findsOneWidget);
      expect(find.text('Particulars of Child'), findsWidgets);
      expect(
        find.text('Reason: The request letter is missing.'),
        findsOneWidget,
      );
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('Surname'), findsNothing);
      expect(find.text('Particulars of Mother'), findsNothing);
      expect(find.text('08/09/2020'), findsOneWidget);
    });

    testWidgets('a queried request opens from the home list', (tester) async {
      tester.view
        ..physicalSize = const Size(1170, 2532)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repository = FakeModificationsRepository()
        ..listResult = const Ok([
          ModificationSummary(
            id: 'q1',
            name: 'Lee Michael',
            certificateNumber: 'B1',
            status: ModificationStatus.queried,
          ),
        ]);
      (ModificationKind, String)? opened;
      await tester.pumpApp(
        BlocProvider(
          create: (_) => ModificationsCubit(repository)..load().ignore(),
          child: ModificationsHomeView(
            onNewRequest: (_) async {},
            onOpenQueried: (kind, id) async => opened = (kind, id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      expect(find.text('Respond to query'), findsOneWidget);
      await tester.tap(find.text('Respond to query'));
      await tester.pumpAndSettle();
      expect(opened, (ModificationKind.birth, 'q1'));

      // Answered: the home reloads.
      expect(repository.requested.length, greaterThan(1));
    });

    testWidgets('the queried page says when it cannot load, and retries', (
      tester,
    ) async {
      final repository = FakeModificationsRepository()
        ..queriedResult = const Err(NetworkFailure());
      GetIt.instance.registerSingleton<ModificationsRepository>(repository);
      addTearDown(GetIt.instance.reset);

      await tester.pumpApp(
        QueriedModificationPage(
          kind: ModificationKind.birth,
          id: 'q1',
          onDone: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No internet connection. Check your connection and try again.',
        ),
        findsOneWidget,
      );

      repository.queriedResult = Ok(_queried);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Queried Record'), findsOneWidget);
      expect(repository.queriedAsked, [
        (ModificationKind.birth, 'q1'),
        (ModificationKind.birth, 'q1'),
      ]);
    });
  });
}
