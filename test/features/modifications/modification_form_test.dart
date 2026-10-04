import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/network/request_flags.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/modifications/data/dtos/modification_dtos.dart';
import 'package:vital_reg_mobile/features/modifications/data/modifications_repository_impl.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_documents.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_submission.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/record_edit.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/form/cubit/modification_form_cubit.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/form/view/modification_form_page.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_modifications_repository.dart';

final _today = DateTime(2026, 10, 3);

ModificationRequest _child(ModificationField field) =>
    const ModificationRequest(kind: ModificationKind.birth)
        .withType(ModificationType.childParticulars)
        .withField(field)
        .withReason(field.reasons.first);

final _nameChange = _child(ModificationField.childName);
final _dobChange = _child(ModificationField.childDateOfBirth);
final _placeChange = _child(ModificationField.childPlaceOfBirth);
final _motherChange = const ModificationRequest(kind: ModificationKind.birth)
    .withType(ModificationType.motherName)
    .withReason(ModificationReason.misspelledName)
    .withComment('Spelled wrongly');

RecordEdit _edit(ModificationRequest request) =>
    RecordEdit.start(sampleRecord, request.editableFields);

void main() {
  group('RecordEdit', () {
    test('each change unlocks only its own fields', () {
      expect(_nameChange.editableFields, {
        RecordField.surname,
        RecordField.firstName,
        RecordField.middleName,
      });
      expect(_dobChange.editableFields, {RecordField.dateOfBirth});
      expect(_motherChange.editableFields, contains(RecordField.motherSurname));
      expect(_motherChange.apiField, 'mother_name');
      expect(_dobChange.apiField, 'applicant_dob');
    });

    test('read-only fields never change; a new state clears its LGA', () {
      final edit = _edit(
        _placeChange,
      ).set(RecordField.surname, 'Other').set(RecordField.birthState, '25');

      expect(edit[RecordField.surname], 'Hasan');
      expect(edit[RecordField.birthLga], isNull);
      expect(
        edit.errorOf(RecordField.birthLga, today: _today),
        RecordEditError.required,
      );
    });

    test('names, dates and "nothing changed"', () {
      final untouched = _edit(_nameChange);
      expect(untouched.isChanged, isFalse);
      expect(untouched.isValid(today: _today), isFalse);

      final bad = untouched.set(RecordField.surname, 'Hass4n');
      expect(
        bad.errorOf(RecordField.surname, today: _today),
        RecordEditError.invalidName,
      );
      final good = untouched.set(RecordField.surname, "Hassan-O'Neil");
      expect(good.isValid(today: _today), isTrue);
      // The middle name is optional.
      expect(good.errorOf(RecordField.middleName, today: _today), isNull);

      final future = _edit(
        _dobChange,
      ).set(RecordField.dateOfBirth, '2026-10-04');
      expect(
        future.errorOf(RecordField.dateOfBirth, today: _today),
        RecordEditError.futureDate,
      );
    });
  });

  group('DTOs', () {
    test('reads the birth record values; a timestamp becomes a date', () {
      final record = recordFromJson(
        {
          'data': {
            'Birth_Reg_ID': 40,
            'Certificate_No': 'B123',
            'childData': {
              'surname': 'Hassan',
              'firstname': 'Suleiman',
              'middle_name': ' ',
              'birth_date': '2020-09-09T00:00:00.000Z',
              'gender': 1,
              'birth_state': 1,
              'birth_lga': 11,
              'town_of_birth': 'Ovim',
            },
            'motherData': {'surname': 'Ikemefuna', 'firstname': 'Devine'},
            'fatherData': {'surname': 'Ikemefuna'},
          },
        },
        kind: ModificationKind.birth,
        certificateNumber: 'B123',
      )!;

      expect(record.recordId, '40');
      expect(record[RecordField.middleName], isNull);
      expect(record[RecordField.dateOfBirth], '2020-09-09');
      expect(record[RecordField.sex], '1');
      expect(record[RecordField.birthLga], '11');
      expect(record[RecordField.motherFirstName], 'Devine');
    });

    test('sends only the change', () {
      final json = submissionToJson(
        ModificationSubmission(
          request: _placeChange,
          edit: _edit(_placeChange)
              .set(RecordField.birthState, '25')
              .set(RecordField.birthLga, '251')
              .set(RecordField.birthTown, 'Ikeja'),
          paymentReference: 'REF1',
        ),
      );

      expect(json, {
        'Birth_Reg_ID': 40,
        'mod_type': 'child particulars',
        'mod_field': 'child_place_of_birth',
        'mod_reason': 'Incorrect Place of Birth',
        'reference': 'REF1',
        'child_state_of_birth': 25,
        'child_lga_of_birth': 251,
        'child_town_of_birth': 'Ikeja',
      });

      final mother = submissionToJson(
        ModificationSubmission(
          request: _motherChange,
          edit: _edit(_motherChange).set(RecordField.motherSurname, 'Ike'),
          paymentReference: 'REF2',
        ),
      );
      expect(mother['mod_field'], 'mother_name');
      expect(mother['comment'], 'Spelled wrongly');
      expect(mother['mother_surname'], 'Ike');
      expect(mother['mother_firstname'], 'Devine');
      expect(mother.containsKey('child_surname'), isFalse);
    });
  });

  test('uploads documents to storage, then sends their keys', () async {
    final dir = await Directory.systemTemp.createTemp('mod_test');
    addTearDown(() => dir.delete(recursive: true));
    final affidavit = File('${dir.path}/affidavit.png')
      ..writeAsBytesSync([1, 2, 3]);

    final calls = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
      ..interceptors.addAll([
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(options);
            handler.next(options);
          },
        ),
        FakeBackendInterceptor(latency: Duration.zero),
      ]);
    final repository = ModificationsRepositoryImpl(
      client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
      storage: signedInUserStorage(),
    );

    final result = await repository.submit(
      ModificationSubmission(
        request: _dobChange,
        edit: _edit(_dobChange).set(RecordField.dateOfBirth, '2019-09-09'),
        paymentReference: 'REF3',
        documents: const ModificationDocuments().withFile(
          ModificationDocument.dateOfBirthAffidavit,
          AttachedFile(
            path: affidavit.path,
            name: 'affidavit.png',
            sizeBytes: 3,
          ),
        ),
      ),
    );

    expect(result, isA<Ok<String?>>());
    expect(calls.map((call) => '${call.method} ${call.path}'), [
      'GET /file-upload-url/MOD-date-of-birth-affidavit-40',
      'PUT https://demo.test/upload/MOD-date-of-birth-affidavit-40',
      'POST /modification/birth-registration',
    ]);
    final put = calls[1];
    expect(put.extra[RequestFlags.skipAuth], isTrue);
    expect(put.headers[Headers.contentTypeHeader], 'image/png');
    final body = calls.last.data as Map<String, Object?>;
    expect(body['child_age'], '2019-09-09');
    expect(body['supportingDocument'], [
      {
        'type': 'date-of-birth-affidavit',
        'file': 'modifications/MOD-date-of-birth-affidavit-40',
        'mimeType': 'image/png',
      },
    ]);
  });

  group('ModificationFormCubit', () {
    late FakeModificationsRepository repository;
    setUp(() => repository = FakeModificationsRepository());

    ModificationFormCubit build(ModificationRequest request) =>
        ModificationFormCubit(
          repository,
          request: request,
          record: sampleRecord,
          today: () => _today,
        );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'loads the states and the LGAs of the state of birth',
      build: () => build(_placeChange),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.states, hasLength(2));
        expect(cubit.state.lgasFor(RecordField.birthLga), hasLength(2));
        expect(repository.lgasAsked, ['1']);
      },
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'a new state of birth loads its LGAs',
      build: () => build(_placeChange),
      act: (cubit) => cubit.valueChanged(RecordField.birthState, '25'),
      verify: (cubit) {
        expect(cubit.state.lgasFor(RecordField.birthLga).single.label, 'Ikeja');
        expect(cubit.state.edit[RecordField.birthLga], isNull);
      },
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'Modify points out what is missing: no change, no declaration',
      build: () => build(_nameChange),
      act: (cubit) async {
        cubit.declaredChanged(true);
        await cubit.modify();
      },
      verify: (cubit) {
        expect(cubit.state.showErrors, isTrue);
        expect(repository.submitted, isEmpty);
      },
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'sends a name change with the paid reference, then clears the payment',
      build: () => build(_nameChange),
      act: (cubit) async {
        await cubit.valueChanged(RecordField.surname, 'Hassan');
        cubit.declaredChanged(true);
        await cubit.modify();
      },
      verify: (cubit) {
        final sent = repository.submitted.single;
        expect(sent.paymentReference, 'BRTPAID1');
        expect(sent.edit[RecordField.surname], 'Hassan');
        expect(sent.documents.files, isEmpty);
        expect(repository.paidFor.single, _nameChange);
        expect(repository.payment.clears, 1);
        expect(cubit.state.submitted, isTrue);
        expect(cubit.state.message, 'Submitted.');
      },
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'a date of birth goes on to its documents, which are required',
      build: () => build(_dobChange),
      act: (cubit) async {
        await cubit.valueChanged(RecordField.dateOfBirth, '2019-09-09');
        cubit.declaredChanged(true);
        await cubit.modify();
        await cubit.submitDocuments();
      },
      verify: (cubit) {
        expect(cubit.state.step, ModificationFormStep.documents);
        expect(cubit.state.showErrors, isTrue);
        expect(repository.submitted, isEmpty);
      },
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'sends the documents once the required ones are in',
      build: () => build(_dobChange),
      act: (cubit) async {
        await cubit.valueChanged(RecordField.dateOfBirth, '2019-09-09');
        cubit.declaredChanged(true);
        await cubit.modify();
        for (final type in [
          ModificationDocument.dateOfBirthAffidavit,
          ModificationDocument.requestLetter,
        ]) {
          await cubit.documentPicked(
            type,
            path: '${type.name}.jpg',
            name: '${type.name}.jpg',
            sizeBytes: 1000,
          );
        }
        await cubit.submitDocuments();
      },
      verify: (cubit) {
        final sent = repository.submitted.single;
        expect(sent.documents.files.keys, {
          ModificationDocument.dateOfBirthAffidavit,
          ModificationDocument.requestLetter,
        });
        expect(
          sent.documents[ModificationDocument.requestLetter]?.path,
          'kept/requestLetter.jpg',
        );
        // Sent, so the private copies are removed.
        expect(repository.deleted, contains('kept/requestLetter.jpg'));
      },
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'refuses a file that is too large or not a photo',
      build: () => build(_dobChange),
      act: (cubit) async {
        expect(
          await cubit.documentPicked(
            ModificationDocument.requestLetter,
            path: 'letter.pdf',
            name: 'letter.pdf',
            sizeBytes: 10,
          ),
          DocumentError.unsupportedType,
        );
        expect(
          await cubit.documentPicked(
            ModificationDocument.requestLetter,
            path: 'letter.jpg',
            name: 'letter.jpg',
            sizeBytes: SupportingDocuments.maxBytes + 1,
          ),
          DocumentError.tooLarge,
        );
      },
      verify: (cubit) => expect(cubit.state.documents.files, isEmpty),
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'without a paid fee nothing is sent',
      build: () {
        repository.payment.stored = null;
        return build(_nameChange);
      },
      act: (cubit) async {
        await cubit.valueChanged(RecordField.firstName, 'Sule');
        cubit.declaredChanged(true);
        await cubit.modify();
      },
      verify: (cubit) {
        expect(cubit.state.paymentMissing, isTrue);
        expect(repository.submitted, isEmpty);
      },
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'a failed send keeps the payment and says why',
      build: () {
        repository.submitResult = const Err(NetworkFailure());
        return build(_nameChange);
      },
      act: (cubit) async {
        await cubit.valueChanged(RecordField.firstName, 'Sule');
        cubit.declaredChanged(true);
        await cubit.modify();
      },
      verify: (cubit) {
        expect(cubit.state.failure, const NetworkFailure());
        expect(repository.payment.clears, 0);
      },
    );
  });

  group('ModificationFormView', () {
    Future<FakeModificationsRepository> pump(
      WidgetTester tester,
      ModificationRequest request, {
      VoidCallback? onDone,
    }) async {
      tester.view
        ..physicalSize = const Size(1170, 2532)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repository = FakeModificationsRepository();
      await tester.pumpApp(
        BlocProvider(
          create: (_) => ModificationFormCubit(
            repository,
            request: request,
            record: sampleRecord,
            today: () => _today,
          )..load().ignore(),
          child: ModificationFormView(onDone: onDone ?? () {}, onExit: () {}),
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    bool enabled(WidgetTester tester, String label) => tester
        .widget<TextField>(
          find.descendant(
            of: find
                .ancestor(of: find.text(label), matching: find.byType(Column))
                .first,
            matching: find.byType(TextField),
          ),
        )
        .enabled!;

    testWidgets('only the father\'s names can be edited for a father name', (
      tester,
    ) async {
      final request = const ModificationRequest(kind: ModificationKind.birth)
          .withType(ModificationType.fatherName)
          .withReason(ModificationReason.misspelledName);
      await pump(tester, request);

      expect(
        find.text(
          "Only the father's surname, first name and middle name can be "
          'modified.',
        ),
        findsOneWidget,
      );
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.where((field) => field.enabled!).length, 3);
      expect(find.text('Hasan'), findsOneWidget);
      expect(find.text('Abia'), findsOneWidget);
    });

    testWidgets('Modify is off until declared; then it sends and is done', (
      tester,
    ) async {
      var done = false;
      final repository = await pump(
        tester,
        _nameChange,
        onDone: () => done = true,
      );
      final modify = find.widgetWithText(FilledButton, 'Modify');
      expect(tester.widget<FilledButton>(modify).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'Hassan');
      await tester.scrollUntilVisible(
        find.byType(Checkbox),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(modify);
      await tester.pumpAndSettle();

      expect(find.text('Modification Request Submitted'), findsOneWidget);
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(repository.submitted.single.edit[RecordField.surname], 'Hassan');
    });

    testWidgets('a date of birth change asks for the documents', (
      tester,
    ) async {
      await pump(tester, _dobChange);
      expect(enabled(tester, 'Surname'), isFalse);

      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(Checkbox),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Modify'));
      await tester.pumpAndSettle();

      expect(find.text('Supporting Documents'), findsOneWidget);
      expect(find.text('Upload Date of Birth Affidavit'), findsOneWidget);
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(find.text('This field is required.'), findsNWidgets(2));

      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('Modify'), findsOneWidget);
    });
  });
}
