import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/modifications/data/dtos/modification_dtos.dart';
import 'package:vital_reg_mobile/features/modifications/data/modifications_repository_impl.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_submission.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/queried_modification.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/record_edit.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/form/cubit/modification_form_cubit.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/form/view/modification_form_page.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_modifications_repository.dart';

final _today = DateTime(2026, 10, 4);

ModificationRequest _applicant(ModificationField field) =>
    const ModificationRequest(kind: ModificationKind.attestation)
        .withType(ModificationType.applicantParticulars)
        .withField(field)
        .withReason(field.reasons.first);

ModificationRequest _deceased(ModificationType type) =>
    const ModificationRequest(kind: ModificationKind.death).withType(type);

const _attestation = ModificationRecord(
  kind: ModificationKind.attestation,
  recordId: '41',
  certificateNumber: 'BA1',
  name: 'Hassan Suleiman',
  values: {
    RecordField.surname: 'Hassan',
    RecordField.firstName: 'Suleiman',
    RecordField.dateOfBirth: '1990-03-14',
    RecordField.sex: '1',
    RecordField.birthState: '1',
    RecordField.birthLga: '11',
    RecordField.originState: '25',
    RecordField.originLga: '251',
    RecordField.originTown: 'Ikeja',
    RecordField.motherSurname: 'Hassan',
    RecordField.fatherSurname: 'Hassan',
    RecordField.fatherFirstName: 'Musa',
  },
);

const _death = ModificationRecord(
  kind: ModificationKind.death,
  recordId: '42',
  certificateNumber: 'DR1',
  name: 'Ade Bola',
  values: {
    RecordField.surname: 'Ade',
    RecordField.firstName: 'Bola',
    RecordField.sex: '2',
    RecordField.ageAtDeath: '70',
    RecordField.dateOfDeath: '2025-02-04',
  },
);

RecordEdit _edit(ModificationRecord record, ModificationRequest request) =>
    RecordEdit.start(record, request.editableFields);

void main() {
  group('changes', () {
    test('each attestation and death change unlocks its own fields', () {
      expect(
        _applicant(ModificationField.applicantStateOfOrigin).editableFields,
        {
          RecordField.originState,
          RecordField.originLga,
          RecordField.originTown,
        },
      );
      expect(
        const ModificationRequest(
          kind: ModificationKind.attestation,
        ).withType(ModificationType.applicantFatherName).editableFields,
        {RecordField.fatherSurname, RecordField.fatherFirstName},
      );
      expect(_deceased(ModificationType.deceasedName).editableFields, {
        RecordField.surname,
        RecordField.firstName,
        RecordField.middleName,
      });
      expect(_deceased(ModificationType.deceasedAgeAtDeath).editableFields, {
        RecordField.ageAtDeath,
      });
      // Death has no fields to choose: its type is the field.
      expect(_deceased(ModificationType.deceasedSex).apiField, 'deceased_sex');
    });

    test(
      'a new state of origin clears its LGA; ages and dates are checked',
      () {
        final origin = _edit(
          _attestation,
          _applicant(ModificationField.applicantStateOfOrigin),
        ).set(RecordField.originState, '1');
        expect(origin[RecordField.originLga], isNull);
        expect(origin[RecordField.birthLga], '11');

        final age = _edit(
          _death,
          _deceased(ModificationType.deceasedAgeAtDeath),
        );
        expect(
          age
              .set(RecordField.ageAtDeath, '170')
              .errorOf(RecordField.ageAtDeath, today: _today),
          RecordEditError.invalidAge,
        );
        expect(
          age.set(RecordField.ageAtDeath, '71').isValid(today: _today),
          isTrue,
        );

        final date = _edit(
          _death,
          _deceased(ModificationType.deceasedDateOfDeath),
        ).set(RecordField.dateOfDeath, '2026-10-05');
        expect(
          date.errorOf(RecordField.dateOfDeath, today: _today),
          RecordEditError.futureDate,
        );
      },
    );
  });

  group('DTOs', () {
    test('reads attestation and death records', () {
      final attestation = recordFromJson(
        {
          'data': {
            'id': 41,
            'attestation_number': 'BA1',
            'personData': {
              'surname': 'Hassan',
              'birth_date': '1990-03-14T00:00:00.000Z',
              'gender': 1,
              'origin_state': 25,
              'origin_lga': 251,
              'town_of_origin': 'Ikeja',
            },
            'mother_maiden_name': 'Bello',
            'father_firstname': 'Musa',
          },
        },
        kind: ModificationKind.attestation,
        certificateNumber: 'BA1',
      )!;
      expect(attestation.recordId, '41');
      expect(attestation[RecordField.dateOfBirth], '1990-03-14');
      expect(attestation[RecordField.originLga], '251');
      expect(attestation[RecordField.motherMiddleName], 'Bello');
      expect(attestation[RecordField.fatherFirstName], 'Musa');

      final death = recordFromJson(
        {
          'data': {
            'id': 42,
            'death_certificate_number': 'DR1',
            'deceasedData': {'surname': 'Ade', 'gender': 2},
            'deceased_age_at_death': 70,
            'deceased_date_of_death': '2025-02-04T00:00:00.000Z',
          },
        },
        kind: ModificationKind.death,
        certificateNumber: 'DR1',
      )!;
      expect(death.recordId, '42');
      expect(death[RecordField.ageAtDeath], '70');
      expect(death[RecordField.dateOfDeath], '2025-02-04');
      expect(death[RecordField.sex], '2');
    });

    test('sends attestation changes', () {
      final name = _applicant(ModificationField.applicantName);
      expect(
        submissionToJson(
          ModificationSubmission(
            request: name,
            edit: _edit(_attestation, name).set(RecordField.surname, 'Hasan'),
            paymentReference: 'R1',
          ),
        ),
        {
          'attestation_id': 41,
          'mod_type': 'particulars_of_applicant',
          'mod_field': 'applicant_name',
          'mod_reason': 'misspelling of name',
          'reference': 'R1',
          'attestation_surname': 'Hasan',
          'applicant_surname': 'Hasan',
          'attestation_firstname': 'Suleiman',
          'applicant_firstname': 'Suleiman',
        },
      );

      final dob = _applicant(ModificationField.applicantDateOfBirth);
      final dobJson = submissionToJson(
        ModificationSubmission(
          request: dob,
          edit: _edit(
            _attestation,
            dob,
          ).set(RecordField.dateOfBirth, '1991-03-14'),
          paymentReference: 'R2',
        ),
      );
      expect(dobJson['applicant_age'], '1991-03-14');
      expect(dobJson['mod_field'], 'applicant_dob');

      final origin = _applicant(ModificationField.applicantStateOfOrigin);
      final originJson = submissionToJson(
        ModificationSubmission(
          request: origin,
          edit: _edit(_attestation, origin)
              .set(RecordField.originState, '1')
              .set(RecordField.originLga, '12')
              .set(RecordField.originTown, 'Umuahia'),
          paymentReference: 'R3',
        ),
      );
      expect(originJson['applicant_state_of_origin'], 1);
      expect(originJson['applicant_lga_of_origin'], 12);
      expect(originJson['applicant_town_of_origin'], 'Umuahia');
    });

    test('sends death changes', () {
      final age = _deceased(ModificationType.deceasedAgeAtDeath);
      expect(
        submissionToJson(
          ModificationSubmission(
            request: age,
            edit: _edit(_death, age).set(RecordField.ageAtDeath, '71'),
            paymentReference: 'R4',
          ),
        ),
        {
          'death_id': 42,
          'mod_type': 'deceased_age_at_death',
          'mod_field': 'deceased_age_at_death',
          'mod_reason': 'incorrect age at entered',
          'reference': 'R4',
          'deceased_age_at_death': 71,
        },
      );
    });

    test('reads queried attestation and death requests', () {
      final attestation = queriedFromJson({
        'data': {
          'id': 41,
          'attestation_number': 'BA1',
          'Modification': [
            {
              'id': 5,
              'reference': 'R5',
              'mod_type': 'particulars_of_applicant',
              'mod_field': 'applicant_name',
              'mod_reason': 'misspelling of name',
              'applicant_surname': 'Hasan',
            },
          ],
          'SupportingDocument': [
            {'type': 'request-letter', 'file': 'k1'},
          ],
        },
        'queried': {'reason': 'Check the surname.'},
      }, kind: ModificationKind.attestation)!;
      expect(attestation.id, '5');
      expect(attestation.record.recordId, '41');
      expect(attestation.record.certificateNumber, 'BA1');
      expect(attestation.record[RecordField.surname], 'Hasan');
      expect(attestation.documents, hasLength(1));

      final death = queriedFromJson({
        'data': {
          'id': 42,
          'Modification': [
            {
              'id': 6,
              'reference': 'R6',
              'mod_type': 'deceased_date_of_death',
              'mod_field': 'deceased_date_of_death',
              'mod_reason': 'incorrect date of death',
              'deceased_date_of_death': '2025-02-03T00:00:00.000Z',
            },
          ],
        },
      }, kind: ModificationKind.death)!;
      expect(death.request.type, ModificationType.deceasedDateOfDeath);
      expect(death.request.reason, ModificationReason.incorrectDateOfDeath);
      expect(death.record[RecordField.dateOfDeath], '2025-02-03');
    });
  });

  test('the demo backend answers attestation and death', () async {
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

    final record = await repository.findRecord(
      ModificationKind.attestation,
      'BA1',
    );
    expect(
      (record as Ok<ModificationRecord>).value[RecordField.originTown],
      'Ikeja',
    );

    final queried = await repository.queried(ModificationKind.death, 'q-0');
    final death = (queried as Ok<QueriedModification>).value;
    expect(death.request.type, ModificationType.deceasedAgeAtDeath);
    final resent = await repository.submit(
      ModificationSubmission(
        request: death.request,
        edit: RecordEdit.start(
          death.record,
          death.request.editableFields,
        ).set(RecordField.ageAtDeath, '70'),
        paymentReference: death.paymentReference,
        modificationId: death.id,
      ),
    );
    expect(resent, isA<Ok<String?>>());
    expect(calls.last, 'PATCH /modification/death-registration');
  });

  group('ModificationFormCubit', () {
    late FakeModificationsRepository repository;
    setUp(() => repository = FakeModificationsRepository());

    blocTest<ModificationFormCubit, ModificationFormState>(
      'an attestation loads the LGAs of its states of birth and origin',
      build: () => ModificationFormCubit(
        repository,
        request: _applicant(ModificationField.applicantStateOfOrigin),
        record: _attestation,
        today: () => _today,
      ),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(repository.lgasAsked, ['1', '25']);
        expect(
          cubit.state.lgasFor(RecordField.originLga).single.label,
          'Ikeja',
        );
        expect(cubit.state.lgasFor(RecordField.birthLga), hasLength(2));
      },
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'a death record needs no option lists',
      build: () => ModificationFormCubit(
        repository,
        request: _deceased(ModificationType.deceasedSex),
        record: _death,
        today: () => _today,
      ),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.states, isEmpty);
        expect(repository.lgasAsked, isEmpty);
      },
    );

    blocTest<ModificationFormCubit, ModificationFormState>(
      'an attestation date of birth goes on to its documents',
      build: () => ModificationFormCubit(
        repository,
        request: _applicant(ModificationField.applicantDateOfBirth),
        record: _attestation,
        today: () => _today,
      ),
      act: (cubit) async {
        await cubit.valueChanged(RecordField.dateOfBirth, '1991-03-14');
        cubit.declaredChanged(true);
        await cubit.modify();
      },
      verify: (cubit) {
        expect(cubit.state.step, ModificationFormStep.documents);
        expect(repository.submitted, isEmpty);
      },
    );
  });

  group('views', () {
    Future<FakeModificationsRepository> pump(
      WidgetTester tester,
      ModificationRequest request,
      ModificationRecord record,
    ) async {
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
            record: record,
            today: () => _today,
          )..load().ignore(),
          child: ModificationFormView(onDone: () {}, onExit: () {}),
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('the death form edits the age at death only', (tester) async {
      final repository = await pump(
        tester,
        _deceased(ModificationType.deceasedAgeAtDeath),
        _death,
      );

      expect(find.text('Particulars of the Deceased'), findsOneWidget);
      expect(
        find.text('Only the age at death can be modified.'),
        findsOneWidget,
      );
      expect(find.text('Date of Death'), findsOneWidget);
      expect(find.text('Particulars of Mother'), findsNothing);
      final enabled = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((field) => field.enabled!);
      expect(enabled.single.controller?.text, '70');

      await tester.enterText(find.text('70'), '71');
      await tester.scrollUntilVisible(
        find.byType(Checkbox),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Modify'));
      await tester.pumpAndSettle();

      expect(repository.submitted.single.edit[RecordField.ageAtDeath], '71');
      expect(find.text('Modification Request Submitted'), findsOneWidget);
    });

    testWidgets('the attestation form has the applicant and origin', (
      tester,
    ) async {
      await pump(
        tester,
        _applicant(ModificationField.applicantStateOfOrigin),
        _attestation,
      );

      expect(find.text('Particulars of Applicant'), findsOneWidget);
      expect(
        find.text(
          "Only the applicant's state, LGA and town of origin can be modified.",
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Town/Village of Origin'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ikeja'), findsNWidgets(2));
    });
  });
}
