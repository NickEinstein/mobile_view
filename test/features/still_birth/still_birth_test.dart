import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/still_birth/data/dtos/still_birth_dtos.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_draft.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_form.dart';
import 'package:vital_reg_mobile/features/still_birth/presentation/details/view/still_birth_details_page.dart';
import 'package:vital_reg_mobile/features/still_birth/presentation/form/cubit/still_birth_form_cubit.dart';
import 'package:vital_reg_mobile/features/still_birth/presentation/form/view/still_birth_form_page.dart';
import 'package:vital_reg_mobile/features/still_birth/presentation/home/cubit/still_birth_home_cubit.dart';
import 'package:vital_reg_mobile/features/still_birth/presentation/home/view/still_birth_home_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_still_birth_repository.dart';

final _today = DateTime(2026, 10, 4);

DeceasedParticulars _deceased() => const DeceasedParticulars()
    .set(DeceasedField.placeOfOccurrence, '5')
    .set(DeceasedField.village, 'Gwarinpa')
    .set(DeceasedField.dateOfDelivery, DateTime(2026, 9, 9).toIso8601String())
    .set(DeceasedField.sex, '1')
    .set(DeceasedField.typeOfDelivery, '1');

MotherParticulars _nigerianMother() => const MotherParticulars()
    .set(MotherField.fullName, 'Ogunlade Amina')
    .set(MotherField.country, StillBirthCodes.nigeria)
    .set(MotherField.state, '5')
    .set(MotherField.lga, '51')
    .set(MotherField.address, 'No. 2')
    .set(MotherField.settlement, '1')
    .set(MotherField.age, '43')
    .set(MotherField.nationality, StillBirthCodes.nigeria)
    .set(MotherField.stateOfOrigin, '5')
    .set(MotherField.ethnicGroup, '4');

InformantParticulars _informant() => const InformantParticulars()
    .set(InformantField.relationship, '3')
    .set(InformantField.fullName, 'Allison Micheal Favour')
    .set(InformantField.country, '31')
    .set(InformantField.signature, 'sign.png');

StillBirthDraft _complete({StillBirthStep step = StillBirthStep.review}) =>
    StillBirthDraft(
      startedOn: _today,
      step: step,
      deceased: _deceased(),
      mother: _nigerianMother(),
      informant: _informant(),
    );

StillBirthFormCubit _cubit(FakeStillBirthRepository repository) =>
    StillBirthFormCubit(
      repository,
      now: () => _today,
      newSubmissionKey: () => 'key-1',
    );

void main() {
  group('rules', () {
    test('every deceased field is required; the date is checked', () {
      const empty = DeceasedParticulars();
      for (final field in DeceasedField.values) {
        expect(
          empty.errorOf(field, today: _today),
          StillBirthFieldError.required,
        );
      }
      expect(_deceased().isComplete(today: _today), isTrue);

      StillBirthFieldError? date(DateTime value) => _deceased()
          .set(DeceasedField.dateOfDelivery, value.toIso8601String())
          .errorOf(DeceasedField.dateOfDelivery, today: _today);
      expect(date(DateTime(2026, 10, 5)), StillBirthFieldError.futureDate);
      expect(date(DateTime(1992)), StillBirthFieldError.tooEarly);
      expect(date(DateTime(1992, 1, 2)), isNull);
    });

    test("the mother's age must be 10 to 60", () {
      StillBirthFieldError? age(String value) => _nigerianMother()
          .set(MotherField.age, value)
          .errorOf(MotherField.age);
      expect(age('9'), StillBirthFieldError.invalidAge);
      expect(age('61'), StillBirthFieldError.invalidAge);
      expect(age('10'), isNull);
      expect(age('60'), isNull);
    });

    test('address and origin details only apply to Nigeria', () {
      final abroad = _nigerianMother()
          .set(MotherField.country, '31')
          .set(MotherField.nationality, '31');
      for (final field in [
        MotherField.state,
        MotherField.lga,
        MotherField.address,
        MotherField.settlement,
        MotherField.stateOfOrigin,
        MotherField.ethnicGroup,
      ]) {
        expect(abroad.applies(field), isFalse, reason: field.name);
        // Cleared with the country or nationality.
        expect(abroad[field], isNull, reason: field.name);
      }
      expect(abroad.set(MotherField.age, '30').isComplete, isTrue);
      expect(
        const MotherParticulars()
            .set(MotherField.country, StillBirthCodes.nigeria)
            .errorOf(MotherField.state),
        StillBirthFieldError.required,
      );
    });

    test('a new state clears the LGA', () {
      final mother = _nigerianMother().set(MotherField.state, '6');
      expect(mother[MotherField.lga], isNull);
      expect(mother[MotherField.address], 'No. 2');
    });

    test('the informant must sign', () {
      final unsigned = _informant().set(InformantField.signature, null);
      expect(
        unsigned.errorOf(InformantField.signature),
        StillBirthFieldError.required,
      );
      expect(_informant().isComplete, isTrue);
    });
  });

  group('payload (POST /stillbirth/add)', () {
    test('sends ids as numbers and the uploaded signature', () {
      final json = stillBirthToJson(_complete(), signature: 'key/sign.png');
      expect(json['birth_place'], 5);
      expect(json['deceased_sex'], 1);
      expect(json['birth_type'], 1);
      expect(json['deceased_village'], 'Gwarinpa');
      expect(json['mother_age'], 43);
      expect(json['mother_country'], 63);
      expect(json['mother_state_residence'], 5);
      expect(json['mother_street_name'], 'No. 2');
      expect(json['mother_ethnic_group'], 4);
      expect(json['informant_relationship_with_mother'], 3);
      expect(json['informant_acknowledgement'], 'key/sign.png');
    });

    test('leaves out address details outside Nigeria', () {
      final json = stillBirthToJson(_complete(), signature: 's');
      expect(json['informant_country'], 31);
      expect(json['informant_state'], isNull);
      expect(json['informant_lga'], isNull);
      expect(json['informant_settlement'], isNull);
    });

    test('reads the list, the total and a tracking ID', () {
      final rows = registrationsFromJson({
        'result': [
          {
            'id': 7,
            'mother_fullname': 'Amina Garba',
            'date_created': '2026-08-30T10:00:00Z',
          },
        ],
        'pagination': {'page': 1},
      });
      expect(rows.single.id, '7');
      expect(rows.single.trackingId, '7');
      expect(rows.single.motherName, 'Amina Garba');
      expect(countFromJson(12), 12);
      expect(
        addedFromJson({
          'success': true,
          'item': {'id': 41},
        }),
        '41',
      );
      expect(addedFromJson({'message': 'ok'}), isNull);
    });

    test('reads a record back into the form\'s fields', () {
      // As the backend's `single`: no id, status as a code.
      final record = stillBirthRecordFromJson(id: '9', {
        'data': {
          'tracking_id': 'FA1',
          'approved_status': 1,
          'date_created': '2026-09-23',
          'birth_place': 1,
          'deceased_village': 'Amaba',
          'deceased_date_of_delivery': '2026-09-21T00:00:00.000Z',
          'deceased_sex': 2,
          'birth_type': 1,
          'mother_fullname': 'Ogunlade Amina',
          'mother_country': 63,
          'mother_state_residence': 5,
          'mother_lga': 51,
          'mother_age': 23,
          'informant_fullname': 'Ogunlade Bolaji',
          'informant_acknowledgement': 'https://files.test/sign.png',
        },
      });
      expect(record.summary.id, '9');
      expect(record.summary.status, ApplicationStatus.approved);
      expect(record.summary.trackingId, 'FA1');
      expect(record.deceased[DeceasedField.placeOfOccurrence], '1');
      expect(record.deceased.dateOfDelivery, DateTime(2026, 9, 21));
      // Kept although its country is read in the same pass.
      expect(record.mother[MotherField.lga], '51');
      expect(record.mother[MotherField.age], '23');
      expect(
        record.informant[InformantField.signature],
        'https://files.test/sign.png',
      );
    });
  });

  group('StillBirthFormCubit', () {
    late FakeStillBirthRepository repository;

    setUp(() => repository = FakeStillBirthRepository());

    test('starts a new draft, or continues the saved one', () async {
      final fresh = _cubit(repository);
      await fresh.load();
      expect(fresh.state.status, FormStatus.ready);
      expect(fresh.state.step, StillBirthStep.deceased);
      expect(fresh.state.draft!.startedOn, _today);

      repository.draft = _complete(step: StillBirthStep.mother);
      final resumed = _cubit(repository);
      await resumed.load();
      expect(resumed.state.step, StillBirthStep.mother);
    });

    test('shows a load failure', () async {
      repository.referenceResult = const Err(NetworkFailure());
      final cubit = _cubit(repository);
      await cubit.load();
      expect(cubit.state.status, FormStatus.failure);
      expect(cubit.state.failure, const NetworkFailure());
    });

    test('Next shows errors until the step is complete, then saves', () async {
      final cubit = _cubit(repository);
      await cubit.load();
      cubit.next();
      expect(cubit.state.showErrors, isTrue);
      expect(cubit.state.step, StillBirthStep.deceased);

      for (final field in DeceasedField.values) {
        cubit.deceasedChanged(field, _deceased()[field]);
      }
      cubit.next();
      await cubit.flush();
      expect(cubit.state.step, StillBirthStep.mother);
      expect(cubit.state.showErrors, isFalse);
      expect(repository.draft!.step, StillBirthStep.mother);
      expect(repository.draft!.deceased, _deceased());
    });

    test('choosing "Mother" copies her name and address', () async {
      repository.draft = _complete(
        step: StillBirthStep.informant,
      ).copyWith(informant: const InformantParticulars());
      final cubit = _cubit(repository);
      await cubit.load();
      cubit.informantChanged(
        InformantField.relationship,
        StillBirthCodes.motherRelationship,
      );
      final informant = cubit.state.draft!.informant;
      expect(informant[InformantField.fullName], 'Ogunlade Amina');
      expect(informant[InformantField.country], StillBirthCodes.nigeria);
      expect(informant[InformantField.state], '5');
      expect(informant[InformantField.lga], '51');
      expect(informant[InformantField.address], 'No. 2');
      expect(informant[InformantField.settlement], '1');
    });

    test(
      'a new signature replaces the old file; clearing deletes it',
      () async {
        repository.draft = _complete(step: StillBirthStep.informant);
        final cubit = _cubit(repository);
        await cubit.load();
        await cubit.signatureDrawn(Uint8List(4));
        expect(
          cubit.state.draft!.informant[InformantField.signature],
          'signature-1.png',
        );
        expect(repository.deleted, ['sign.png']);

        await cubit.signatureCleared();
        expect(cubit.state.draft!.informant[InformantField.signature], isNull);
        expect(repository.deleted, ['sign.png', 'signature-1.png']);
      },
    );

    test('Edit on the preview returns to it after Next', () async {
      repository.draft = _complete();
      final cubit = _cubit(repository);
      await cubit.load();
      cubit.editStep(StillBirthStep.mother);
      expect(cubit.state.step, StillBirthStep.mother);
      cubit.next();
      expect(cubit.state.step, StillBirthStep.review);
    });

    blocTest<StillBirthFormCubit, StillBirthFormState>(
      'submitting needs the declaration',
      setUp: () => repository.draft = _complete(),
      build: () => _cubit(repository),
      act: (cubit) async {
        await cubit.load();
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.showErrors, isTrue);
        expect(repository.submitted, isEmpty);
      },
    );

    test('submits once with a stored key, then clears the draft', () async {
      repository.draft = _complete();
      final cubit = _cubit(repository);
      await cubit.load();
      cubit.declarationChanged(declared: true);
      await cubit.submit();
      expect(repository.submitted.single.submissionKey, 'key-1');
      expect(cubit.state.submitStatus, SubmitStatus.submitted);
      expect(cubit.state.trackingId, 'SB123');
      expect(repository.draft, isNull);
    });

    test('a failed submission keeps the draft and its key', () async {
      repository
        ..draft = _complete()
        ..submitResult = const Err(ServerFailure(statusCode: 500));
      final cubit = _cubit(repository);
      await cubit.load();
      cubit.declarationChanged(declared: true);
      await cubit.submit();
      expect(cubit.state.submitStatus, SubmitStatus.failed);
      expect(cubit.state.submitFailure, const ServerFailure(statusCode: 500));
      expect(repository.draft!.submissionKey, 'key-1');
    });
  });

  group('StillBirthHomeCubit', () {
    test('loads the total and the list; searching filters', () async {
      final repository = FakeStillBirthRepository();
      final cubit = StillBirthHomeCubit(repository, searchDelay: Duration.zero);
      await cubit.load();
      expect(cubit.state.total, 3);
      expect(cubit.state.items, sampleRegistrations);

      cubit.queryChanged(' Sofia ');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(repository.searches.last, 'Sofia');
    });
  });

  group('screens', () {
    testWidgets('home shows the total and registrations', (tester) async {
      await tester.pumpApp(
        StillBirthHomePage(
          onOpenForm: () async {},
          onOpenRegistration: (_) async {},
          repository: FakeStillBirthRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Still Birth Registration'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Total Registration'), findsOneWidget);
      expect(find.text('Michael Lee'), findsOneWidget);
      expect(find.text('Sofia Martinez'), findsOneWidget);
    });

    testWidgets('a row opens its details, also from ⋮', (tester) async {
      final opened = <String>[];
      await tester.pumpApp(
        StillBirthHomePage(
          onOpenForm: () async {},
          onOpenRegistration: (id) async => opened.add(id),
          repository: FakeStillBirthRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Michael Lee'));
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(opened, ['1', '2']);
    });

    testWidgets('Certificate Details shows the record read-only', (
      tester,
    ) async {
      await tester.pumpApp(
        StillBirthDetailsPage(id: '1', repository: FakeStillBirthRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Certificate Details'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Hospital'), findsOneWidget);
      expect(find.text('Amaba'), findsOneWidget);
      expect(find.text('Ogunlade Bolaji'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('offers to continue an unfinished registration', (
      tester,
    ) async {
      final repository = FakeStillBirthRepository()
        ..draft = _complete(step: StillBirthStep.mother);
      var opened = 0;
      await tester.pumpApp(
        StillBirthHomePage(
          onOpenForm: () async => opened++,
          onOpenRegistration: (_) async {},
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person_add_alt));
      await tester.pumpAndSettle();
      expect(find.text('Continue your application?'), findsOneWidget);
      await tester.tap(find.text('Start new'));
      await tester.pumpAndSettle();
      expect(repository.draft, isNull);
      expect(opened, 1);
    });

    testWidgets('step 1 asks for the deceased and shows what is missing', (
      tester,
    ) async {
      await tester.pumpApp(
        StillBirthFormPage(
          onExit: () {},
          repository: FakeStillBirthRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Particulars of Deceased'), findsWidgets);
      expect(find.text('Place of Occurrence'), findsOneWidget);
      expect(find.text('Date of Delivery'), findsOneWidget);
      expect(find.text('Type of Delivery'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsWidgets);
    });

    testWidgets('a foreign residence hides the Nigerian address fields', (
      tester,
    ) async {
      final repository = FakeStillBirthRepository()
        ..draft = StillBirthDraft(
          startedOn: _today,
          step: StillBirthStep.mother,
          mother: const MotherParticulars().set(MotherField.country, '31'),
        );
      await tester.pumpApp(
        StillBirthFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Country'), findsOneWidget);
      expect(find.text('LGA'), findsNothing);
      expect(find.text('Place of settlement'), findsNothing);
    });

    testWidgets('the preview lists every step with Edit', (tester) async {
      final repository = FakeStillBirthRepository()..draft = _complete();
      await tester.pumpApp(
        StillBirthFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 4 of 4'), findsOneWidget);
      expect(find.text('Gwarinpa'), findsOneWidget);
      expect(find.text('Bus'), findsOneWidget);
      expect(find.text('Ogunlade Amina'), findsOneWidget);
      expect(find.text('Allison Micheal Favour'), findsOneWidget);
      expect(find.text('Edit'), findsNWidgets(3));
      expect(find.text('Submit'), findsOneWidget);
    });
  });
}
