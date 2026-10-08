import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/death_registration/data/dtos/death_dtos.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_draft.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_form.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_record.dart';
import 'package:vital_reg_mobile/features/death_registration/presentation/details/view/death_details_page.dart';
import 'package:vital_reg_mobile/features/death_registration/presentation/form/cubit/death_form_cubit.dart';
import 'package:vital_reg_mobile/features/death_registration/presentation/form/view/death_form_page.dart';
import 'package:vital_reg_mobile/features/death_registration/presentation/home/view/death_registration_home_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_death_registration_repository.dart';

final _today = DateTime(2026, 10, 4);

const _file = AttachedFile(path: 'a.jpg', name: 'a.jpg', sizeBytes: 10);

/// Without a NIN; a Nigerian living in Bauchi who died at home.
DeceasedParticulars _deceased() {
  var d = const DeceasedParticulars();
  for (final (field, value) in [
    (DeceasedField.noNinReason, 'Never enrolled'),
    (DeceasedField.surname, 'Allison'),
    (DeceasedField.firstName, 'Favour'),
    (DeceasedField.sex, '2'),
    (DeceasedField.country, DeathCodes.nigeria),
    (DeceasedField.state, '5'),
    (DeceasedField.lga, '51'),
    (DeceasedField.address, 'No.3 Owerri street'),
    (DeceasedField.settlement, '2'),
    (DeceasedField.occupation, '100'),
    (DeceasedField.dateOfDeath, DateTime(2026, 9, 22).toIso8601String()),
    (DeceasedField.placeOfDeath, '2'),
    (DeceasedField.village, 'Amaba'),
    (DeceasedField.ageAtDeath, '90'),
    (DeceasedField.nationality, DeathCodes.nigeria),
    (DeceasedField.stateOfOrigin, '5'),
    (DeceasedField.lgaOfOrigin, '51'),
    (DeceasedField.ethnicGroup, '4'),
    (DeceasedField.maritalStatus, '1'),
    (DeceasedField.certifiedByDoctor, '1'),
    (DeceasedField.causeOfDeath, '3'),
    (DeceasedField.registrationState, '5'),
    (DeceasedField.registrationLga, '51'),
    (DeceasedField.registrationCenter, '9'),
  ]) {
    d = d.set(field, value);
  }
  return d;
}

InformantParticulars _informant() => const InformantParticulars(
  FieldValues({
    InformantField.nin: '12342567890',
    InformantField.surname: 'Doe',
    InformantField.firstName: 'John',
    InformantField.relationship: '3',
    InformantField.sameAddress: DeathCodes.no,
    InformantField.country: '31',
    InformantField.phone: '08045365780',
  }),
  '12342567890',
);

DeathDocuments _documents() => const DeathDocuments()
    .set(DeathDocument.policeReport, _file)
    .set(DeathDocument.nextOfKinLetter, _file)
    .set(DeathDocument.affidavit, _file);

DeathDraft _complete({DeathStep step = DeathStep.review}) => DeathDraft(
  startedOn: _today,
  step: step,
  deceased: _deceased(),
  informant: _informant(),
  documents: _documents(),
  signature: 'sign.png',
);

DeathFormCubit _cubit(FakeDeathRegistrationRepository repository) =>
    DeathFormCubit(
      repository,
      now: () => _today,
      newSubmissionKey: () => 'key-1',
    );

void main() {
  group('rules', () {
    test('without a NIN a reason is needed; with one it must be verified', () {
      expect(_deceased().isComplete(today: _today), isTrue);
      final noReason = _deceased().set(DeceasedField.noNinReason, null);
      expect(
        noReason.errorOf(DeceasedField.noNinReason, today: _today),
        DeathFieldError.required,
      );

      final typed = _deceased().set(DeceasedField.nin, '1234');
      expect(typed.applies(DeceasedField.noNinReason), isFalse);
      expect(
        typed.errorOf(DeceasedField.nin, today: _today),
        DeathFieldError.invalidNin,
      );
      // A NIN replaces the typed names until it is verified.
      final full = _deceased().set(DeceasedField.nin, '65783893030');
      expect(full[DeceasedField.surname], isNull);
      expect(
        full.errorOf(DeceasedField.nin, today: _today),
        DeathFieldError.ninNotVerified,
      );
      final verified = full.verified(
        nin: '65783893030',
        surname: 'Allison',
        firstName: 'Favour',
      );
      expect(verified.errorOf(DeceasedField.nin, today: _today), isNull);
      expect(verified[DeceasedField.surname], 'Allison');
      expect(
        verified
            .set(DeceasedField.nin, '65783893031')
            .errorOf(DeceasedField.nin, today: _today),
        DeathFieldError.ninNotVerified,
      );
    });

    test('age at death is at most 150; the date 1992 to today', () {
      DeathFieldError? error(DeceasedField field, String value) =>
          _deceased().set(field, value).errorOf(field, today: _today);
      expect(
        error(DeceasedField.ageAtDeath, '151'),
        DeathFieldError.invalidAge,
      );
      expect(error(DeceasedField.ageAtDeath, '150'), isNull);
      expect(
        error(DeceasedField.dateOfDeath, DateTime(2026, 10, 5).toString()),
        DeathFieldError.futureDate,
      );
      expect(
        error(DeceasedField.dateOfDeath, DateTime(1992).toString()),
        DeathFieldError.tooEarly,
      );
    });

    test('literacy is optional; education only when literate', () {
      final d = _deceased();
      expect(d.applies(DeceasedField.educationLevel), isFalse);
      final literate = d.set(DeceasedField.literacy, DeathCodes.literate);
      expect(
        literate.errorOf(DeceasedField.educationLevel, today: _today),
        DeathFieldError.required,
      );
      expect(
        literate.set(DeceasedField.literacy, '2').isComplete(today: _today),
        isTrue,
      );
    });

    test('a foreign deceased has no Nigerian residence or origin', () {
      final abroad = _deceased()
          .set(DeceasedField.country, '31')
          .set(DeceasedField.nationality, '31');
      expect(abroad[DeceasedField.state], isNull);
      expect(abroad[DeceasedField.ethnicGroup], isNull);
      expect(abroad.isComplete(today: _today), isTrue);
    });

    test('the informant needs a verified NIN and an 11-digit phone', () {
      expect(_informant().isComplete, isTrue);
      expect(
        _informant()
            .set(InformantField.phone, '0804')
            .errorOf(InformantField.phone),
        DeathFieldError.invalidPhone,
      );
      expect(
        _informant().set(InformantField.nin, null).errorOf(InformantField.nin),
        DeathFieldError.required,
      );
    });

    test('police report unless in hospital; medical proof only then', () {
      bool required(DeathDocument d, String place) =>
          d.isRequired(placeOfDeath: place);
      expect(required(DeathDocument.policeReport, '2'), isTrue);
      expect(required(DeathDocument.medicalProofOfDeath, '2'), isFalse);
      expect(required(DeathDocument.policeReport, '1'), isFalse);
      expect(required(DeathDocument.medicalProofOfDeath, '1'), isTrue);
      expect(required(DeathDocument.employersReport, '2'), isFalse);
      expect(_documents().isComplete(placeOfDeath: '2'), isTrue);
      expect(_documents().isComplete(placeOfDeath: '1'), isFalse);
    });
  });

  group('payload (POST /death-registration/add)', () {
    test('sends ids as numbers, uploaded keys and only applying fields', () {
      final json = deathToJson(
        _complete(),
        places: sampleDeathReferenceData,
        documents: {
          DeathDocument.policeReport: 'k/police.jpg',
          DeathDocument.affidavit: 'k/affidavit.jpg',
        },
        signature: 'k/sign.png',
      );
      expect(json['deceased_sex'], 2);
      expect(json['deceased_state'], 5);
      expect(json['deceased_age_at_death'], 90);
      expect(json['deceased_level_of_education'], isNull);
      // A new registration has no reason.
      expect(json.containsKey('no_nin_reason'), isFalse);
      expect(json['registration_center'], 9);
      // Codes, not ids.
      expect(json['deceased_state_code'], 'BA');
      expect(json['deceased_lga_code'], '510');
      expect(json['informant_state'], isNull);
      expect(json['informant_phone_number'], '08045365780');
      expect(json['informant_signature'], 'k/sign.png');
      final docs = json['SupportingDocument']! as List<Object?>;
      expect(docs, hasLength(5));
      expect(docs.first, {
        'type': 'police-report',
        'file': 'k/police.jpg',
        'mimeType': 'image/jpeg',
      });
    });

    test('reads the counts and the list', () {
      // SQL sums, which arrive as strings.
      final counts = deathCountsFromJson({'Pending': '2', 'Queried': '1'});
      expect(counts.of(ApplicationStatus.pending), 2);
      expect(counts.of(ApplicationStatus.queried), 1);
      final rows = deathRegistrationsFromJson({
        'result': [
          {
            'id': 7,
            'death_certificate_number': 'DC1',
            'deceasedData': {'surname': 'Lee', 'firstname': 'Michael'},
            'date_created': '2026-09-23',
          },
        ],
      }, status: ApplicationStatus.approved);
      expect(rows.single.childName, 'Lee Michael');
      expect(rows.single.trackingId, 'DC1');
      expect(rows.single.status, ApplicationStatus.approved);
    });
  });

  group('a recorded registration (the API\'s shapes)', () {
    test('reads deceasedData, informantData and the files', () {
      final record = deathRecordFromJson({
        'data': {
          'id': 40300,
          'death_certificate_number': 'DC1',
          'status': 'queried',
          'date_created': '2026-09-23',
          'deceased_date_of_death': '2026-09-22T00:00:00.000Z',
          'deceased_age_at_death': 90,
          'informant_signature': 'k/sign.png',
          'query_reason': 'Wrong document uploaded',
          'SupportingDocument': [
            {'type': 'affidavit', 'file': 'k/affidavit.jpg'},
            {'type': 'next-of-kin', 'file': ''},
          ],
          'deceasedData': {
            'surname': 'Allison',
            'firstname': 'Favour',
            'nin': '65783893030',
            'current_residence_country': 63,
            'current_residence_state': 5,
            'current_residence_lga': 51,
            'origin_country': 63,
          },
          'informantData': {
            'nin': '12342567890',
            'surname': 'Doe',
            'current_phone_number': '08045365780',
          },
        },
      });
      expect(record.summary.status, ApplicationStatus.queried);
      expect(record.summary.childName, 'Allison Favour');
      expect(record.deceased.ninVerified, isTrue);
      expect(record.deceased[DeceasedField.lga], '51');
      expect(record.deceased.dateOfDeath, DateTime(2026, 9, 22));
      expect(record.deceased[DeceasedField.ageAtDeath], '90');
      expect(record.informant.ninVerified, isTrue);
      expect(record.informant[InformantField.sameAddress], DeathCodes.no);
      expect(record.documentKeys, {DeathDocument.affidavit: 'k/affidavit.jpg'});
      expect(record.signatureKey, 'k/sign.png');
      expect(record.queryReason, 'Wrong document uploaded');
    });

    test('the update keeps files on record and adds the record\'s ids', () {
      final draft = _complete().copyWith(documents: const DeathDocuments());
      final queried = DeathDraft(
        startedOn: _today,
        deceased: draft.deceased,
        informant: draft.informant,
        queried: const QueriedDeath(
          recordId: '40300',
          certificateNumber: 'DC1',
          queryReason: 'Wrong document uploaded',
        ),
      );
      final json = deathUpdateToJson(
        queried,
        places: sampleDeathReferenceData,
        documents: {DeathDocument.affidavit: 'k/affidavit.jpg'},
        signature: 'k/sign.png',
      );
      expect(json['id'], 40300);
      expect(json['death_certificate_number'], 'DC1');
      expect(json['query_reason'], 'Wrong document uploaded');
      expect(json['registration_state'], 5);
      expect(json['registration_lga'], 51);
      expect(json['informant_signature'], 'k/sign.png');
      expect(json['SupportingDocument'], [
        {'type': 'affidavit', 'file': 'k/affidavit.jpg', 'mimeType': null},
      ]);
    });
  });

  group('correcting a queried record', () {
    late FakeDeathRegistrationRepository repository;

    setUp(() => repository = FakeDeathRegistrationRepository());

    DeathFormCubit correction() => DeathFormCubit(
      repository,
      queriedRecordId: '40300',
      now: () => _today,
      newSubmissionKey: () => 'key-1',
    );

    test('opens the record; files on record count as provided', () async {
      final cubit = correction();
      await cubit.load();
      expect(cubit.state.isCorrection, isTrue);
      expect(cubit.state.isComplete(DeathStep.deceased, _today), isTrue);
      expect(cubit.state.isComplete(DeathStep.informant, _today), isTrue);
      // The next-of-kin letter is missing: what was queried.
      expect(cubit.state.isComplete(DeathStep.documents, _today), isFalse);
      expect(cubit.state.draft!.hasSignature, isTrue);
    });

    test('is never saved on the device, and is sent as an update', () async {
      final cubit = correction();
      await cubit.load();
      await cubit.documentPicked(
        DeathDocument.nextOfKinLetter,
        path: 'tmp.jpg',
        name: 'kin.jpg',
        sizeBytes: 10,
      );
      expect(repository.draft, isNull);
      cubit.declarationChanged(declared: true);
      await cubit.submit();
      expect(repository.submitted, isEmpty);
      final sent = repository.updated.single;
      expect(sent.queried!.recordId, '40300');
      expect(sent.documents[DeathDocument.nextOfKinLetter]?.name, 'kin.jpg');
      expect(cubit.state.submitStatus, SubmitStatus.submitted);
      expect(cubit.state.trackingId, 'DC30087677');
      // The replacement was sent, so the device copy is deleted.
      expect(repository.deleted, contains('document-1.jpg'));
    });
  });

  group('DeathFormCubit', () {
    late FakeDeathRegistrationRepository repository;

    setUp(() => repository = FakeDeathRegistrationRepository());

    test('verifying a NIN fills the names and locks them', () async {
      final cubit = _cubit(repository);
      await cubit.load();
      cubit.deceasedChanged(DeceasedField.nin, '65783893030');
      expect(cubit.state.isLocked(DeceasedField.surname), isTrue);
      await cubit.verifyNin(NinOwner.deceased);
      final deceased = cubit.state.draft!.deceased;
      expect(deceased.ninVerified, isTrue);
      expect(deceased[DeceasedField.surname], 'Allison');
      cubit.deceasedChanged(DeceasedField.surname, 'Other');
      expect(cubit.state.draft!.deceased[DeceasedField.surname], 'Allison');
    });

    test('an unknown NIN shows why', () async {
      final cubit = _cubit(repository);
      await cubit.load();
      cubit.informantChanged(InformantField.nin, '00000000000');
      await cubit.verifyNin(NinOwner.informant);
      expect(
        cubit.state.ninFailures[NinOwner.informant],
        const NotFoundFailure(),
      );
      expect(cubit.state.draft!.informant.ninVerified, isFalse);
      cubit.informantChanged(InformantField.nin, '00000000001');
      expect(cubit.state.ninFailures, isEmpty);
    });

    test('"Yes" copies the deceased\'s residence to the informant', () async {
      repository.draft = _complete(
        step: DeathStep.informant,
      ).copyWith(informant: const InformantParticulars());
      final cubit = _cubit(repository);
      await cubit.load();
      cubit.informantChanged(InformantField.sameAddress, DeathCodes.yes);
      final informant = cubit.state.draft!.informant;
      expect(informant[InformantField.country], DeathCodes.nigeria);
      expect(informant[InformantField.state], '5');
      expect(informant[InformantField.lga], '51');
      expect(informant[InformantField.address], 'No.3 Owerri street');
      expect(informant[InformantField.settlement], '2');
    });

    test('documents are checked, kept and removed', () async {
      repository.draft = _complete(step: DeathStep.documents);
      final cubit = _cubit(repository);
      await cubit.load();
      expect(
        await cubit.documentPicked(
          DeathDocument.employersReport,
          path: 'x.pdf',
          name: 'x.pdf',
          sizeBytes: 10,
        ),
        DocumentError.unsupportedType,
      );
      await cubit.documentPicked(
        DeathDocument.employersReport,
        path: 'tmp.jpg',
        name: 'report.jpg',
        sizeBytes: 10,
      );
      expect(
        cubit.state.draft!.documents[DeathDocument.employersReport]?.name,
        'report.jpg',
      );
      await cubit.documentRemoved(DeathDocument.employersReport);
      expect(
        cubit.state.draft!.documents[DeathDocument.employersReport],
        isNull,
      );
      expect(repository.deleted, ['document-1.jpg']);
    });

    test('the preview needs the signature and the declaration', () async {
      repository.draft = _complete().copyWith(signature: () => null);
      final cubit = _cubit(repository);
      await cubit.load();
      cubit.declarationChanged(declared: true);
      await cubit.submit();
      expect(cubit.state.showErrors, isTrue);
      expect(repository.submitted, isEmpty);

      await cubit.signatureDrawn(Uint8List(4));
      await cubit.submit();
      expect(repository.submitted.single.signature, 'signature-1.png');
      expect(repository.submitted.single.submissionKey, 'key-1');
      expect(cubit.state.submitStatus, SubmitStatus.submitted);
      expect(cubit.state.trackingId, 'DR123');
      expect(repository.draft, isNull);
    });

    test('a failed submission keeps the draft', () async {
      repository
        ..draft = _complete()
        ..submitResult = const Err(NetworkFailure());
      final cubit = _cubit(repository);
      await cubit.load();
      cubit.declarationChanged(declared: true);
      await cubit.submit();
      expect(cubit.state.submitStatus, SubmitStatus.failed);
      expect(repository.draft!.submissionKey, 'key-1');
    });
  });

  group('screens', () {
    /// A tall screen, so whole steps are built.
    void tallScreen(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(400, 8000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('home shows the four status cards and records', (tester) async {
      tallScreen(tester);
      await tester.pumpApp(
        DeathRegistrationHomePage(
          onOpenForm: () async {},
          onOpenRegistration: (_) async {},
          onUpdateQueried: (_) async {},
          repository: FakeDeathRegistrationRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Death Registration'), findsOneWidget);
      expect(find.text('Pending Approvals'), findsOneWidget);
      expect(find.text('Queried Registrations'), findsOneWidget);
      expect(find.text('Lee Michael'), findsOneWidget);
    });

    testWidgets('a queried row asks first; Update opens the correction', (
      tester,
    ) async {
      tallScreen(tester);
      final opened = <String>[];
      final updated = <String>[];
      await tester.pumpApp(
        DeathRegistrationHomePage(
          onOpenForm: () async {},
          onOpenRegistration: (id) async => opened.add(id),
          onUpdateQueried: (id) async => updated.add(id),
          repository: FakeDeathRegistrationRepository()
            ..listedStatus = ApplicationStatus.queried,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lee Michael'));
      await tester.pumpAndSettle();
      expect(find.text('Queried Record'), findsOneWidget);
      expect(
        find.textContaining('Wrong document uploaded', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(updated, ['40000']);
      expect(opened, isEmpty);
    });

    testWidgets('other rows open Certificate Details', (tester) async {
      tallScreen(tester);
      final opened = <String>[];
      await tester.pumpApp(
        DeathRegistrationHomePage(
          onOpenForm: () async {},
          onOpenRegistration: (id) async => opened.add(id),
          onUpdateQueried: (_) async {},
          repository: FakeDeathRegistrationRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lee Michael'));
      await tester.pumpAndSettle();
      expect(opened, ['40000']);
    });

    testWidgets('Certificate Details shows the record and the query', (
      tester,
    ) async {
      tallScreen(tester);
      var updates = 0;
      await tester.pumpApp(
        DeathDetailsPage(
          id: '40300',
          onUpdate: () => updates++,
          repository: FakeDeathRegistrationRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Certificate Details'), findsOneWidget);
      expect(find.text('Queried: Wrong document uploaded'), findsOneWidget);
      expect(find.text('Amaba'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      await tester.tap(find.text('Update'));
      expect(updates, 1);
    });

    testWidgets('step 1 asks for a reason without a NIN', (tester) async {
      tallScreen(tester);
      await tester.pumpApp(
        DeathFormPage(
          onExit: () {},
          repository: FakeDeathRegistrationRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(
        find.text('Reason (If NIN of deceased is unavailable)'),
        findsOneWidget,
      );
      expect(find.text('Verify'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '65783893030');
      await tester.pumpAndSettle();
      expect(
        find.text('Reason (If NIN of deceased is unavailable)'),
        findsNothing,
      );
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('(Verified)', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Allison'), findsOneWidget);
    });

    testWidgets('the documents step marks what a home death needs', (
      tester,
    ) async {
      final repository = FakeDeathRegistrationRepository()
        ..draft = _complete(
          step: DeathStep.documents,
        ).copyWith(documents: const DeathDocuments());
      await tester.pumpApp(
        DeathFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Upload Police Report'), findsOneWidget);
      expect(find.text('Upload Medical Proof of Death'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      // Police report, next-of-kin letter and affidavit.
      expect(find.text('This field is required.'), findsNWidgets(3));
    });

    testWidgets('the preview lists every step, then the signature', (
      tester,
    ) async {
      tallScreen(tester);
      final repository = FakeDeathRegistrationRepository()
        ..draft = _complete().copyWith(signature: () => null);
      await tester.pumpApp(
        DeathFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 4 of 4'), findsOneWidget);
      expect(find.text('Particulars of Deceased'), findsWidgets);
      expect(find.text('Amaba'), findsOneWidget);
      expect(find.text('Fever'), findsOneWidget);
      expect(find.text('Doe'), findsOneWidget);
      expect(find.text('Documents Upload'), findsOneWidget);
      expect(find.text('Edit'), findsNWidgets(3));
      expect(
        find.textContaining("Informant's Signature", findRichText: true),
        findsOneWidget,
      );
    });
  });
}
