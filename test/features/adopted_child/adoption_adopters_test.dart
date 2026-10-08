import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/adopted_child/data/dtos/adoption_dtos.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_draft.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_form.dart';
import 'package:vital_reg_mobile/features/adopted_child/presentation/form/cubit/adoption_form_cubit.dart';
import 'package:vital_reg_mobile/features/adopted_child/presentation/form/view/adoption_form_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_adopted_child_repository.dart';

final _today = DateTime(2026, 10, 4);

void main() {
  group('adopter rules', () {
    test('NIN, name, marital status, nationality, address and occupation '
        'are required; the residence is not', () {
      const empty = AdopterParticulars();
      for (final field in AdopterField.values) {
        if (!empty.applies(field)) continue;
        expect(
          empty.errorOf(field),
          field.isRequired ? AdoptionFieldError.required : isNull,
          reason: field.name,
        );
      }
      expect(completeAdopter().isComplete(), isTrue);
    });

    test('the NIN must be 11 digits and validated; editing it undoes that', () {
      final short = completeAdopter().set(AdopterField.nin, '123');
      expect(short.errorOf(AdopterField.nin), AdoptionFieldError.invalidNin);
      final edited = completeAdopter().set(AdopterField.nin, '11111111111');
      expect(edited.isNinVerified, isFalse);
      expect(
        edited.errorOf(AdopterField.nin),
        AdoptionFieldError.ninNotVerified,
      );
    });

    test('state and LGA only for Nigeria; education only when literate', () {
      final abroad = completeAdopter().set(AdopterField.country, '31');
      expect(abroad.applies(AdopterField.state), isFalse);
      final home = completeAdopter()
          .set(AdopterField.country, '63')
          .set(AdopterField.state, '25')
          .set(AdopterField.lga, '501');
      expect(home.applies(AdopterField.lga), isTrue);
      expect(home.set(AdopterField.country, '31')[AdopterField.state], isNull);
      expect(
        completeAdopter()
            .set(AdopterField.literacy, '1')
            .applies(AdopterField.educationLevel),
        isTrue,
      );
    });

    test('a phone number has 11 digits', () {
      expect(
        completeAdopter()
            .set(AdopterField.phone, '0912')
            .errorOf(AdopterField.phone),
        AdoptionFieldError.invalidPhone,
      );
    });

    test('adopter 2 may be left empty, but once started it is checked', () {
      const empty = AdopterParticulars();
      expect(empty.isComplete(optional: true), isTrue);
      expect(empty.isComplete(), isFalse);
      final started = empty.set(AdopterField.surname, 'Ololade');
      expect(started.isComplete(optional: true), isFalse);
      expect(
        started.errorOf(AdopterField.nin, optional: true),
        AdoptionFieldError.required,
      );
    });

    test('every adoption order field is required; the date is checked', () {
      for (final field in AdoptionDetailsField.values) {
        expect(
          const AdoptionDetails().errorOf(field, today: _today),
          AdoptionFieldError.required,
        );
      }
      expect(completeDetails().isComplete(today: _today), isTrue);
      expect(
        completeDetails()
            .set(
              AdoptionDetailsField.orderDate,
              DateTime(2027).toIso8601String(),
            )
            .errorOf(AdoptionDetailsField.orderDate, today: _today),
        AdoptionFieldError.futureDate,
      );
    });

    test('the draft keeps the adopters and details through JSON', () {
      final draft = paidDraft(step: AdoptionStep.adoptionDetails).copyWith(
        adopter1: completeAdopter(),
        adopter2: const AdopterParticulars().set(AdopterField.surname, 'A'),
        details: completeDetails(),
      );
      expect(AdoptionDraft.fromJson(draft.toJson()), draft);
      expect(draft.hasAdopter2, isTrue);
    });
  });

  group('section payload', () {
    test('adopters go as ad1/ad2 with a joined full name and the state name '
        'as text', () {
      final draft = paidDraft().copyWith(
        child: completeChild(),
        adopter1: completeAdopter()
            .set(AdopterField.middleName, 'Ade')
            .set(AdopterField.country, '63')
            .set(AdopterField.state, '25')
            .set(AdopterField.lga, '501')
            .set(AdopterField.localityType, '2')
            .set(AdopterField.literacy, '2')
            .set(AdopterField.phone, '09012348349'),
        details: completeDetails(),
      );
      final json = adoptionSectionToJson(
        draft,
        section: AdoptionSection.parents,
        stateName: (id) => id == '25' ? 'Lagos' : null,
      );
      expect(json['section'], 2);
      expect(json['ad1FullName'], 'Ololade Semiola Ade');
      expect(json['ad1Nin'], '72921010909');
      expect(json['ad1MaritalStatus'], 1);
      expect(json['ad1Nationality'], 63);
      expect(json['ad1Occupation'], 100);
      expect(json['ad1ResidenceCountry'], 63);
      expect(json['ad1ResidenceState'], 25);
      expect(json['ad1ResidenceLga'], 501);
      expect(json['ad1StateProvince'], 'Lagos');
      expect(json['ad1ResidenceStateProvince'], 'Lagos');
      expect(json['ad1LocalityType'], 2);
      expect(json['ad1LiteracyLevel'], 2);
      expect(json['ad1EducationLevel'], isNull);
      expect(json['ad1Phone'], '09012348349');
      expect(json['ad2Present'], isFalse);
      expect(json['ad2FullName'], isNull);
      expect(json['courtName'], 'Federal High Court');
      expect(json['orderReferenceNo'], 'FCT/HC/CV/1889/2026');
      expect(json['adoptionOrderDate'], '2025-09-09');
      expect(json['adoptionType'], 'domestic');
    });

    test('an unvalidated NIN is not sent', () {
      final draft = paidDraft().copyWith(
        adopter1: completeAdopter().set(AdopterField.nin, '11111111111'),
      );
      final json = adoptionSectionToJson(
        draft,
        section: AdoptionSection.parents,
        stateName: (_) => null,
      );
      expect(json['ad1Nin'], isNull);
    });
  });

  group('AdoptionFormCubit', () {
    late FakeAdoptedChildRepository repository;
    setUp(() => repository = FakeAdoptedChildRepository());

    AdoptionFormCubit build() =>
        AdoptionFormCubit(repository, now: () => _today);

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'validating an adopter NIN fills the name and marks it verified',
      setUp: () => repository.draft = paidDraft(step: AdoptionStep.adopter1),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.adopterChanged(Adopter.first, AdopterField.nin, '12345678901');
        await cubit.validateNin(Adopter.first);
      },
      verify: (cubit) {
        final adopter = cubit.state.draft!.adopter1;
        expect(adopter.isNinVerified, isTrue);
        expect(adopter[AdopterField.surname], 'Hassan');
        expect(adopter[AdopterField.firstName], 'Suleiman');
        expect(cubit.state.ninValidations, 1);
        expect(cubit.state.ninChecking, isNull);
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'an unknown NIN shows on that adopter until the NIN is edited',
      setUp: () {
        repository
          ..draft = paidDraft(step: AdoptionStep.adopter2)
          ..ninResult = const Err(NotFoundFailure());
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.adopterChanged(Adopter.second, AdopterField.nin, '12345678901');
        await cubit.validateNin(Adopter.second);
        expect(cubit.state.ninFailure?.$1, Adopter.second);
        expect(cubit.state.draft!.adopter2.isNinVerified, isFalse);
        cubit.adopterChanged(Adopter.second, AdopterField.nin, '1234567890');
      },
      verify: (cubit) => expect(cubit.state.ninFailure, isNull),
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'an empty adopter 2 is skipped; the parents section is saved',
      setUp: () => repository.draft = paidDraft(
        step: AdoptionStep.adopter2,
      ).copyWith(child: completeChild(), adopter1: completeAdopter()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.next();
      },
      verify: (cubit) {
        expect(repository.savedSections.single.$1, AdoptionSection.parents);
        expect(cubit.state.step, AdoptionStep.adoptionDetails);
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'adoption details save section 3 and move to the informant',
      setUp: () =>
          repository.draft = paidDraft(step: AdoptionStep.adoptionDetails),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit
          ..detailsChanged(AdoptionDetailsField.courtName, 'Federal High Court')
          ..detailsChanged(AdoptionDetailsField.orderReference, 'FCT/1')
          ..detailsChanged(
            AdoptionDetailsField.adoptionType,
            AdoptionCodes.interCountry,
          )
          ..orderDateChanged(DateTime(2025, 9, 9, 15));
        await cubit.next();
      },
      verify: (cubit) {
        final (section, saved) = repository.savedSections.single;
        expect(section, AdoptionSection.adoptionDetails);
        expect(
          saved.details[AdoptionDetailsField.orderDate],
          '2025-09-09T00:00:00.000',
        );
        expect(cubit.state.step, AdoptionStep.informant);
      },
    );
  });

  group('screens', () {
    testWidgets('adopter 1 asks for the NIN and validates it', (tester) async {
      final repository = FakeAdoptedChildRepository()
        ..draft = paidDraft(step: AdoptionStep.adopter1);
      await tester.pumpApp(
        AdoptionFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 7'), findsOneWidget);
      expect(find.text('Particulars of Adopter 1'), findsOneWidget);
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

    testWidgets('adopter 2 is optional: Next goes on when it is empty', (
      tester,
    ) async {
      final repository = FakeAdoptedChildRepository()
        ..draft = paidDraft(
          step: AdoptionStep.adopter2,
        ).copyWith(adopter1: completeAdopter());
      await tester.pumpApp(
        AdoptionFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Particulars of Adopter 2 (Optional)'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 4 of 7'), findsWidgets);
      expect(find.text('Court Name'), findsOneWidget);
      expect(find.text('Type of Adoption'), findsOneWidget);
    });

    testWidgets('the type of adoption offers the two backend values', (
      tester,
    ) async {
      final repository = FakeAdoptedChildRepository()
        ..draft = paidDraft(step: AdoptionStep.adoptionDetails);
      await tester.pumpApp(
        AdoptionFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Select an option'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select an option'));
      await tester.pumpAndSettle();
      expect(find.text('Domestic Adoption'), findsWidgets);
      expect(find.text('Inter-Country Adoption'), findsWidgets);
    });
  });
}
