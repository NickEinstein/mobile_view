import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_select_field.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/face_verifier.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/data/reissuance_repository_impl.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/birth_form/cubit/birth_reissuance_form_cubit.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/birth_form/view/birth_reissuance_form_page.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_reissuance_repository.dart';

final _certificate = LegacyCertificate(
  kind: ReissuanceKind.birth,
  number: 'CR1',
  issuedOn: DateTime(2010),
  filePath: 'old.jpg',
  fileName: 'old.jpg',
  sizeBytes: 10,
);

ReissuanceDraft _draft({BirthReissuanceForm? form}) => ReissuanceDraft(
  startedOn: DateTime(2026, 10, 4),
  mode: ValidationMode.nin,
  ninRecord: ninRecord,
  facePhoto: 'face.jpg',
  certificate: _certificate,
  birthForm: form,
);

/// A complete child, born in Bauchi and registered there.
final _child = const ChildParticulars()
    .set(ChildField.surname, 'Ogunlade')
    .set(ChildField.firstName, 'Bolaji')
    .set(ChildField.dateOfBirth, DateTime(2016, 3, 12).toIso8601String())
    .set(ChildField.typeOfBirth, '1')
    .set(ChildField.birthOrder, '1')
    .set(ChildField.sex, '1')
    .set(ChildField.placeOfOccurrence, '1')
    .set(ChildField.stateOfBirth, '5')
    .set(ChildField.lgaOfBirth, '51')
    .set(ChildField.locality, '1')
    .set(ChildField.registrationState, '5')
    .set(ChildField.registrationLga, '51')
    .set(ChildField.registrationCenter, '510');

/// A complete Nigerian, literate mother living in Bauchi.
ParentParticulars _parent({bool maiden = true}) {
  var parent = const ParentParticulars()
      .set(ParentDetail.surname, 'Ogunlade')
      .set(ParentDetail.firstName, 'Amina')
      .set(ParentDetail.country, '63')
      .set(ParentDetail.state, '5')
      .set(ParentDetail.lga, '51')
      .set(ParentDetail.address, 'No 2 Agwada Str')
      .set(ParentDetail.age, '30')
      .set(ParentDetail.maritalStatus, '1')
      .set(ParentDetail.nationality, '63')
      .set(ParentDetail.stateOfOrigin, '5')
      .set(ParentDetail.lgaOfOrigin, '51')
      .set(ParentDetail.ethnicGroup, '4')
      .set(ParentDetail.literacy, '1')
      .set(ParentDetail.educationLevel, '9')
      .set(ParentDetail.occupation, '3')
      .set(ParentDetail.phone, '08130845852');
  if (maiden) parent = parent.set(ParentDetail.maidenName, 'Alice');
  return parent;
}

void main() {
  group('rules', () {
    test('the child: required fields, a birth by the commission date', () {
      expect(_child.isComplete, isTrue);
      expect(
        _child.set(ChildField.middleName, null).isComplete,
        isTrue,
        reason: 'middle name, town of birth and origin are optional',
      );
      expect(
        _child.set(ChildField.locality, null).errorOf(ChildField.locality),
        ReissuanceFieldError.required,
      );
      final late = _child.set(
        ChildField.dateOfBirth,
        DateTime(2023, 11, 9).toIso8601String(),
      );
      expect(
        late.errorOf(ChildField.dateOfBirth),
        ReissuanceFieldError.tooLate,
      );
    });

    test('a new state clears its LGA; a registration LGA its centre', () {
      final child = _child
          .set(ChildField.stateOfBirth, '25')
          .set(ChildField.registrationLga, '52');
      expect(child[ChildField.lgaOfBirth], isNull);
      expect(child[ChildField.registrationCenter], isNull);
      expect(child[ChildField.registrationState], '5');
    });

    test("the mother's youngest age rises with the birth order", () {
      expect(ParentParticulars.ageRange(ParentRole.mother, birthOrder: 1), (
        9,
        60,
      ));
      expect(ParentParticulars.ageRange(ParentRole.mother, birthOrder: 4), (
        12,
        60,
      ));
      expect(ParentParticulars.ageRange(ParentRole.father), (10, 90));
      final mother = _parent().set(ParentDetail.age, '11');
      expect(
        mother.errorOf(ParentDetail.age, ParentRole.mother, birthOrder: 4),
        ReissuanceFieldError.invalidAge,
      );
      expect(
        mother.errorOf(ParentDetail.age, ParentRole.mother, birthOrder: 1),
        isNull,
      );
    });

    test('a phone number is 11 to 15 digits', () {
      for (final (phone, ok) in [
        ('0813084585', false),
        ('08130845852', true),
        ('234813084585212', true),
        ('2348130845852123', false),
      ]) {
        expect(
          _parent()
              .set(ParentDetail.phone, phone)
              .errorOf(ParentDetail.phone, ParentRole.mother),
          ok ? isNull : ReissuanceFieldError.invalidPhone,
          reason: phone,
        );
      }
    });

    test('LGAs only in Nigeria; education only when literate', () {
      final abroad = _parent()
          .set(ParentDetail.country, '31')
          .set(ParentDetail.state, '901')
          .set(ParentDetail.nationality, '31')
          .set(ParentDetail.stateOfOrigin, '901')
          .set(ParentDetail.literacy, '2');
      expect(abroad[ParentDetail.lga], isNull);
      expect(abroad[ParentDetail.educationLevel], isNull);
      expect(abroad.applies(ParentDetail.lga, ParentRole.mother), isFalse);
      expect(
        abroad.applies(ParentDetail.lgaOfOrigin, ParentRole.mother),
        isFalse,
      );
      expect(
        abroad.applies(ParentDetail.educationLevel, ParentRole.mother),
        isFalse,
      );
      expect(abroad.isComplete(ParentRole.mother), isTrue);
    });

    test('only the mother has a maiden name', () {
      final father = _parent(maiden: false);
      expect(father.isComplete(ParentRole.father), isTrue);
      expect(father.isComplete(ParentRole.mother), isFalse);
    });

    test("'same as mother's' copies her residence; no clears his", () {
      final mother = _parent();
      final same = const ParentParticulars().sameResidenceAs(
        mother,
        same: true,
      );
      for (final field in ParentDetail.residence) {
        expect(same[field], mother[field], reason: field.name);
      }
      final notSame = same.sameResidenceAs(mother, same: false);
      expect(notSame[ParentDetail.sameResidenceAsMother], 'no');
      for (final field in ParentDetail.residence) {
        expect(notSame[field], isNull, reason: field.name);
      }
    });

    test('a draft with a form reads back the same', () {
      final draft = _draft(
        form: BirthReissuanceForm(
          step: BirthReissuanceStep.father,
          child: _child,
          mother: _parent(),
        ),
      );
      expect(ReissuanceDraft.fromJson(draft.toJson()), draft);
    });
  });

  group('BirthReissuanceFormCubit', () {
    late FakeReissuanceRepository repository;
    setUp(() => repository = FakeReissuanceRepository()..draft = _draft());

    BirthReissuanceFormCubit build() => BirthReissuanceFormCubit(repository);

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      "a new form starts with the NIN's names and sex, and is saved",
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.flush();
      },
      verify: (cubit) {
        final child = cubit.state.form!.child;
        expect(cubit.state.status, FormStatus.ready);
        expect(child[ChildField.surname], 'Ogunlade');
        expect(child[ChildField.firstName], 'Bolaji');
        expect(child[ChildField.sex], ReissuanceCodes.male);
        expect(repository.draft?.birthForm, cubit.state.form);
        expect(cubit.state.statesOf('63'), hasLength(2));
      },
    );

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      'a resumed form loads the places its answers use',
      setUp: () => repository.draft = _draft(
        form: BirthReissuanceForm(
          step: BirthReissuanceStep.mother,
          child: _child,
          mother: _parent()
              .set(ParentDetail.nationality, '31')
              .set(ParentDetail.stateOfOrigin, '901'),
        ),
      ),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.step, BirthReissuanceStep.mother);
        expect(repository.statesAsked.toSet(), {'63', '31'});
        expect(repository.lgasAsked.toSet(), {'5', '901'});
        expect(cubit.state.lgasOf('5'), [const Option('51', 'Bogoro')]);
      },
    );

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      "can't open without a certificate",
      setUp: () => repository.draft = ReissuanceDraft(
        startedOn: DateTime(2026, 10, 4),
        mode: ValidationMode.nin,
        ninRecord: ninRecord,
      ),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.status, FormStatus.missing),
    );

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      'choosing a state or a country loads what it offers',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit
          ..childChanged(ChildField.registrationState, '25')
          ..parentChanged(ParentRole.mother, ParentDetail.country, '31');
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.lgasOf('25'), [const Option('251', 'Ikeja')]);
        expect(cubit.state.statesOf('31'), [
          const Option('901', 'Greater Accra'),
        ]);
      },
    );

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      'Next on an incomplete step shows the errors and stays',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.showErrors, isTrue);
        expect(cubit.state.step, BirthReissuanceStep.child);
      },
    );

    blocTest<BirthReissuanceFormCubit, BirthReissuanceFormState>(
      'complete steps move on, and back; the step is saved',
      setUp: () => repository.draft = _draft(
        form: BirthReissuanceForm(child: _child, mother: _parent()),
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit
          ..next()
          ..next();
        expect(cubit.state.step, BirthReissuanceStep.father);
        cubit
          ..sameResidenceAsMother(same: true)
          ..previous();
        await cubit.flush();
      },
      verify: (cubit) {
        expect(cubit.state.step, BirthReissuanceStep.mother);
        expect(repository.draft?.birthForm?.step, BirthReissuanceStep.mother);
        expect(
          repository.draft?.birthForm?.father[ParentDetail.address],
          'No 2 Agwada Str',
        );
      },
    );
  });

  test('the demo backend serves the form options on the API paths', () async {
    final paths = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
      ..interceptors.addAll([
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paths.add(options.path);
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

    T ok<T>(Result<T> result) => (result as Ok<T>).value;
    final options = ok(await repository.options());
    final ghana = ok(await repository.states('31'));
    final lgas = ok(await repository.lgas('15'));
    // Cached: no second request.
    await repository.options();
    await repository.lgas('15');

    expect(options.nationalities.map((o) => o.label), contains('Nigerian'));
    expect(options.birthOrders, hasLength(20));
    expect(options.centresIn('151').single.label, 'AMAC Registration Centre');
    expect(ghana, isNotEmpty);
    expect(lgas.map((o) => o.label), ['AMAC', 'Bwari']);
    // Only places from the API, no list endpoint.
    expect(options.sexes.first.label, 'Male');
    expect(paths.toSet(), {
      '/option/country',
      '/option/registration-centres',
      '/option/states/31',
      '/option/lga/15',
    });
    expect(paths, hasLength(4));
  });

  group('form page', () {
    Future<FakeReissuanceRepository> pumpForm(
      WidgetTester tester, {
      BirthReissuanceForm? form,
    }) async {
      tester.view
        ..physicalSize = const Size(400, 4000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = FakeReissuanceRepository()..draft = _draft(form: form);
      await tester.pumpApp(
        BirthReissuanceFormPage(repository: repository, onExit: () {}),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('step 1: the NIN names, the sex locked, errors on Save', (
      tester,
    ) async {
      await pumpForm(tester);

      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Particulars of Child'), findsWidgets);
      expect(find.text('Ogunlade'), findsOneWidget);
      final sex = tester.widget<AppSelectField<String>>(
        find.byKey(const ValueKey(ChildField.sex)),
      );
      expect(sex.value, '1');
      expect(sex.onChanged, isNull);

      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsWidgets);
      expect(find.text('Step 1 of 5'), findsOneWidget);
    });

    testWidgets("the father's 'same as mother's' fills in his address", (
      tester,
    ) async {
      await pumpForm(
        tester,
        form: BirthReissuanceForm(
          step: BirthReissuanceStep.father,
          child: _child,
          mother: _parent(),
        ),
      );

      expect(find.text('Is it the same as mother\'s?'), findsOneWidget);
      expect(find.text('Maiden Name'), findsNothing);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(find.text('No 2 Agwada Str'), findsOneWidget);
      expect(find.text('Previous'), findsOneWidget);
    });
  });
}
