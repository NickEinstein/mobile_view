import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/data/dtos/surrogacy_dtos.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_form.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/form/cubit/surrogacy_form_cubit.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/form/view/surrogacy_form_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_surrogacy_birth_repository.dart';

final _today = DateTime(2026, 10, 4);

ParentParticulars _parent({String country = SurrogacyCodes.nigeria}) {
  var parent = const ParentParticulars()
      .set(ParentField.surname, 'Ololade')
      .set(ParentField.firstName, 'Simisola')
      .set(ParentField.maritalStatus, '1')
      .set(ParentField.address, 'No 12 Adeleke road, Lekki')
      .set(ParentField.occupation, '100')
      .set(ParentField.nationality, '63')
      .set(ParentField.country, country)
      .set(ParentField.localityType, '2');
  if (country == SurrogacyCodes.nigeria) {
    parent = parent.set(ParentField.state, '25').set(ParentField.lga, '501');
  }
  return parent;
}

SurrogateMotherParticulars _surrogate({
  String age = '28',
  String order = '1',
}) => const SurrogateMotherParticulars()
    .set(SurrogateField.surname, 'Bala')
    .set(SurrogateField.firstName, 'Michelle')
    .set(SurrogateField.ageAtBirth, age)
    .set(SurrogateField.birthOrder, order);

void main() {
  group('legal parent rules', () {
    test('the legally required fields are required', () {
      const empty = ParentParticulars();
      for (final field in ParentField.values) {
        if (!empty.applies(field)) continue;
        expect(
          empty.errorOf(field),
          field.isRequired ? SurrogacyFieldError.required : isNull,
          reason: field.name,
        );
      }
      expect(_parent().isComplete, isTrue);
    });

    test('state and LGA only for a residence in Nigeria', () {
      final abroad = _parent().set(ParentField.country, '31');
      expect(abroad[ParentField.state], isNull);
      expect(abroad.applies(ParentField.lga), isFalse);
      expect(abroad.isComplete, isTrue);
      expect(
        _parent().set(ParentField.state, null).errorOf(ParentField.state),
        SurrogacyFieldError.required,
      );
    });

    test('the level of education is asked only when literate', () {
      final parent = _parent().set(ParentField.literacy, '1');
      expect(parent.applies(ParentField.educationLevel), isTrue);
      final illiterate = parent
          .set(ParentField.educationLevel, '7')
          .set(ParentField.literacy, '2');
      expect(illiterate[ParentField.educationLevel], isNull);
      expect(illiterate.applies(ParentField.educationLevel), isFalse);
    });

    test('a typed NIN must be validated; editing it undoes that', () {
      final typed = _parent().set(ParentField.nin, '72921010909');
      expect(
        typed.errorOf(ParentField.nin),
        SurrogacyFieldError.ninNotVerified,
      );
      expect(
        _parent().set(ParentField.nin, '123').errorOf(ParentField.nin),
        SurrogacyFieldError.invalidNin,
      );
      final verified = typed.set(ParentField.verifiedNin, '72921010909');
      expect(verified.isNinVerified, isTrue);
      expect(verified.isComplete, isTrue);
      expect(
        verified.set(ParentField.nin, '72921010900').isNinVerified,
        isFalse,
      );
    });

    test('a phone number has 11 digits', () {
      expect(
        _parent().set(ParentField.phone, '0901').errorOf(ParentField.phone),
        SurrogacyFieldError.invalidPhone,
      );
      expect(
        _parent().set(ParentField.phone, '09012348349').isComplete,
        isTrue,
      );
    });
  });

  group('surrogate mother rules', () {
    test('may be left empty', () {
      expect(const SurrogateMotherParticulars().isComplete, isTrue);
    });

    test('once started, name, age and birth order are required', () {
      final started = const SurrogateMotherParticulars().set(
        SurrogateField.nationality,
        '63',
      );
      for (final field in [
        SurrogateField.surname,
        SurrogateField.firstName,
        SurrogateField.ageAtBirth,
        SurrogateField.birthOrder,
      ]) {
        expect(
          started.errorOf(field),
          SurrogacyFieldError.required,
          reason: field.name,
        );
      }
      expect(_surrogate().isComplete, isTrue);
    });

    test('the youngest age rises by one per birth before this one', () {
      SurrogacyFieldError? age(String value, String order) => _surrogate(
        age: value,
        order: order,
      ).errorOf(SurrogateField.ageAtBirth);
      expect(age('9', '1'), isNull);
      expect(age('8', '1'), SurrogacyFieldError.invalidAge);
      expect(age('10', '3'), SurrogacyFieldError.invalidAge);
      expect(age('11', '3'), isNull);
      expect(age('61', '1'), SurrogacyFieldError.invalidAge);
      expect(_surrogate(order: '3').minAgeForBirthOrder, 11);
    });

    test('state and LGA of origin only for a Nigerian', () {
      final nigerian = _surrogate()
          .set(SurrogateField.nationality, '63')
          .set(SurrogateField.stateOfOrigin, '25');
      expect(nigerian.applies(SurrogateField.lgaOfOrigin), isTrue);
      final ghanaian = nigerian.set(SurrogateField.nationality, '31');
      expect(ghanaian[SurrogateField.stateOfOrigin], isNull);
      expect(ghanaian.applies(SurrogateField.stateOfOrigin), isFalse);
    });
  });

  group('payload (the API\'s lp1 / lp2 / sm fields)', () {
    test('sends the legal mother, and no father unless named', () {
      final draft = paidDraft().copyWith(
        legalMother: _parent()
            .set(ParentField.middleName, 'Ada')
            .set(ParentField.nin, '72921010909')
            .set(ParentField.verifiedNin, '72921010909'),
        hasLegalFather: false,
        legalFather: _parent(),
      );
      final json = surrogacySectionToJson(
        draft,
        section: SurrogacySection.parents,
      );
      expect(json['section'], 2);
      expect(json['lp1FullName'], 'Ololade Simisola Ada');
      expect(json['lp1MaritalStatus'], 1);
      expect(json['lp1ResidenceCountry'], 63);
      expect(json['lp1ResidenceState'], 25);
      expect(json['lp1ResidenceLga'], 501);
      expect(json['lp1Occupation'], 100);
      expect(json['lp1Nin'], '72921010909');
      expect(json['lp1EducationLevel'], isNull);
      expect(json['lp2Present'], false);
      expect(json['lp2FullName'], isNull);
      expect(json['smFullName'], isNull);
    });

    test('a NIN not validated is not sent', () {
      final draft = paidDraft().copyWith(
        hasLegalFather: true,
        legalFather: _parent().set(ParentField.nin, '90289384945'),
        surrogateMother: _surrogate(),
      );
      final json = surrogacySectionToJson(
        draft,
        section: SurrogacySection.parents,
      );
      expect(json['lp2Present'], true);
      expect(json['lp2FullName'], 'Ololade Simisola');
      expect(json['lp2Nin'], isNull);
      expect(json['smFullName'], 'Bala Michelle');
      expect(json['smAgeAtBirth'], 28);
      expect(json['smBirthOrder'], 1);
    });
  });

  group('SurrogacyFormCubit (parents)', () {
    late FakeSurrogacyBirthRepository repository;
    setUp(() => repository = FakeSurrogacyBirthRepository());

    SurrogacyFormCubit build() =>
        SurrogacyFormCubit(repository, now: () => _today);

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      "the registration state and LGA are the registrar's",
      setUp: () => repository.draft = paidDraft(),
      build: () => SurrogacyFormCubit(
        repository,
        registrarLocation: (stateId: '19', lgaId: '249'),
        now: () => _today,
      ),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        final child = cubit.state.draft!.child;
        expect(child[ChildField.registrationState], '19');
        expect(child[ChildField.registrationLga], '249');
        expect(repository.draft!.child, child);
      },
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'a validated NIN fills the name and counts as verified',
      setUp: () =>
          repository.draft = paidDraft(step: SurrogacyStep.legalMother),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.legalParentChanged(
          SurrogacyPerson.legalMother,
          ParentField.nin,
          '12345678901',
        );
        await cubit.validateNin(SurrogacyPerson.legalMother);
      },
      verify: (cubit) {
        final mother = cubit.state.draft!.legalMother;
        expect(mother.isNinVerified, isTrue);
        expect(mother[ParentField.surname], 'Hassan');
        expect(mother[ParentField.firstName], 'Suleiman');
        expect(cubit.state.ninValidations, 1);
        expect(cubit.state.ninChecking, isNull);
      },
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'an unknown NIN shows against that person',
      setUp: () {
        repository
          ..draft = paidDraft(step: SurrogacyStep.surrogateMother)
          ..ninResult = const Err(NotFoundFailure());
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.surrogateMotherChanged(SurrogateField.nin, '12345678901');
        await cubit.validateNin(SurrogacyPerson.surrogateMother);
      },
      verify: (cubit) {
        expect(cubit.state.ninFailure?.$1, SurrogacyPerson.surrogateMother);
        expect(cubit.state.draft!.surrogateMother.isNinVerified, isFalse);
        expect(cubit.state.ninValidations, 0);
      },
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'the father step needs an answer; "No" skips his details',
      setUp: () =>
          repository.draft = paidDraft(step: SurrogacyStep.legalFather),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.next();
        cubit.hasLegalFatherChanged(named: false);
        await cubit.next();
        await cubit.flush();
      },
      verify: (cubit) {
        expect(repository.savedSections.single.$1, SurrogacySection.parents);
        expect(cubit.state.step, SurrogacyStep.surrogateMother);
      },
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'a named father must be filled in',
      setUp: () => repository.draft = paidDraft(
        step: SurrogacyStep.legalFather,
      ).copyWith(hasLegalFather: true),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.showErrors, isTrue);
        expect(cubit.state.step, SurrogacyStep.legalFather);
        expect(repository.savedSections, isEmpty);
      },
    );
  });

  group('screens', () {
    testWidgets('legal mother: Validate fills the name and says so', (
      tester,
    ) async {
      final repository = FakeSurrogacyBirthRepository()
        ..draft = paidDraft(step: SurrogacyStep.legalMother);
      await tester.pumpApp(
        SurrogacyFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 8'), findsOneWidget);
      expect(
        find.text('Particulars of Legal Parents (Mother)'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, '12345678901');
      await tester.pump();
      await tester.tap(find.text('Validate'));
      await tester.pumpAndSettle();
      expect(find.text('NIN Validated'), findsOneWidget);
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Hassan'), findsOneWidget);
    });

    testWidgets('legal father: only the question until he is named', (
      tester,
    ) async {
      final repository = FakeSurrogacyBirthRepository()
        ..draft = paidDraft(step: SurrogacyStep.legalFather);
      await tester.pumpApp(
        SurrogacyFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Is a second legal parent (Father) named in the court order?',
        ),
        findsOneWidget,
      );
      expect(find.text('Surname'), findsNothing);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(find.text('Surname'), findsOneWidget);
    });

    testWidgets('surrogate mother: an empty step can be passed', (
      tester,
    ) async {
      final repository = FakeSurrogacyBirthRepository()
        ..draft = paidDraft(step: SurrogacyStep.surrogateMother);
      await tester.pumpApp(
        SurrogacyFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 5 of 8'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 6 of 8'), findsOneWidget);
      expect(repository.savedSections.single.$1, SurrogacySection.parents);
    });
  });
}
