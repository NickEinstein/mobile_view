import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/data/dtos/surrogacy_dtos.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_form.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/form/cubit/surrogacy_form_cubit.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/form/view/surrogacy_form_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_surrogacy_birth_repository.dart';

final _today = DateTime(2026, 10, 4);

ParentParticulars _mother() => const ParentParticulars()
    .set(ParentField.surname, 'Ololade')
    .set(ParentField.firstName, 'Simisola')
    .set(ParentField.maritalStatus, '1')
    .set(ParentField.address, 'No 12 Adeleke road, Lekki')
    .set(ParentField.occupation, '100')
    .set(ParentField.nationality, '63')
    .set(ParentField.country, '63')
    .set(ParentField.state, '25')
    .set(ParentField.lga, '501')
    .set(ParentField.localityType, '2');

InformantParticulars _informant() => const InformantParticulars()
    .set(InformantField.surname, 'Keith')
    .set(InformantField.firstName, 'Ryan')
    .set(InformantField.country, '31')
    .set(InformantField.address, 'No 12 Adeleke road, Lekki')
    .set(InformantField.relationship, '13')
    .set(InformantField.phone, '08123212820')
    .set(InformantField.consentType, ConsentType.signature)
    .set(InformantField.signature, 'sign.png');

const _photo = AttachedFile(path: 'court.jpg', name: 'court.jpg', sizeBytes: 1);

Map<SurrogacyDocument, AttachedFile> _documents({bool father = false}) => {
  SurrogacyDocument.courtOrder: _photo,
  SurrogacyDocument.parentalOrder: const AttachedFile(
    path: 'order.jpg',
    name: 'order.jpg',
    sizeBytes: 1,
  ),
  SurrogacyDocument.motherIdentity: const AttachedFile(
    path: 'mother.png',
    name: 'mother.png',
    sizeBytes: 1,
  ),
  if (father)
    SurrogacyDocument.fatherIdentity: const AttachedFile(
      path: 'father.png',
      name: 'father.png',
      sizeBytes: 1,
    ),
};

/// Everything filled in, on [step].
SurrogacyDraft _complete({SurrogacyStep step = SurrogacyStep.review}) =>
    paidDraft(step: step).copyWith(
      child: completeChild(),
      surrogacy: completeDetails(),
      legalMother: _mother(),
      hasLegalFather: false,
      informant: _informant(),
      documents: _documents(),
    );

void main() {
  group('informant rules', () {
    test('required fields, and the chosen consent', () {
      expect(_informant().isComplete, isTrue);
      for (final field in [
        InformantField.surname,
        InformantField.firstName,
        InformantField.country,
        InformantField.address,
        InformantField.relationship,
        InformantField.phone,
        InformantField.consentType,
      ]) {
        expect(
          _informant().set(field, null).errorOf(field),
          SurrogacyFieldError.required,
          reason: field.name,
        );
      }
      final byFace = _informant().set(
        InformantField.consentType,
        ConsentType.faceCapture,
      );
      expect(byFace.errorOf(InformantField.face), SurrogacyFieldError.required);
      expect(byFace.errorOf(InformantField.signature), isNull);
      expect(byFace.set(InformantField.face, 'face.jpg').isComplete, isTrue);
    });

    test('a residence in Nigeria needs its state and LGA', () {
      final nigeria = _informant().set(InformantField.country, '63');
      expect(
        nigeria.errorOf(InformantField.state),
        SurrogacyFieldError.required,
      );
      expect(nigeria.errorOf(InformantField.lga), SurrogacyFieldError.required);
    });

    test("'same residence' copies the legal mother's", () {
      final copied = _informant().copyResidenceFrom(_mother());
      expect(copied[InformantField.country], '63');
      expect(copied[InformantField.state], '25');
      expect(copied[InformantField.lga], '501');
      expect(copied[InformantField.address], 'No 12 Adeleke road, Lekki');
    });
  });

  group('documents', () {
    test('court order, parental order and mother identity are required', () {
      final draft = _complete();
      expect(draft.documentsComplete, isTrue);
      expect(
        draft.documentsAsked,
        isNot(contains(SurrogacyDocument.fatherIdentity)),
      );
      final missing = draft.copyWith(
        documents: Map.of(draft.documents)
          ..remove(SurrogacyDocument.parentalOrder),
      );
      expect(missing.isMissing(SurrogacyDocument.parentalOrder), isTrue);
    });

    test("the father's identity only when he is named", () {
      final named = _complete().copyWith(hasLegalFather: true);
      expect(named.isMissing(SurrogacyDocument.fatherIdentity), isTrue);
      expect(
        named.copyWith(documents: _documents(father: true)).documentsComplete,
        isTrue,
      );
    });

    test('only files the backend takes are uploaded', () {
      final draft = _complete().copyWith(
        informant: _informant()
            .set(InformantField.consentType, ConsentType.faceCapture)
            .set(InformantField.face, 'face.jpg'),
      );
      expect(draft.filesToUpload, isNot(contains('face.jpg')));
      expect(draft.filesToUpload, isNot(contains('sign.png')));
      expect(draft.files, containsAll(['face.jpg', 'sign.png']));
    });
  });

  group('payload (the API\'s inf* fields and supportingDocument)', () {
    test('sends the informant and the uploaded documents', () {
      final draft = _complete().copyWith(
        informant: _informant()
            .set(InformantField.sameResidence, Answer.no)
            .set(InformantField.passportNumber, 'X12345678'),
        informantPassport: () => const AttachedFile(
          path: 'passport.png',
          name: 'passport.png',
          sizeBytes: 1,
        ),
        uploads: {
          'sign.png': 'key/sign.png',
          'court.jpg': 'key/court.jpg',
          'order.jpg': 'key/order.jpg',
          'mother.png': 'key/mother.png',
          'passport.png': 'key/passport.png',
        },
      );
      final json = surrogacySectionToJson(
        draft,
        section: SurrogacySection.documents,
      );
      expect(json['infSurname'], 'Keith');
      expect(json['infSameResidenceAsLp1'], false);
      expect(json['infCountry'], 31);
      expect(json['infStateProvince'], isNull);
      expect(json['infRelationshipToChild'], 13);
      expect(json['infPassportNo'], 'X12345678');
      expect(json['infConsentType'], 'signature_pad');
      expect(json['infSignature'], 'key/sign.png');
      expect(json['supportingDocument'], [
        {
          'type': 'court_surrogacy_agreement_order',
          'file': 'key/court.jpg',
          'mimeType': 'image/jpeg',
        },
        {
          'type': 'parental_order',
          'file': 'key/order.jpg',
          'mimeType': 'image/jpeg',
        },
        {
          'type': 'legal_mother_identity_document',
          'file': 'key/mother.png',
          'mimeType': 'image/png',
        },
        {
          'type': 'international-passport',
          'file': 'key/passport.png',
          'mimeType': 'image/png',
        },
      ]);
    });

    test('a face consent sends no signature', () {
      final json = surrogacySectionToJson(
        _complete().copyWith(
          informant: _informant().set(
            InformantField.consentType,
            ConsentType.faceCapture,
          ),
          uploads: {'sign.png': 'key/sign.png'},
        ),
        section: SurrogacySection.informant,
      );
      expect(json['infConsentType'], 'face_capture');
      expect(json['infSignature'], isNull);
    });

    test('a refused submission is an error', () {
      expect(
        () => submittedFromJson({'success': false}),
        throwsFormatException,
      );
      expect(submittedFromJson({'success': true}), isNull);
      expect(submittedFromJson({'certificateNo': 'SBR123'}), 'SBR123');
    });
  });

  group('SurrogacyFormCubit (informant, documents, submit)', () {
    late FakeSurrogacyBirthRepository repository;
    setUp(() => repository = FakeSurrogacyBirthRepository());

    SurrogacyFormCubit build() =>
        SurrogacyFormCubit(repository, now: () => _today);

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      "'same residence' fills the informant from the legal mother",
      setUp: () => repository.draft = _complete(
        step: SurrogacyStep.informant,
      ).copyWith(informant: const InformantParticulars()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.informantChanged(InformantField.sameResidence, Answer.yes);
      },
      verify: (cubit) {
        final informant = cubit.state.draft!.informant;
        expect(informant[InformantField.lga], '501');
        expect(informant[InformantField.sameResidence], Answer.yes);
      },
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'a document that is not a JPEG or PNG is refused',
      setUp: () => repository.draft = paidDraft(step: SurrogacyStep.documents),
      build: build,
      act: (cubit) async {
        await cubit.load();
        final error = await cubit.documentPicked(
          SurrogacyDocument.courtOrder,
          path: 'order.pdf',
          name: 'order.pdf',
          sizeBytes: 10,
        );
        expect(error, DocumentError.unsupportedType);
        await cubit.documentPicked(
          SurrogacyDocument.courtOrder,
          path: 'order.jpg',
          name: 'order.jpg',
          sizeBytes: 10,
        );
      },
      verify: (cubit) => expect(
        cubit.state.draft!.documents[SurrogacyDocument.courtOrder]?.path,
        'kept/order.jpg',
      ),
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'Edit on the review returns to the review once saved',
      setUp: () => repository.draft = _complete(),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.editStep(SurrogacyStep.surrogacy);
        await cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.step, SurrogacyStep.review);
        expect(repository.savedSections.single.$1, SurrogacySection.child);
      },
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'submit needs the declaration',
      setUp: () => repository.draft = _complete(),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.submit();
      },
      verify: (cubit) {
        expect(repository.submitted, isEmpty);
        expect(cubit.state.showErrors, isTrue);
      },
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'submitting finalises the application and clears the device',
      setUp: () => repository.draft = _complete(),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(repository.submitted, ['SBR-2026-0004821']);
        expect(cubit.state.submitStatus, SubmitStatus.submitted);
        expect(cubit.state.trackingId, 'SBR-2026-0004821');
        expect(repository.draft, isNull);
        expect(repository.payments.clears, 1);
      },
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'a failed submit keeps everything',
      setUp: () {
        repository
          ..draft = _complete()
          ..submitResult = const Err(NetworkFailure());
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.submitStatus, SubmitStatus.idle);
        expect(cubit.state.saveFailure, isA<NetworkFailure>());
        expect(repository.draft, isNotNull);
        expect(repository.payments.clears, 0);
      },
    );
  });

  group('screens', () {
    testWidgets('informant: choosing a consent shows its control', (
      tester,
    ) async {
      final repository = FakeSurrogacyBirthRepository()
        ..draft = paidDraft(step: SurrogacyStep.informant);
      await tester.pumpApp(
        SurrogacyFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 6 of 8'), findsOneWidget);
      expect(find.text("Informant's Signature"), findsNothing);
      await tester.dragUntilVisible(
        find.text('Draw Signature'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      // Clear of the buttons under the form.
      await tester.ensureVisible(find.text('Draw Signature'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Draw Signature'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          "Informant's Signature",
          findRichText: true,
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Capture Face'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          "Informant's Face",
          findRichText: true,
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets("documents: the father's only when he is named", (
      tester,
    ) async {
      final repository = FakeSurrogacyBirthRepository()
        ..draft = paidDraft(step: SurrogacyStep.documents);
      await tester.pumpApp(
        SurrogacyFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Court Surrogacy Agreement Order (Scanned)'),
        findsOneWidget,
      );
      expect(find.text('Parental Order (Scanned)'), findsOneWidget);
      expect(
        find.text('Identity Document (Legal Parent (Father))'),
        findsNothing,
      );
    });

    testWidgets('review: submit shows the success dialog, then leaves', (
      tester,
    ) async {
      final repository = FakeSurrogacyBirthRepository()..draft = _complete();
      var exited = false;
      await tester.pumpApp(
        SurrogacyFormPage(onExit: () => exited = true, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 8 of 8'), findsOneWidget);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Application Successfully Submitted'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('SBR-2026-0004821'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(exited, isTrue);
    });
  });
}
