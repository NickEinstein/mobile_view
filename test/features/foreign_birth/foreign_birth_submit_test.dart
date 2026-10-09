import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/foreign_birth/data/dtos/foreign_birth_dtos.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_draft.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_form.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/form/cubit/foreign_birth_form_cubit.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/form/view/foreign_birth_form_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_foreign_birth_repository.dart';

final _today = DateTime(2026, 10, 4);

void main() {
  group('informant rules', () {
    test('with the nationality (backend) and an email', () {
      expect(completeInformant().isComplete, isTrue);
      for (final field in [
        InformantField.relationship,
        InformantField.surname,
        InformantField.firstName,
        InformantField.country,
        InformantField.state,
        InformantField.address,
        InformantField.nationality,
        InformantField.phone,
        InformantField.email,
        InformantField.consentType,
      ]) {
        expect(
          completeInformant().set(field, null).errorOf(field),
          ForeignBirthFieldError.required,
          reason: field.name,
        );
      }
      expect(completeInformant().errorOf(InformantField.stateOfOrigin), isNull);
    });

    test('a Nigerian informant needs a validated NIN and origin', () {
      final nigerian = completeInformant().set(
        InformantField.nationality,
        '63',
      );
      expect(
        nigerian.errorOf(InformantField.nin),
        ForeignBirthFieldError.required,
      );
      expect(
        nigerian.errorOf(InformantField.stateOfOrigin),
        ForeignBirthFieldError.required,
      );
      expect(
        nigerian.errorOf(InformantField.lgaOfOrigin),
        ForeignBirthFieldError.required,
      );
    });

    test('the email and phone are checked', () {
      expect(
        completeInformant()
            .set(InformantField.email, 'keith@')
            .errorOf(InformantField.email),
        ForeignBirthFieldError.invalidEmail,
      );
      expect(
        completeInformant()
            .set(InformantField.phone, '0812')
            .errorOf(InformantField.phone),
        ForeignBirthFieldError.invalidPhone,
      );
    });

    test('consent needs the chosen signature or face', () {
      final byFace = completeInformant().set(
        InformantField.consentType,
        ConsentType.faceCapture,
      );
      expect(
        byFace.errorOf(InformantField.face),
        ForeignBirthFieldError.required,
      );
      expect(byFace.errorOf(InformantField.signature), isNull);
    });

    test("a parent's particulars fill the informant's", () {
      final informant = const InformantParticulars()
          .set(InformantField.email, 'a@b.co')
          .copyFrom(completeMother());
      expect(informant[InformantField.surname], 'Ololade');
      expect(informant[InformantField.nationality], '63');
      expect(informant[InformantField.lga], '501');
      expect(informant.isNinVerified, isTrue);
      expect(informant[InformantField.email], 'a@b.co');
    });
  });

  group('draft', () {
    test('only the chosen consent is uploaded', () {
      final draft = completeDraft().copyWith(
        informant: completeInformant().set(InformantField.face, '/face.jpg'),
      );
      expect(draft.filesToUpload, ['signature-1.png', '/certificate.jpg']);
      expect(draft.consentPath, 'signature-1.png');
      expect(draft.files, contains('/face.jpg'));
    });

    test('survives a round trip through JSON', () {
      final draft = completeDraft().copyWith(
        uploads: {'/certificate.jpg': 'key/cert'},
      );
      expect(ForeignBirthDraft.fromJson(draft.toJson()), draft);
    });
  });

  group("submit payload (the backend's CreateBirthNotification)", () {
    final draft = completeDraft().copyWith(
      child: completeChild().set(ChildField.facePhoto, '/face.jpg'),
      uploads: {
        '/face.jpg': 'key/face',
        'signature-1.png': 'key/sig',
        '/certificate.jpg': 'key/cert',
      },
    );
    final json = foreignBirthPayloadToJson(draft, data: sampleReferenceData);

    test('child, reference and email', () {
      expect(json['reference'], 'BRTPAID1');
      expect(json['email'], 'keith@example.com');
      expect(json['surname'], 'Garba');
      expect(json['middlename'], isNull);
      expect(json['date_of_birth'], '2025-12-12');
      expect(json['gender'], 2);
      expect(json['birth_country'], 181);
      expect(json['birth_country_code'], 'GB');
      expect(json['state'], 951);
      expect(json['child_face'], 'key/face');
    });

    test('a Nigerian mother sends her NIN, LGAs and ethnic group', () {
      expect(json['mother_nin'], '90289384945');
      expect(json['mother_nationality'], 63);
      expect(json['mother_lga_of_origin'], 501);
      expect(json['mother_ethnic_group'], 5);
      expect(json['mother_lga'], 501);
      expect(json['mother_maiden_name'], 'Bello');
      expect(json['mother_occupation'], 100);
      expect(json['mother_age_at_birth'], 30);
      expect(json['mother_education_Level'], isNull);
    });

    test('a foreign father sends no LGA, ethnic group or NIN', () {
      expect(json['father_nin'], isNull);
      expect(json['father_lga_of_origin'], isNull);
      expect(json['father_ethnic_group'], isNull);
      expect(json['father_lga'], isNull);
      expect(json['father_residence_state'], 951);
      expect(json.containsKey('father_maiden_name'), isFalse);
    });

    test('informant, consent and the certificate as storage keys', () {
      expect(json['informant_relationship'], 13);
      expect(json['informant_nin'], isNull);
      expect(json['informant_nationality'], 181);
      expect(json['informant_email'], 'keith@example.com');
      expect(json['informant_consent'], 'key/sig');
      expect(json['supporting_document'], 'key/cert');
    });

    test('the response carries the notification number', () {
      expect(
        submittedFromJson({
          'success': true,
          'message': '…',
          'notification_number': 'GB261004512',
        }),
        'GB261004512',
      );
    });
  });

  group('ForeignBirthFormCubit', () {
    late FakeForeignBirthRepository repository;
    setUp(() => repository = FakeForeignBirthRepository());
    ForeignBirthFormCubit build() =>
        ForeignBirthFormCubit(repository, now: () => _today);

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'choosing Mother fills the informant from her',
      setUp: () => repository.draft = paidDraft(
        step: ForeignBirthStep.informant,
      ).copyWith(mother: completeMother()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.informantChanged(
          InformantField.relationship,
          ForeignBirthCodes.mother,
        );
      },
      verify: (cubit) {
        final informant = cubit.state.draft!.informant;
        expect(informant[InformantField.surname], 'Ololade');
        expect(informant[InformantField.relationship], '2');
        expect(informant.isLocked(InformantField.surname), isTrue);
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'a new signature replaces the old upload',
      setUp: () => repository.draft = completeDraft().copyWith(
        uploads: {'signature-1.png': 'key/old'},
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.informantSignatureDrawn(Uint8List(1));
      },
      verify: (cubit) {
        final draft = cubit.state.draft!;
        expect(draft.informant[InformantField.signature], 'signature-1.png');
        expect(draft.uploads, isEmpty);
      },
    );

    test('an unsupported certificate file is refused', () async {
      repository.draft = paidDraft(step: ForeignBirthStep.documents);
      final cubit = build();
      await cubit.load();
      final error = await cubit.certificatePicked(
        path: '/cert.pdf',
        name: 'cert.pdf',
        sizeBytes: 1000,
      );
      expect(error, DocumentError.unsupportedType);
      expect(cubit.state.draft!.certificate, isNull);
      await cubit.certificatePicked(
        path: '/cert.jpg',
        name: 'cert.jpg',
        sizeBytes: 1000,
      );
      expect(cubit.state.draft!.certificate?.path, 'kept//cert.jpg');
      expect(cubit.state.isStepComplete(_today), isTrue);
      await cubit.close();
    });

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'submit needs the declaration',
      setUp: () => repository.draft = completeDraft(),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.showErrors, isTrue);
        expect(repository.submitted, isEmpty);
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'submit uploads the files, sends everything, then clears the payment '
      'and the draft',
      setUp: () => repository.draft = completeDraft(),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(repository.uploadedPaths, [
          'signature-1.png',
          '/certificate.jpg',
        ]);
        expect(repository.submitted.single.uploads, {
          'signature-1.png': 'key/signature-1.png',
          '/certificate.jpg': 'key//certificate.jpg',
        });
        expect(cubit.state.submitStatus, SubmitStatus.submitted);
        expect(cubit.state.trackingId, 'GB261004512');
        expect(repository.payments.clears, 1);
        expect(repository.draft, isNull);
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'a failed upload sends nothing',
      setUp: () {
        repository
          ..draft = completeDraft()
          ..uploadFailure = const NetworkFailure();
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(repository.submitted, isEmpty);
        expect(cubit.state.submitStatus, SubmitStatus.idle);
        expect(cubit.state.submitFailure, isA<NetworkFailure>());
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'a refused submit keeps the uploads, so a retry sends them once',
      setUp: () {
        repository
          ..draft = completeDraft()
          ..submitResult = const Err(ServerFailure(statusCode: 500));
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
        repository.submitResult = const Ok(null);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(repository.uploadedPaths, hasLength(2));
        expect(repository.submitted, hasLength(2));
        // No number from the server: the payment reference is shown.
        expect(cubit.state.trackingId, 'BRTPAID1');
      },
    );
  });

  group('screens', () {
    Future<void> pumpForm(
      WidgetTester tester,
      FakeForeignBirthRepository repository,
    ) async {
      await tester.pumpApp(
        ForeignBirthFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the informant step asks for the relationship and email', (
      tester,
    ) async {
      final repository = FakeForeignBirthRepository()
        ..draft = paidDraft(step: ForeignBirthStep.informant);
      await pumpForm(tester, repository);
      expect(find.text('Step 4 of 6'), findsOneWidget);
      expect(find.text('Relationship to Child'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Email Address (the certificate is sent here)'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Select Type of Consent'), findsOneWidget);
    });

    testWidgets('the documents step needs the certificate', (tester) async {
      final repository = FakeForeignBirthRepository()
        ..draft = paidDraft(step: ForeignBirthStep.documents);
      await pumpForm(tester, repository);
      expect(find.text('Foreign Birth Certificate'), findsWidgets);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsOneWidget);
    });

    testWidgets('the review submits and shows the notification number', (
      tester,
    ) async {
      final repository = FakeForeignBirthRepository()..draft = completeDraft();
      var exited = false;
      await tester.pumpApp(
        ForeignBirthFormPage(
          onExit: () => exited = true,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 6 of 6'), findsOneWidget);
      expect(find.text('Information Review'), findsWidgets);
      final declaration = find.byType(Checkbox);
      await tester.ensureVisible(declaration);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Application Successfully Submitted'), findsOneWidget);
      expect(find.text('GB261004512'), findsOneWidget);
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(exited, isTrue);
    });
  });
}
