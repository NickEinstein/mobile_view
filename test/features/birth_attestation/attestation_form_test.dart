import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/form/cubit/attestation_form_cubit.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/form/view/attestation_form_page.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';

import '../../helpers/pump_app.dart';
import 'fake_birth_attestation_repository.dart';

final _today = DateTime(2026, 10, 3);

final _bauchiRecord = ApplicantNinRecord(
  nin: '12345678901',
  surname: 'Ogunlade',
  firstName: 'Bolaji',
  middleName: 'Favour',
  dateOfBirth: DateTime(1990, 6, 14),
  sex: Sex.male,
  phone: '08130845852',
  stateOfOrigin: 'Bauchi',
  lgaOfOrigin: 'Bogoro',
);

const _affidavit = AttachedFile(path: 'a.jpg', name: 'a.jpg', sizeBytes: 10);

ApplicantParticulars _completeApplicant() {
  var a = const ApplicantParticulars();
  for (final (field, value) in [
    (ApplicantField.surname, 'Ogunlade'),
    (ApplicantField.firstName, 'Bolaji'),
    (ApplicantField.sex, '1'),
    (ApplicantField.dateOfBirth, DateTime(1990, 6, 14).toIso8601String()),
    (ApplicantField.maritalStatus, 'Single'),
    (ApplicantField.stateOfOrigin, 'bauchi'),
    (ApplicantField.lgaOfOrigin, 'bogoro'),
    (ApplicantField.townOfOrigin, 'Gobbiya'),
    (ApplicantField.idType, 'Nigerian Passport'),
    (ApplicantField.idNumber, 'A1234567'),
    (ApplicantField.email, 'bolaji@mail.com'),
  ]) {
    a = a.set(field, value);
  }
  return a;
}

AdditionalInformation _completeAdditional() {
  var b = const AdditionalInformation();
  for (final field in AdditionalField.values) {
    if (field == AdditionalField.requiredForCountry) continue;
    b = b.set(field, switch (field) {
      AdditionalField.requiredFor => 'job in nigeria',
      _ => 'value',
    });
  }
  return b;
}

ParentInformation _nigerianParent() => const ParentInformation()
    .set(ParentInfoField.surname, 'Ogunlade')
    .set(ParentInfoField.firstName, 'Ada')
    .set(ParentInfoField.maidenName, 'Musa')
    .set(ParentInfoField.nationality, ParentInformation.nigeria)
    .set(ParentInfoField.stateOfOrigin, 'bauchi')
    .set(ParentInfoField.lgaOfOrigin, 'bogoro')
    .set(ParentInfoField.town, 'Bogoro');

AttestationDraft _identityDone({ApplicantNinRecord? record}) =>
    AttestationDraft(
      startedOn: _today,
      hasNin: record != null,
      ninRecord: record,
      facePhoto: 'face.jpg',
    );

AttestationDraft _completeDraft() => _identityDone().copyWith(
  applicant: _completeApplicant(),
  additional: _completeAdditional(),
  mother: _nigerianParent(),
  father: _nigerianParent(),
  documents: const AttestationDocuments().set(
    AttestationDocument.affidavit,
    _affidavit,
  ),
);

void main() {
  group('rules', () {
    test('everything but middle name and phone is required', () {
      const empty = ApplicantParticulars();
      expect(
        empty.errorOf(ApplicantField.surname, today: _today),
        AttestationFieldError.required,
      );
      expect(empty.errorOf(ApplicantField.middleName, today: _today), isNull);
      expect(empty.errorOf(ApplicantField.phone, today: _today), isNull);
      expect(_completeApplicant().isComplete(today: _today), isTrue);
    });

    test('checks email, phone and date of birth', () {
      final a = _completeApplicant()
          .set(ApplicantField.email, 'not-an-email')
          .set(ApplicantField.phone, '0813');
      expect(
        a.errorOf(ApplicantField.email, today: _today),
        AttestationFieldError.invalidEmail,
      );
      expect(
        a.errorOf(ApplicantField.phone, today: _today),
        AttestationFieldError.invalidPhone,
      );

      AttestationFieldError? dob(DateTime date, {ApplicantNinRecord? nin}) =>
          _completeApplicant()
              .set(ApplicantField.dateOfBirth, date.toIso8601String())
              .errorOf(ApplicantField.dateOfBirth, today: _today, nin: nin);
      expect(dob(DateTime(2027)), AttestationFieldError.futureDate);
      expect(dob(DateTime(2008, 10, 4)), AttestationFieldError.underAge);
      expect(dob(DateTime(2008, 10, 3)), isNull);
      expect(
        dob(DateTime(1984), nin: _bauchiRecord),
        AttestationFieldError.farFromNinDate,
      );
      expect(dob(DateTime(1988), nin: _bauchiRecord), isNull);
    });

    test('the country is asked only for a requirement abroad', () {
      final home = _completeAdditional();
      expect(home.isComplete(), isTrue);
      final abroad = home.set(AdditionalField.requiredFor, 'job abroad');
      expect(abroad.isComplete(), isFalse);
      expect(
        abroad.set(AdditionalField.requiredForCountry, 'gh').isComplete(),
        isTrue,
      );
    });

    test('a foreign parent gives a passport instead of origin', () {
      final foreign = _nigerianParent().set(ParentInfoField.nationality, 'gh');
      expect(foreign.needsPassport, isTrue);
      expect(foreign[ParentInfoField.stateOfOrigin], isNull);
      expect(foreign.isComplete(Parent.mother), isTrue);
      expect(
        _nigerianParent()
            .set(ParentInfoField.maidenName, null)
            .isComplete(Parent.father),
        isTrue,
      );
      expect(
        _nigerianParent()
            .set(ParentInfoField.maidenName, null)
            .isComplete(Parent.mother),
        isFalse,
      );
    });

    test('a draft reads back the same', () {
      final draft = _completeDraft().copyWith(
        step: AttestationStep.parents,
        submissionKey: 'k1',
      );
      expect(AttestationDraft.fromJson(draft.toJson()), draft);
    });
  });

  group('AttestationFormCubit', () {
    late FakeBirthAttestationRepository repository;

    setUp(
      () => repository = FakeBirthAttestationRepository()
        ..payments.stored = const StoredPayment(reference: 'REF1', isPaid: true)
        ..draft = _identityDone(),
    );

    AttestationFormCubit build() => AttestationFormCubit(
      repository,
      now: () => _today,
      newSubmissionKey: () => 'key-1',
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'needs a confirmed payment',
      setUp: () => repository.payments.stored = null,
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.status, FormStatus.missingPayment),
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'needs face validation first',
      setUp: () =>
          repository.draft = AttestationDraft(startedOn: _today, hasNin: false),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.status, FormStatus.missingIdentity),
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'prefills and locks the applicant from the NIN record',
      setUp: () => repository.draft = _identityDone(record: _bauchiRecord),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.applicantChanged(ApplicantField.surname, 'Changed');
      },
      verify: (cubit) {
        final a = cubit.state.draft!.applicant;
        expect(a[ApplicantField.surname], 'Ogunlade');
        expect(a[ApplicantField.middleName], 'Favour');
        expect(a[ApplicantField.sex], '1');
        expect(a[ApplicantField.stateOfOrigin], 'bauchi');
        expect(a[ApplicantField.lgaOfOrigin], 'bogoro');
        expect(a[ApplicantField.phone], '08130845852');
        expect(cubit.state.isLocked(ApplicantField.surname), isTrue);
        expect(cubit.state.isLocked(ApplicantField.email), isFalse);
        expect(repository.draft!.applicant, a);
        // The NIN state's LGAs were asked for before matching the LGA.
        expect(repository.lgaRequests, anyElement(equals({'bauchi'})));
      },
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'an incomplete step shows its errors instead of moving on',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.showErrors, isTrue);
        expect(cubit.state.step, AttestationStep.applicant);
      },
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'step 2 needs the affidavit',
      setUp: () => repository.draft = _identityDone().copyWith(
        step: AttestationStep.additional,
        additional: _completeAdditional(),
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.next();
        expect(cubit.state.step, AttestationStep.additional);
        await cubit.documentPicked(
          AttestationDocument.affidavit,
          path: 'affidavit.jpg',
          name: 'affidavit.jpg',
          sizeBytes: 1000,
        );
        cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.step, AttestationStep.parents);
        expect(
          cubit.state.draft!.documents[AttestationDocument.affidavit]?.path,
          'kept-affidavit.jpg',
        );
      },
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'refuses a document that is not an image',
      build: build,
      act: (cubit) async {
        await cubit.load();
        final error = await cubit.documentPicked(
          AttestationDocument.affidavit,
          path: 'a.pdf',
          name: 'a.pdf',
          sizeBytes: 10,
        );
        expect(error, DocumentError.unsupportedType);
      },
      verify: (cubit) => expect(cubit.state.draft!.documents.files, isEmpty),
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'a foreign parent needs a passport; becoming Nigerian drops it',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.parentChanged(Parent.father, ParentInfoField.nationality, 'gh');
        expect(cubit.state.passportMissing(Parent.father), isTrue);
        await cubit.documentPicked(
          AttestationDocument.fatherPassport,
          path: 'p.jpg',
          name: 'p.jpg',
          sizeBytes: 10,
        );
        expect(cubit.state.passportMissing(Parent.father), isFalse);
        cubit.parentChanged(
          Parent.father,
          ParentInfoField.nationality,
          ParentInformation.nigeria,
        );
      },
      verify: (cubit) {
        expect(
          cubit.state.draft!.documents[AttestationDocument.fatherPassport],
          isNull,
        );
        expect(repository.deleted, contains('kept-p.jpg'));
      },
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'Edit on the review returns to the review',
      setUp: () => repository.draft = _completeDraft().copyWith(
        step: AttestationStep.review,
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit
          ..editStep(AttestationStep.applicant)
          ..next();
      },
      verify: (cubit) => expect(cubit.state.step, AttestationStep.review),
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'submits with the paid reference, then clears the draft and payment',
      setUp: () => repository.draft = _completeDraft().copyWith(
        step: AttestationStep.review,
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.submit();
        expect(repository.submitted, isEmpty);
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.submitStatus, SubmitStatus.submitted);
        expect(cubit.state.trackingId, 'BA123');
        final (sent, reference) = repository.submitted.single;
        expect(reference, 'REF1');
        expect(sent.submissionKey, 'key-1');
        expect(repository.draft, isNull);
        expect(repository.payments.stored, isNull);
      },
    );

    blocTest<AttestationFormCubit, AttestationFormState>(
      'a failed submission keeps everything for a retry',
      setUp: () => repository
        ..draft = _completeDraft().copyWith(step: AttestationStep.review)
        ..submitResult = const Err(NetworkFailure()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.submitStatus, SubmitStatus.failed);
        expect(repository.draft?.submissionKey, 'key-1');
        expect(repository.payments.stored, isNotNull);
      },
    );
  });

  group('form screens', () {
    late FakeBirthAttestationRepository repository;

    setUp(
      () => repository = FakeBirthAttestationRepository()
        ..payments.stored = const StoredPayment(
          reference: 'REF1',
          isPaid: true,
        ),
    );

    Future<void> pump(WidgetTester tester, {VoidCallback? onExit}) async {
      tester.view
        ..physicalSize = const Size(400, 8000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        BlocProvider(
          create: (_) =>
              AttestationFormCubit(repository, now: () => _today)
                ..load().ignore(),
          child: AttestationFormView(onExit: onExit ?? () {}),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('step 1 shows the NIN details read-only and the face', (
      tester,
    ) async {
      repository.draft = _identityDone(record: _bauchiRecord);
      await pump(tester);

      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Particulars of Applicant'), findsWidgets);
      final surname = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Ogunlade'),
      );
      expect(surname.enabled, isFalse);
      expect(find.text('Face captured successfully'), findsOneWidget);

      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsWidgets);
      expect(find.text('Step 1 of 4'), findsOneWidget);
    });

    testWidgets('the review submits and shows the tracking ID', (tester) async {
      repository.draft = _completeDraft().copyWith(
        step: AttestationStep.review,
      );
      var exited = 0;
      await pump(tester, onExit: () => exited++);

      expect(find.text('Information Preview'), findsWidgets);
      expect(find.text('Particulars of Mother'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('Application Successfully Submitted'), findsOneWidget);
      expect(find.text('BA123'), findsOneWidget);
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(exited, 1);
    });

    testWidgets('explains a missing payment', (tester) async {
      repository
        ..payments.stored = null
        ..draft = _identityDone();
      await pump(tester);
      expect(find.textContaining('no confirmed payment'), findsOneWidget);
    });
  });
}
