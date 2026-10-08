import 'dart:typed_data';

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
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';

import '../../helpers/pump_app.dart';
import 'fake_adopted_child_repository.dart';

final _today = DateTime(2026, 10, 4);

void main() {
  group('informant rules', () {
    test('name, residence, address, relationship, phone and consent are '
        'required', () {
      const empty = InformantParticulars();
      expect(
        empty.errorOf(InformantField.surname),
        AdoptionFieldError.required,
      );
      expect(
        empty.errorOf(InformantField.country),
        AdoptionFieldError.required,
      );
      expect(
        empty.errorOf(InformantField.consentType),
        AdoptionFieldError.required,
      );
      expect(empty.errorOf(InformantField.nin), isNull);
      expect(empty.errorOf(InformantField.passportNumber), isNull);
      expect(completeInformant().isComplete, isTrue);
    });

    test('state and LGA are asked only for a residence in Nigeria', () {
      final home = completeInformant().set(InformantField.country, '63');
      expect(home.errorOf(InformantField.lga), AdoptionFieldError.required);
      expect(completeInformant().applies(InformantField.lga), isFalse);
    });

    test('consent needs its own artefact: a signature or a face', () {
      final byFace = completeInformant().set(
        InformantField.consentType,
        ConsentType.faceCapture,
      );
      expect(byFace.errorOf(InformantField.signature), isNull);
      expect(byFace.errorOf(InformantField.face), AdoptionFieldError.required);
      expect(byFace.set(InformantField.face, '/face.jpg').isComplete, isTrue);
    });

    test('a typed NIN must be validated', () {
      expect(
        completeInformant()
            .set(InformantField.nin, '12345678901')
            .errorOf(InformantField.nin),
        AdoptionFieldError.ninNotVerified,
      );
    });

    test('"same residence" copies Adopter 1\'s residence', () {
      final adopter = completeAdopter()
          .set(AdopterField.country, '63')
          .set(AdopterField.state, '25')
          .set(AdopterField.lga, '501');
      final informant = completeInformant().copyResidenceFrom(adopter);
      expect(informant[InformantField.country], '63');
      expect(informant[InformantField.state], '25');
      expect(informant[InformantField.lga], '501');
      expect(informant[InformantField.address], 'No 12 Adeleke road, Lekki');
    });
  });

  group('documents', () {
    test('court order, adoption certificate and Adopter 1\'s identity are '
        'required; Adopter 2\'s only when given', () {
      final draft = completeDraft();
      expect(
        draft.documentsAsked,
        isNot(contains(AdoptionDocument.adopter2Identity)),
      );
      expect(draft.documentsComplete, isTrue);
      final withSecond = draft.copyWith(adopter2: completeAdopter());
      expect(withSecond.isMissing(AdoptionDocument.adopter2Identity), isTrue);
      expect(withSecond.documentsComplete, isFalse);
    });

    test('the draft keeps the informant and documents through JSON', () {
      final draft = completeDraft().copyWith(
        informantPassport: () => photo('passport.png'),
      );
      expect(AdoptionDraft.fromJson(draft.toJson()), draft);
    });

    test('only the chosen consent artefact is uploaded', () {
      final draft = completeDraft().copyWith(
        informant: completeInformant().set(InformantField.face, '/face.jpg'),
      );
      expect(draft.filesToUpload, contains('signature-1.png'));
      expect(draft.filesToUpload, isNot(contains('/face.jpg')));
      expect(draft.files, contains('/face.jpg'));
    });
  });

  group('section payload', () {
    test('the informant goes as inf* and the documents with their keys', () {
      final draft = completeDraft().copyWith(
        informantPassport: () => photo('passport.png'),
        uploads: {
          'signature-1.png': 'key/sig',
          '/order.jpg': 'key/order',
          '/certificate.jpg': 'key/cert',
          '/id1.png': 'key/id1',
          '/passport.png': 'key/passport',
        },
      );
      final json = adoptionSectionToJson(
        draft,
        section: AdoptionSection.documents,
        stateName: (_) => null,
      );
      expect(json['section'], 5);
      expect(json['infSurname'], 'Keith');
      expect(json['infCountry'], 31);
      expect(json['infResidenceState'], isNull);
      expect(json['infRelationshipToChild'], 13);
      expect(json['infPhone'], '08123123123');
      expect(json['infNin'], isNull);
      expect(json['infConsentType'], 'signature_pad');
      expect(json['infSignature'], 'key/sig');
      expect(json['infSameResidenceAsAdopter1'], isFalse);
      expect(json['supportingDocument'], [
        {
          'type': 'court_adoption_order',
          'file': 'key/order',
          'mimeType': 'image/jpeg',
        },
        {
          'type': 'adoption_certificate',
          'file': 'key/cert',
          'mimeType': 'image/jpeg',
        },
        {
          'type': 'adoptive_mother_identity_document',
          'file': 'key/id1',
          'mimeType': 'image/png',
        },
        {
          'type': 'international-passport',
          'file': 'key/passport',
          'mimeType': 'image/png',
        },
      ]);
    });

    test('a face consent is sent in infSignature', () {
      final draft = completeDraft().copyWith(
        informant: completeInformant()
            .set(InformantField.consentType, ConsentType.faceCapture)
            .set(InformantField.face, '/face.jpg'),
        uploads: {'/face.jpg': 'key/face', 'signature-1.png': 'key/sig'},
      );
      final json = adoptionSectionToJson(
        draft,
        section: AdoptionSection.informant,
        stateName: (_) => null,
      );
      expect(json['infConsentType'], 'face_capture');
      expect(json['infSignature'], 'key/face');
    });

    test('the submit answer may carry a tracking number', () {
      expect(submittedFromJson({'trackingId': 'ACR-9'}), 'ACR-9');
      expect(submittedFromJson({'success': true}), isNull);
      expect(
        () => submittedFromJson({'success': false}),
        throwsFormatException,
      );
    });
  });

  group('AdoptionFormCubit', () {
    late FakeAdoptedChildRepository repository;
    setUp(() => repository = FakeAdoptedChildRepository());

    AdoptionFormCubit build() =>
        AdoptionFormCubit(repository, now: () => _today);

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      '"same residence" Yes fills the informant from Adopter 1',
      setUp: () => repository.draft = paidDraft(
        step: AdoptionStep.informant,
      ).copyWith(adopter1: completeAdopter().set(AdopterField.country, '63')),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.informantChanged(InformantField.sameResidence, Answer.yes);
      },
      verify: (cubit) {
        final informant = cubit.state.draft!.informant;
        expect(informant[InformantField.country], '63');
        expect(informant[InformantField.address], 'No 12 Adeleke road, Lekki');
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'validating the informant NIN fills the name',
      setUp: () => repository.draft = paidDraft(step: AdoptionStep.informant),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.informantChanged(InformantField.nin, '12345678901');
        await cubit.validateInformantNin();
      },
      verify: (cubit) {
        final informant = cubit.state.draft!.informant;
        expect(informant.isNinVerified, isTrue);
        expect(informant[InformantField.surname], 'Hassan');
        expect(cubit.state.ninValidations, 1);
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'a drawn signature is kept and replaces the earlier upload',
      setUp: () => repository.draft = paidDraft(
        step: AdoptionStep.informant,
      ).copyWith(uploads: {'signature-0.png': 'key/old'}),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.informantSignatureDrawn(Uint8List(4));
      },
      verify: (cubit) {
        expect(
          cubit.state.draft!.informant[InformantField.signature],
          'signature-1.png',
        );
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'a document that is too large is refused',
      setUp: () => repository.draft = paidDraft(step: AdoptionStep.documents),
      build: build,
      act: (cubit) async {
        await cubit.load();
        final error = await cubit.documentPicked(
          AdoptionDocument.courtOrder,
          path: '/big.jpg',
          name: 'big.jpg',
          sizeBytes: 6 * 1024 * 1024,
        );
        expect(error, DocumentError.tooLarge);
        await cubit.documentPicked(
          AdoptionDocument.adoptionCertificate,
          path: '/cert.jpg',
          name: 'cert.jpg',
          sizeBytes: 1024,
        );
      },
      verify: (cubit) {
        final documents = cubit.state.draft!.documents;
        expect(documents[AdoptionDocument.courtOrder], isNull);
        expect(
          documents[AdoptionDocument.adoptionCertificate]?.path,
          'kept//cert.jpg',
        );
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'the documents step saves section 5 with the uploads',
      setUp: () => repository.draft = completeDraft().copyWith(
        step: AdoptionStep.documents,
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.next();
      },
      verify: (cubit) {
        expect(repository.savedSections.single.$1, AdoptionSection.documents);
        expect(cubit.state.step, AdoptionStep.review);
        expect(cubit.state.draft!.uploads['/order.jpg'], 'key//order.jpg');
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'Edit on the review returns to it after saving',
      setUp: () => repository.draft = completeDraft(),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.editStep(AdoptionStep.adoptionDetails);
        await cubit.next();
      },
      verify: (cubit) {
        expect(
          repository.savedSections.single.$1,
          AdoptionSection.adoptionDetails,
        );
        expect(cubit.state.step, AdoptionStep.review);
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'submitting needs the declaration',
      setUp: () => repository.draft = completeDraft(),
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

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'a submitted application clears the payment and the draft',
      setUp: () {
        repository
          ..draft = completeDraft()
          ..submitResult = const Ok('ACR-TRACK-1');
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(repository.submitted, ['ACR-2026-0003150']);
        expect(repository.payments.clears, 1);
        expect(repository.draft, isNull);
        expect(cubit.state.submitStatus, SubmitStatus.submitted);
        expect(cubit.state.trackingId, 'ACR-TRACK-1');
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'a failed submission keeps everything',
      setUp: () {
        repository
          ..draft = completeDraft()
          ..submitResult = const Err(NetworkFailure());
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(repository.draft, isNotNull);
        expect(repository.payments.clears, 0);
        expect(cubit.state.submitStatus, SubmitStatus.idle);
        expect(cubit.state.saveFailure, isA<NetworkFailure>());
      },
    );
  });

  group('screens', () {
    testWidgets('the informant step asks how the informant consents', (
      tester,
    ) async {
      final repository = FakeAdoptedChildRepository()
        ..draft = paidDraft(step: AdoptionStep.informant);
      await tester.pumpApp(
        AdoptionFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 5 of 7'), findsOneWidget);
      expect(
        find.text('Is the place of residence the same as that of Adopter 1?'),
        findsOneWidget,
      );
    });

    testWidgets('upload documents lists what is asked for', (tester) async {
      final repository = FakeAdoptedChildRepository()
        ..draft = paidDraft(step: AdoptionStep.documents);
      await tester.pumpApp(
        AdoptionFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Court Adoption Order'), findsWidgets);
      expect(find.text('Adoption Certificate'), findsWidgets);
      expect(find.text('Identity Document (Adopter 1)'), findsWidgets);
      expect(find.text('Identity Document (Adopter 2)'), findsNothing);
    });

    testWidgets('the review submits and shows the tracking number', (
      tester,
    ) async {
      final repository = FakeAdoptedChildRepository()
        ..draft = completeDraft()
        ..submitResult = const Ok('ACR-TRACK-1');
      var exited = false;
      await tester.pumpApp(
        AdoptionFormPage(onExit: () => exited = true, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Information Review'), findsWidgets);
      expect(find.text('Submit'), findsOneWidget);
      final declaration = find.byType(Checkbox);
      await tester.ensureVisible(declaration);
      await tester.pumpAndSettle();
      await tester.tap(declaration);
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('ACR-TRACK-1'), findsOneWidget);
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(exited, isTrue);
    });
  });
}
