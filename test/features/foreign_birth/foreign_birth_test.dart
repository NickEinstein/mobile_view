import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/foreign_birth/data/dtos/foreign_birth_dtos.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_draft.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_form.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/form/cubit/foreign_birth_form_cubit.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/form/view/foreign_birth_form_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_foreign_birth_repository.dart';

final _today = DateTime(2026, 10, 4);

void main() {
  group('child rules', () {
    test('everything but the middle name and the face is required', () {
      const empty = ChildParticulars();
      for (final field in ChildField.values) {
        expect(
          empty.errorOf(field, today: _today),
          field.isRequired ? ForeignBirthFieldError.required : isNull,
          reason: field.name,
        );
      }
      expect(
        ChildField.values.where((f) => !f.isRequired),
        unorderedEquals([ChildField.middleName, ChildField.facePhoto]),
      );
      expect(completeChild().isComplete(today: _today), isTrue);
    });

    test('the date of birth cannot be in the future', () {
      expect(
        completeChild()
            .set(
              ChildField.dateOfBirth,
              DateTime(2026, 10, 5).toIso8601String(),
            )
            .errorOf(ChildField.dateOfBirth, today: _today),
        ForeignBirthFieldError.futureDate,
      );
    });

    test('a new country of birth clears the state of birth', () {
      final child = completeChild().set(ChildField.countryOfBirth, '31');
      expect(child[ChildField.stateOfBirth], isNull);
    });

    test('Nigeria is not offered as the country of birth', () {
      expect(sampleReferenceData.birthCountries.map((c) => c.id), ['181']);
      expect(sampleReferenceData.isoCodeOf('181'), 'GB');
    });
  });

  group('parent rules (with the backend\'s)', () {
    test(
      'a Nigerian needs a validated NIN, LGA of origin and ethnic group',
      () {
        final mother = completeMother();
        expect(mother.isComplete(Parent.mother), isTrue);
        expect(
          mother
              .set(ParentField.lgaOfOrigin, null)
              .errorOf(ParentField.lgaOfOrigin, Parent.mother),
          ForeignBirthFieldError.required,
        );
        expect(
          mother
              .set(ParentField.ethnicGroup, null)
              .errorOf(ParentField.ethnicGroup, Parent.mother),
          ForeignBirthFieldError.required,
        );
        final unverified = mother.set(ParentField.nin, '11111111111');
        expect(unverified[ParentField.verifiedNin], isNull);
        expect(
          unverified.errorOf(ParentField.nin, Parent.mother),
          ForeignBirthFieldError.ninNotVerified,
        );
        expect(
          mother
              .set(ParentField.nin, null)
              .errorOf(ParentField.nin, Parent.mother),
          ForeignBirthFieldError.required,
        );
      },
    );

    test('anyone else may leave the NIN out, but a typed one must be '
        'validated', () {
      final father = completeFather();
      expect(father.isComplete(Parent.father), isTrue);
      expect(father.applies(ParentField.lgaOfOrigin, Parent.father), isFalse);
      expect(father.applies(ParentField.ethnicGroup, Parent.father), isFalse);
      expect(
        father
            .set(ParentField.nin, '12345678901')
            .errorOf(ParentField.nin, Parent.father),
        ForeignBirthFieldError.ninNotVerified,
      );
    });

    test('a new nationality clears the origin and the NIN', () {
      final mother = completeMother().set(ParentField.nationality, '181');
      expect(mother[ParentField.stateOfOrigin], isNull);
      expect(mother[ParentField.lgaOfOrigin], isNull);
      expect(mother[ParentField.ethnicGroup], isNull);
      expect(mother[ParentField.nin], isNull);
    });

    test('an LGA of residence only in Nigeria', () {
      expect(
        completeFather()
            .set(ParentField.country, '63')
            .errorOf(ParentField.lga, Parent.father),
        ForeignBirthFieldError.required,
      );
      expect(completeFather().errorOf(ParentField.lga, Parent.father), isNull);
    });

    test('maiden name and occupation are the mother\'s only', () {
      const empty = ParentParticulars();
      expect(
        empty.errorOf(ParentField.maidenName, Parent.mother),
        ForeignBirthFieldError.required,
      );
      expect(
        empty.errorOf(ParentField.occupation, Parent.mother),
        ForeignBirthFieldError.required,
      );
      expect(empty.errorOf(ParentField.maidenName, Parent.father), isNull);
      expect(empty.errorOf(ParentField.occupation, Parent.father), isNull);
    });

    test('the level of education only when literate', () {
      final literate = completeFather().set(ParentField.literacy, '1');
      expect(
        literate.errorOf(ParentField.educationLevel, Parent.father),
        ForeignBirthFieldError.required,
      );
      expect(
        literate
            .set(ParentField.educationLevel, '7')
            .set(ParentField.literacy, '2')[ParentField.educationLevel],
        isNull,
      );
    });

    test('ages: mother 10–60, father 10–90 (the backend refuses under 10)', () {
      ForeignBirthFieldError? age(Parent parent, String value) =>
          const ParentParticulars()
              .set(ParentField.age, value)
              .errorOf(ParentField.age, parent);
      expect(age(Parent.mother, '9'), ForeignBirthFieldError.invalidAge);
      expect(age(Parent.mother, '10'), isNull);
      expect(age(Parent.mother, '61'), ForeignBirthFieldError.invalidAge);
      expect(age(Parent.father, '90'), isNull);
      expect(age(Parent.father, '91'), ForeignBirthFieldError.invalidAge);
    });

    test('a phone number, if given, has 11 to 15 digits', () {
      ForeignBirthFieldError? phone(String value) => completeFather()
          .set(ParentField.phone, value)
          .errorOf(ParentField.phone, Parent.father);
      expect(phone('0812345678'), ForeignBirthFieldError.invalidPhone);
      expect(phone('08123456789'), isNull);
      expect(phone('234812345678901'), isNull);
      expect(phone('2348123456789012'), ForeignBirthFieldError.invalidPhone);
    });

    test('a verified NIN locks the name until the NIN changes', () {
      final mother = completeMother();
      expect(mother.isLocked(ParentField.surname), isTrue);
      expect(mother.isLocked(ParentField.maidenName), isFalse);
      expect(
        mother
            .set(ParentField.nin, '22222222222')
            .isLocked(ParentField.surname),
        isFalse,
      );
    });

    test("the same residence copies the mother's", () {
      final father = const ParentParticulars().copyResidenceFrom(
        completeMother(),
      );
      expect(father[ParentField.country], '63');
      expect(father[ParentField.state], '25');
      expect(father[ParentField.lga], '501');
      expect(father[ParentField.address], 'No 12 Adeleke road, Lekki');
    });
  });

  group('draft', () {
    test('picks up at the payment, then the form', () {
      final started = ForeignBirthDraft(startedOn: _today);
      expect(started.stage, ForeignBirthStage.payment);
      expect(
        started.copyWith(paymentReference: 'P').stage,
        ForeignBirthStage.form,
      );
    });

    test('one parent must be Nigerian', () {
      final draft = paidDraft().copyWith(father: completeFather());
      expect(draft.hasNigerianParent, isFalse);
      expect(
        draft.copyWith(mother: completeMother()).hasNigerianParent,
        isTrue,
      );
    });

    test('survives a round trip through JSON', () {
      final draft = paidDraft(step: ForeignBirthStep.father).copyWith(
        child: completeChild().set(ChildField.facePhoto, '/face.jpg'),
        mother: completeMother(),
        father: completeFather(),
      );
      expect(ForeignBirthDraft.fromJson(draft.toJson()), draft);
    });
  });

  group("API shapes (the backend's)", () {
    test('stats are SQL sums; downloaded counts as printed', () {
      final counts = countsFromJson({
        'Pending': '2',
        'Approved': 3,
        'Queried': null,
        'Downloaded': '1',
        'total': '6',
      });
      expect(counts.of(ApplicationStatus.pending), 2);
      expect(counts.of(ApplicationStatus.approved), 3);
      expect(counts.of(ApplicationStatus.queried), 0);
      expect(counts.of(ApplicationStatus.printed), 1);
    });

    test('list rows show the child and the notification number', () {
      final rows = applicationsFromJson({
        'result': [
          {
            'id': 520,
            'notification_number': 'GB261004512',
            'reference': 'BN-7731',
            'approved_status': 2,
            'date_registered': '2026-09-23T10:00:00.000Z',
            'childData': {
              'firstname': 'Amina',
              'surname': 'Garba',
              'middle_name': null,
            },
          },
          {
            'id': 521,
            'reference': 'BN-7732',
            'approved_status': 9,
            'date_registered': '2026-09-20',
          },
        ],
      }, requested: ApplicationStatus.pending);
      // Opened by notification number.
      expect(rows.first.id, 'GB261004512');
      expect(rows.first.childName, 'Garba Amina');
      expect(rows.first.trackingId, 'GB261004512');
      expect(rows.first.status, ApplicationStatus.queried);
      expect(rows.last.childName, 'BN-7732');
      expect(rows.last.status, ApplicationStatus.pending);
    });

    test('countries carry their ISO code, sorted by name', () {
      final countries = countriesFromJson([
        {
          'Country_Code': 181,
          'Country_Name': 'United Kingdom',
          'Country_Nationality_Name': 'British',
          'Alpfa_2_Code': 'gb',
        },
        {
          'Country_Code': 31,
          'Country_Name': 'Ghana',
          'Country_Nationality_Name': 'Ghanaian',
        },
      ]);
      expect(countries.map((c) => c.option.label), ['Ghana', 'United Kingdom']);
      expect(countries.last.isoCode, 'GB');
      expect(countries.last.nationality.label, 'British');
      expect(countries.first.isoCode, isNull);
    });
  });

  group('ForeignBirthFormCubit', () {
    late FakeForeignBirthRepository repository;
    setUp(() => repository = FakeForeignBirthRepository());
    ForeignBirthFormCubit build() =>
        ForeignBirthFormCubit(repository, now: () => _today);

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'needs the fee paid',
      setUp: () => repository.payments.stored = null,
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.status, FormStatus.notPaid);
        expect(repository.draft, isNull);
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'starts the notification on the device with the paid reference',
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.status, FormStatus.ready);
        expect(repository.draft!.paymentReference, 'BRTPAID1');
        expect(repository.draft!.startedOn, _today);
        expect(cubit.state.step, ForeignBirthStep.child);
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'offers to try again when the lists cannot load',
      setUp: () => repository.referenceResult = const Err(NetworkFailure()),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.status, FormStatus.failure);
        expect(cubit.state.failure, isA<NetworkFailure>());
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'loads the states of a chosen country, and the LGAs of a Nigerian '
      'state',
      setUp: () =>
          repository.draft = paidDraft().copyWith(mother: completeMother()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.childChanged(ChildField.countryOfBirth, '181');
        await pumpEventQueue();
      },
      verify: (cubit) {
        expect(cubit.state.statesOf('181').map((o) => o.label), [
          'England',
          'Scotland',
        ]);
        expect(cubit.state.statesOf('63').single.label, 'Lagos');
        expect(cubit.state.lgasOf('25').single.label, 'Agege');
        // Each is asked for once.
        expect(repository.statesAsked, unorderedEquals(['63', '181']));
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'reports places it could not load',
      setUp: () {
        repository
          ..draft = paidDraft()
          ..statesFailure = const Err(NetworkFailure());
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.childChanged(ChildField.countryOfBirth, '181');
        await pumpEventQueue();
      },
      verify: (cubit) {
        expect(cubit.state.placesFailure, isA<NetworkFailure>());
        expect(cubit.state.statesOf('181'), isEmpty);
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'an incomplete step shows its errors and stays',
      setUp: () => repository.draft = paidDraft(),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.showErrors, isTrue);
        expect(cubit.state.step, ForeignBirthStep.child);
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'a finished step moves on and is kept on the device',
      setUp: () =>
          repository.draft = paidDraft().copyWith(child: completeChild()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.next();
        await cubit.flush();
      },
      verify: (cubit) {
        expect(cubit.state.step, ForeignBirthStep.mother);
        expect(repository.draft!.step, ForeignBirthStep.mother);
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'the father step needs a Nigerian parent',
      setUp: () =>
          repository.draft = paidDraft(step: ForeignBirthStep.father).copyWith(
            child: completeChild(),
            mother: completeMother().set(ParentField.nationality, '181'),
            father: completeFather(),
          ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.showErrors, isTrue);
        expect(cubit.state.step, ForeignBirthStep.father);
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'a validated NIN fills and locks the name',
      setUp: () =>
          repository.draft = paidDraft(step: ForeignBirthStep.mother).copyWith(
            mother: const ParentParticulars()
                .set(ParentField.nationality, '63')
                .set(ParentField.nin, '90289384945'),
          ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.validateNin(Parent.mother);
        cubit.parentChanged(Parent.mother, ParentField.surname, 'Other');
      },
      verify: (cubit) {
        final mother = cubit.state.draft!.mother;
        expect(mother.isNinVerified, isTrue);
        expect(mother[ParentField.surname], 'Ololade');
        expect(mother[ParentField.firstName], 'Adegoke');
        expect(cubit.state.ninValidations, 1);
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'an unknown NIN is reported and not verified',
      setUp: () {
        repository
          ..draft = paidDraft(step: ForeignBirthStep.mother).copyWith(
            mother: const ParentParticulars().set(
              ParentField.nin,
              '00000000000',
            ),
          )
          ..ninResult = const Err(NotFoundFailure());
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.validateNin(Parent.mother);
      },
      verify: (cubit) {
        expect(cubit.state.ninFailure?.$1, Parent.mother);
        expect(cubit.state.ninFailure?.$2, isA<NotFoundFailure>());
        expect(cubit.state.draft!.mother.isNinVerified, isFalse);
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      "\"Yes\" to the same residence copies the mother's",
      setUp: () => repository.draft = paidDraft(
        step: ForeignBirthStep.father,
      ).copyWith(mother: completeMother()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.parentChanged(
          Parent.father,
          ParentField.sameResidence,
          Answer.yes,
        );
      },
      verify: (cubit) {
        final father = cubit.state.draft!.father;
        expect(father[ParentField.country], '63');
        expect(father[ParentField.lga], '501');
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'a new photo replaces the old one',
      setUp: () => repository.draft = paidDraft().copyWith(
        child: completeChild().set(ChildField.facePhoto, '/old.jpg'),
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.childPhotoCaptured('/new.jpg');
      },
      verify: (cubit) => expect(
        cubit.state.draft!.child[ChildField.facePhoto],
        'kept//new.jpg',
      ),
    );
  });

  group('screens', () {
    testWidgets('the form opens on Particulars of Child, step 1 of 6', (
      tester,
    ) async {
      final repository = FakeForeignBirthRepository()..draft = paidDraft();
      await tester.pumpApp(
        ForeignBirthFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Foreign Birth Notification'), findsOneWidget);
      expect(find.text('Step 1 of 6'), findsOneWidget);
      expect(find.text('Particulars of Child'), findsWidgets);
      expect(find.text('Save & Continue'), findsOneWidget);
    });

    testWidgets('Save & Continue on an empty step shows what is missing', (
      tester,
    ) async {
      final repository = FakeForeignBirthRepository()..draft = paidDraft();
      await tester.pumpApp(
        ForeignBirthFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsWidgets);
      expect(find.text('Step 1 of 6'), findsOneWidget);
    });

    testWidgets('a finished child step moves to the mother', (tester) async {
      final repository = FakeForeignBirthRepository()
        ..draft = paidDraft().copyWith(child: completeChild());
      await tester.pumpApp(
        ForeignBirthFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 6'), findsOneWidget);
      expect(find.text('Particulars of Mother'), findsWidgets);
      expect(find.text('Maiden Name'), findsOneWidget);
    });

    testWidgets("the father step asks about the mother's residence", (
      tester,
    ) async {
      final repository = FakeForeignBirthRepository()
        ..draft = paidDraft(step: ForeignBirthStep.father);
      await tester.pumpApp(
        ForeignBirthFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Particulars of Father'), findsWidgets);
      expect(find.text('Maiden Name'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Is the place of residence the same as that of Mother?'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.text('Is the place of residence the same as that of Mother?'),
        findsOneWidget,
      );
    });

    testWidgets('an unpaid notification cannot be filled in', (tester) async {
      final repository = FakeForeignBirthRepository()..payments.stored = null;
      await tester.pumpApp(
        ForeignBirthFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          "The notification fee hasn't been paid. Go back and pay to continue.",
        ),
        findsOneWidget,
      );
    });
  });
}
