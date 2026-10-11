import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/person_fields.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/form/cubit/registration_form_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/nin_check/cubit/nin_check_cubit.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';

import 'fake_birth_registration_repository.dart';
import 'sample_data.dart';

final _today = DateTime(2026, 9, 29);

void main() {
  group('ChildParticulars', () {
    test('everything but the middle name is required', () {
      const empty = ChildParticulars();
      expect(
        empty.errorOf(ChildField.surname, today: _today),
        ChildFieldError.required,
      );
      expect(empty.errorOf(ChildField.middleName, today: _today), isNull);
      expect(completeChild().isComplete(today: _today), isTrue);
    });

    test('rejects a future date of birth and anyone 18 or older', () {
      final future = completeChild().set(
        ChildField.dateOfBirth,
        DateTime(2026, 10, 1).toIso8601String(),
      );
      final adult = completeChild().set(
        ChildField.dateOfBirth,
        DateTime(2008, 9, 29).toIso8601String(),
      );
      final seventeen = completeChild().set(
        ChildField.dateOfBirth,
        DateTime(2008, 9, 30).toIso8601String(),
      );

      expect(
        future.errorOf(ChildField.dateOfBirth, today: _today),
        ChildFieldError.futureDate,
      );
      expect(
        adult.errorOf(ChildField.dateOfBirth, today: _today),
        ChildFieldError.notAChild,
      );
      expect(seventeen.errorOf(ChildField.dateOfBirth, today: _today), isNull);
    });

    test('changing a state clears the choices that depended on it', () {
      final child = completeChild().set(ChildField.registrationState, 'new');

      expect(child[ChildField.registrationLga], isNull);
      expect(child[ChildField.registrationCenter], isNull);
      expect(child[ChildField.stateOfOrigin], 'value');
    });
  });

  group('ParentParticulars', () {
    test('a valid mother is complete; NIN and phone are optional', () {
      final mother = completeParent()
          .set(ParentField.nin, null)
          .set(ParentField.phone, null);
      expect(mother.isComplete(ParentRole.mother), isTrue);
    });

    test('checks NIN, phone and age formats', () {
      final parent = completeParent()
          .set(ParentField.nin, '123')
          .set(ParentField.phone, '12')
          .set(ParentField.age, '7');
      const role = ParentRole.mother;
      expect(
        parent.errorOf(ParentField.nin, role),
        PersonFieldError.invalidNin,
      );
      expect(
        parent.errorOf(ParentField.phone, role),
        PersonFieldError.invalidPhone,
      );
      expect(
        parent.errorOf(ParentField.age, role),
        PersonFieldError.invalidAge,
      );
    });

    test('maiden name is asked of the mother only', () {
      final parent = completeParent().set(ParentField.maidenName, null);
      expect(
        parent.errorOf(ParentField.maidenName, ParentRole.mother),
        PersonFieldError.required,
      );
      expect(parent.isComplete(ParentRole.father), isTrue);
    });

    test('a father living with the mother skips his residence', () {
      final father = completeParent()
          .set(ParentField.sameResidenceAsMother, answerYes)
          .set(ParentField.address, null)
          .set(ParentField.country, null);
      expect(father.isComplete(ParentRole.father), isTrue);
      expect(father.isComplete(ParentRole.mother), isFalse);
    });

    test('state and LGA only apply in Nigeria', () {
      final abroad = completeParent().set(ParentField.country, 'gh');
      expect(abroad[ParentField.state], isNull);
      expect(abroad.applies(ParentField.state, ParentRole.mother), isFalse);
      expect(abroad.isComplete(ParentRole.mother), isTrue);

      final foreigner = completeParent().set(ParentField.nationality, 'gh');
      expect(foreigner[ParentField.lgaOfOrigin], isNull);
      expect(foreigner[ParentField.ethnicGroup], isNull);
      expect(foreigner.isComplete(ParentRole.mother), isTrue);
    });

    test('education is asked of a literate parent only', () {
      final literate = completeParent().set(
        ParentField.literacy,
        ReferenceData.literate,
      );
      expect(
        literate
            .set(ParentField.educationLevel, null)
            .errorOf(ParentField.educationLevel, ParentRole.mother),
        PersonFieldError.required,
      );
      final illiterate = literate.set(ParentField.literacy, '2');
      expect(illiterate[ParentField.educationLevel], isNull);
      expect(illiterate.isComplete(ParentRole.mother), isTrue);
    });
  });

  group('InformantParticulars', () {
    test('needs a NIN only when no parent gave one', () {
      final informant = informantWithoutId();
      expect(informant.isComplete(parentsGaveNin: true), isTrue);
      expect(
        informant.errorOf(InformantField.nin, parentsGaveNin: false),
        PersonFieldError.informantNinRequired,
      );
      // The API needs a NIN from someone; a tracking ID doesn't count.
      expect(
        informant
            .set(InformantField.trackingId, 'TRK123456789012')
            .isComplete(parentsGaveNin: false),
        isFalse,
      );
      expect(
        informant
            .set(InformantField.nin, '12345678901')
            .isComplete(parentsGaveNin: false),
        isTrue,
      );
    });

    test('a tracking ID has 15 characters', () {
      final informant = informantWithoutId();
      expect(
        informant
            .set(InformantField.trackingId, 'TRK123')
            .errorOf(InformantField.trackingId, parentsGaveNin: true),
        PersonFieldError.invalidTrackingId,
      );
      expect(
        informant
            .set(InformantField.trackingId, 'TRK123456789012')
            .errorOf(InformantField.trackingId, parentsGaveNin: true),
        isNull,
      );
    });

    test('asks for the proof of identity that was chosen', () {
      final signed = informantWithoutId();
      final byFace = signed.set(
        InformantField.identityMode,
        IdentityMode.face.name,
      );
      expect(byFace.isComplete(parentsGaveNin: true), isFalse);
      expect(
        byFace.errorOf(InformantField.facePhoto, parentsGaveNin: true),
        PersonFieldError.required,
      );
      expect(
        byFace
            .set(InformantField.facePhoto, 'face.jpg')
            .isComplete(parentsGaveNin: true),
        isTrue,
      );
    });
  });

  group('RegistrationDraft', () {
    test("asks for a passport for each parent who isn't Nigerian", () {
      final draft = completeDraft(_today);
      expect(draft.documentTypes, isNot(contains(DocumentType.fatherPassport)));
      expect(draft.documentsComplete, isTrue);

      final foreignFather = draft.copyWith(
        father: draft.father.set(ParentField.nationality, '31'),
      );
      expect(
        foreignFather.documentTypes,
        contains(DocumentType.fatherPassport),
      );
      expect(
        foreignFather.isDocumentMissing(DocumentType.fatherPassport),
        isTrue,
      );
      expect(foreignFather.documentsComplete, isFalse);
    });

    test('a child of 5 or older needs the fee paid', () {
      ChildParticulars bornOn(DateTime date) =>
          completeChild().set(ChildField.dateOfBirth, date.toIso8601String());
      final draft = completeDraft(_today);
      expect(draft.isPaidFor(_today), isTrue);
      final fifthBirthdayTomorrow = draft.copyWith(
        child: bornOn(DateTime(2021, 9, 30)),
      );
      expect(fifthBirthdayTomorrow.child.ageOn(_today), 4);
      expect(fifthBirthdayTomorrow.isPaidFor(_today), isTrue);
      final five = draft.copyWith(child: bornOn(DateTime(2021, 9, 29)));
      expect(five.isPaidFor(_today), isFalse);
      expect(
        five.copyWith(paymentReference: 'BR-PAID').isPaidFor(_today),
        isTrue,
      );
    });
  });

  test('a draft survives a save and reload', () {
    final draft = RegistrationDraft(
      startedOn: _today,
      childHasNin: true,
      childNin: '12345678901',
      step: RegistrationStep.mother,
      child: completeChild(),
      mother: completeParent(),
      father: const ParentParticulars({ParentField.surname: 'Allison'}),
      informant: informantWithoutId(),
    );

    expect(RegistrationDraft.fromJson(draft.toJson()), draft);
    expect(draft.toString(), isNot(contains('12345678901')));
  });

  group('NinCheckCubit', () {
    late FakeBirthRegistrationRepository repository;

    setUp(() => repository = FakeBirthRegistrationRepository());

    NinCheckCubit build() => NinCheckCubit(repository, now: () => _today);

    blocTest<NinCheckCubit, NinCheckState>(
      'without a NIN it starts the draft straight away',
      build: build,
      act: (cubit) async {
        cubit.answered(false);
        await cubit.proceed();
      },
      verify: (cubit) {
        expect(cubit.state.isDone, isTrue);
        expect(repository.draft?.childHasNin, isFalse);
        expect(repository.draft?.childNin, isNull);
      },
    );

    blocTest<NinCheckCubit, NinCheckState>(
      'a NIN must have 11 digits before it can be validated',
      build: build,
      act: (cubit) => cubit
        ..answered(true)
        ..ninChanged('12345'),
      verify: (cubit) => expect(cubit.state.canProceed, isFalse),
    );

    blocTest<NinCheckCubit, NinCheckState>(
      'a rejected NIN shows the error and starts nothing',
      setUp: () =>
          repository.ninResult = const Err(ValidationFailure(message: 'x')),
      build: build,
      act: (cubit) async {
        cubit
          ..answered(true)
          ..ninChanged('00000000000');
        await cubit.proceed();
      },
      verify: (cubit) {
        expect(cubit.state.isDone, isFalse);
        expect(cubit.state.failure, isA<ValidationFailure>());
        expect(repository.draft, isNull);
      },
    );

    blocTest<NinCheckCubit, NinCheckState>(
      'a valid NIN is kept in the draft',
      build: build,
      act: (cubit) async {
        cubit
          ..answered(true)
          ..ninChanged('12345678901');
        await cubit.proceed();
      },
      verify: (_) {
        final draft = repository.draft;
        expect(draft?.childNin, '12345678901');
        // Filled in from the NIN's record.
        expect(draft?.child[ChildField.surname], 'Ogunlade');
        expect(draft?.child[ChildField.middleName], 'Favour');
        expect(draft?.child.dateOfBirth, DateTime(2016, 3, 12));
        expect(draft?.child[ChildField.sex], '2');
      },
    );
  });

  group('NinCheckCubit offline', () {
    late FakeBirthRegistrationRepository repository;

    setUp(
      () => repository = FakeBirthRegistrationRepository()
        // Would fail if it were asked.
        ..ninResult = const Err(NetworkFailure()),
    );

    blocTest<NinCheckCubit, NinCheckState>(
      'keeps the NIN unchecked and starts the draft',
      build: () => NinCheckCubit(repository, offline: true, now: () => _today),
      act: (cubit) async {
        cubit
          ..answered(true)
          ..ninChanged('12345678901');
        await cubit.proceed();
      },
      verify: (cubit) {
        expect(cubit.state.isDone, isTrue);
        expect(repository.draft?.childNin, '12345678901');
        expect(repository.draft?.child, const ChildParticulars());
      },
    );
  });

  group('RegistrationFormCubit', () {
    late FakeBirthRegistrationRepository repository;

    setUp(() {
      repository = FakeBirthRegistrationRepository()
        ..draft = RegistrationDraft(startedOn: _today, childHasNin: false);
    });

    RegistrationFormCubit build() =>
        RegistrationFormCubit(repository, now: () => _today);

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      "the registration state and LGA are the registrar's",
      setUp: () => repository.draft = RegistrationDraft(
        startedOn: _today,
        child: const ChildParticulars({
          ChildField.registrationState: '1',
          ChildField.registrationLga: '2',
          ChildField.registrationCenter: '3',
        }),
      ),
      build: () => RegistrationFormCubit(
        repository,
        registrarLocation: (stateId: '19', lgaId: '249'),
        now: () => _today,
      ),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        final child = cubit.state.draft!.child;
        expect(child[ChildField.registrationState], '19');
        expect(child[ChildField.registrationLga], '249');
        // The old centre belonged to the old LGA.
        expect(child[ChildField.registrationCenter], isNull);
        expect(repository.draft?.child, child);
      },
    );

    test('locatedAt keeps the centre when the LGA is already right', () {
      const child = ChildParticulars({
        ChildField.registrationState: '19',
        ChildField.registrationLga: '249',
        ChildField.registrationCenter: '1723',
      });
      expect(child.locatedAt((stateId: '19', lgaId: '249')), child);
    });

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      'an incomplete Step 1 shows errors instead of moving on',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.step, RegistrationStep.child);
        expect(cubit.state.showErrors, isTrue);
      },
    );

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      'every change is saved, and a complete step moves on',
      build: build,
      act: (cubit) async {
        await cubit.load();
        for (final MapEntry(:key, :value) in completeChild().values.entries) {
          cubit.childChanged(key, value);
        }
        cubit.next();
        await cubit.flush();
      },
      verify: (cubit) {
        expect(cubit.state.step, RegistrationStep.mother);
        expect(repository.draft?.step, RegistrationStep.mother);
        expect(repository.saves, ChildField.values.length + 1);
      },
    );

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      'the mother step moves on once complete',
      setUp: () => repository.draft = RegistrationDraft(
        startedOn: _today,
        step: RegistrationStep.mother,
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        for (final MapEntry(:key, :value) in completeParent().values.entries) {
          cubit.parentChanged(ParentRole.mother, key, value);
        }
        cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.step, RegistrationStep.father);
        expect(cubit.state.draft?.father, const ParentParticulars());
      },
    );

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      "a state's LGAs are asked for once, when it is chosen",
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit
          ..childChanged(ChildField.stateOfBirth, '15')
          ..childChanged(ChildField.surname, 'Ogunlade')
          ..parentChanged(ParentRole.mother, ParentField.state, '15');
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) => expect(repository.lgaRequests, [
        <String>{},
        {'15'},
      ]),
    );

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      'a state whose LGAs fail to load is flagged until a retry works',
      build: build,
      act: (cubit) async {
        await cubit.load();
        repository.lgaFailure = const NetworkFailure();
        cubit.childChanged(ChildField.stateOfOrigin, '15');
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.lgasUnavailable, {'15'});
        repository.lgaFailure = null;
        await cubit.retryLgas();
      },
      verify: (cubit) {
        expect(cubit.state.lgasUnavailable, isEmpty);
        expect(repository.lgaRequests.last, {'15'});
      },
    );

    group('for a child of 5 or older', () {
      final olderChild = completeChild().set(
        ChildField.dateOfBirth,
        DateTime(2016, 3, 12).toIso8601String(),
      );
      setUp(
        () => repository.draft = RegistrationDraft(
          startedOn: _today,
          childHasNin: false,
          child: olderChild,
        ),
      );

      blocTest<RegistrationFormCubit, RegistrationFormState>(
        'Step 1 asks for the fee before moving on',
        build: build,
        act: (cubit) async {
          await cubit.load();
          cubit.next();
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(cubit.state.askForPayment, isTrue);
          expect(cubit.state.step, RegistrationStep.child);
        },
      );

      blocTest<RegistrationFormCubit, RegistrationFormState>(
        'once paid, the reference is kept and the form moves on',
        build: build,
        act: (cubit) async {
          await cubit.load();
          cubit.next();
          await pumpEventQueue();
          repository.payments.stored = const StoredPayment(
            reference: 'BR-PAID',
            isPaid: true,
          );
          await cubit.paymentClosed();
        },
        verify: (cubit) {
          expect(cubit.state.askForPayment, isFalse);
          expect(cubit.state.step, RegistrationStep.mother);
          expect(cubit.state.draft?.paymentReference, 'BR-PAID');
        },
      );

      blocTest<RegistrationFormCubit, RegistrationFormState>(
        "offline, the fee can't be paid, so Step 1 stops there",
        build: () =>
            RegistrationFormCubit(repository, offline: true, now: () => _today),
        act: (cubit) async {
          await cubit.load();
          cubit.next();
          await pumpEventQueue();
        },
        verify: (cubit) {
          expect(cubit.state.askForPayment, isFalse);
          expect(cubit.state.showErrors, isTrue);
          expect(cubit.state.step, RegistrationStep.child);
        },
      );

      blocTest<RegistrationFormCubit, RegistrationFormState>(
        'offline, a fee paid before going offline still counts',
        setUp: () => repository.draft = RegistrationDraft(
          startedOn: _today,
          childHasNin: false,
          child: olderChild,
          paymentReference: 'BR-PAID',
        ),
        build: () =>
            RegistrationFormCubit(repository, offline: true, now: () => _today),
        act: (cubit) async {
          await cubit.load();
          cubit.next();
        },
        verify: (cubit) => expect(cubit.state.step, RegistrationStep.mother),
      );

      blocTest<RegistrationFormCubit, RegistrationFormState>(
        'closing the payment unpaid stays on Step 1',
        build: build,
        act: (cubit) async {
          await cubit.load();
          cubit.next();
          await pumpEventQueue();
          await cubit.paymentClosed();
        },
        verify: (cubit) {
          expect(cubit.state.step, RegistrationStep.child);
          expect(cubit.state.draft?.paymentReference, isNull);
        },
      );
    });

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      'a drawn signature is stored and can be cleared',
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.signatureDrawn(Uint8List(1));
      },
      verify: (cubit) => expect(
        cubit.state.draft?.informant[InformantField.signature],
        'signature.png',
      ),
    );
  });
}
