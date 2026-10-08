import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/adopted_child/data/dtos/adoption_dtos.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_draft.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_form.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_record.dart';
import 'package:vital_reg_mobile/features/adopted_child/presentation/details/cubit/adoption_details_cubit.dart';
import 'package:vital_reg_mobile/features/adopted_child/presentation/details/view/adoption_details_page.dart';
import 'package:vital_reg_mobile/features/adopted_child/presentation/form/cubit/adoption_form_cubit.dart';
import 'package:vital_reg_mobile/features/adopted_child/presentation/form/view/adoption_form_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_adopted_child_repository.dart';

final _today = DateTime(2026, 10, 4);

/// A record in the backend's flat shape.
Map<String, Object?> _rawRecord({int status = 2, int? lastSection}) => {
  'data': {
    'id': 7,
    'referenceId': 'ACR-2026-0003150',
    'status': status,
    'createdAt': '2026-08-12T10:00:00Z',
    'remarks': 'Wrong date of birth',
    'certificateNo': 'ACR/LA/2026/0041',
    'paymentReference': 'PAID1',
    'childNinVerified': false,
    'lastCompletedSection': ?lastSection,
    'childSurname': 'Hassan',
    'childFirstName': 'Suleiman',
    'dateOfBirth': '2015-09-09T00:00:00Z',
    'childSex': 1,
    'birthOrder': 1,
    'regState': 25,
    'regLga': 501,
    'regCenter': 5011,
    'childFace': 'faces/child.png',
    'ad1FullName': 'Ololade Semiola Ade',
    'ad1Nin': '72921010909',
    'ad1MaritalStatus': 1,
    'ad1Nationality': 63,
    'ad1Address': 'No 12 Adeleke road',
    'ad1Occupation': 100,
    'ad1ResidenceCountry': 63,
    'ad1ResidenceState': 25,
    'ad2Present': true,
    'ad2FullName': 'Ololade Adegoke',
    'courtName': 'Federal High Court',
    'orderReferenceNo': 'FCT/HC/CV/1889/2026',
    'adoptionOrderDate': '2025-09-09',
    'adoptionType': 'inter_country',
    'infSurname': 'Keith',
    'infFirstName': 'Ryan',
    'infSameResidenceAsAdopter1': false,
    'infCountry': 31,
    'infRelationshipToChild': 13,
    'infPhone': '08123123123',
    'infConsentType': 'face_capture',
    'infSignature': 'faces/informant.png',
    'supportingDocument': [
      {'type': 'court_adoption_order', 'file': 'docs/order.jpg'},
      {'type': 'adoptive_father_identity_document', 'file': 'docs/id2.png'},
      {'type': 'international-passport', 'file': 'docs/passport.jpg'},
    ],
  },
};

void main() {
  group('reading a record back (the API\'s shape)', () {
    test('fills the form, splitting the adopters\' full names', () {
      final record = adoptionRecordFromJson(_rawRecord());
      expect(record.id, '7');
      expect(record.status, AdoptionRecordStatus.queried);
      expect(record.remarks, 'Wrong date of birth');
      expect(record.certificateNumber, 'ACR/LA/2026/0041');
      final draft = record.draft;
      expect(draft.child[ChildField.surname], 'Hassan');
      expect(draft.child.dateOfBirth, DateTime(2015, 9, 9));
      expect(draft.child[ChildField.registrationLga], '501');
      expect(draft.adopter1[AdopterField.surname], 'Ololade');
      expect(draft.adopter1[AdopterField.firstName], 'Semiola');
      expect(draft.adopter1[AdopterField.middleName], 'Ade');
      expect(draft.adopter1.isNinVerified, isTrue);
      expect(draft.hasAdopter2, isTrue);
      expect(draft.adopter2[AdopterField.firstName], 'Adegoke');
      expect(
        draft.details[AdoptionDetailsField.orderReference],
        'FCT/HC/CV/1889/2026',
      );
      expect(draft.details[AdoptionDetailsField.adoptionType], 'inter_country');
      expect(draft.ninDecision, ChildNinDecision.skipped);
      expect(draft.paymentReference, 'PAID1');
    });

    test('a face consent comes back as the face, not the signature', () {
      final informant = adoptionRecordFromJson(_rawRecord()).draft.informant;
      expect(informant[InformantField.consentType], ConsentType.faceCapture);
      expect(informant[InformantField.face], 'faces/informant.png');
      expect(informant[InformantField.signature], isNull);
      expect(informant[InformantField.sameResidence], Answer.no);
    });

    test('files come back as storage keys, already uploaded', () {
      final draft = adoptionRecordFromJson(_rawRecord()).draft;
      expect(
        draft.documents[AdoptionDocument.courtOrder]?.path,
        'docs/order.jpg',
      );
      expect(
        draft.documents[AdoptionDocument.adopter2Identity]?.path,
        'docs/id2.png',
      );
      expect(draft.informantPassport?.path, 'docs/passport.jpg');
      expect(draft.uploads['faces/child.png'], 'faces/child.png');
      expect(draft.uploads['docs/order.jpg'], 'docs/order.jpg');
    });

    test('a draft resumes after the last section saved', () {
      expect(
        adoptionRecordFromJson(
          _rawRecord(status: 3, lastSection: 2),
        ).draft.step,
        AdoptionStep.adoptionDetails,
      );
      expect(
        adoptionRecordFromJson(
          _rawRecord(status: 3, lastSection: 5),
        ).draft.step,
        AdoptionStep.review,
      );
      expect(
        adoptionRecordFromJson(_rawRecord(status: 3)).status,
        AdoptionRecordStatus.drafted,
      );
    });

    test('a correction is sent whole, without a section number', () {
      final json = adoptionSectionToJson(
        completeDraft(),
        section: null,
        stateName: (_) => null,
      );
      expect(json.containsKey('section'), isFalse);
      expect(json['childSurname'], 'Hassan');
      expect(json['ad1FullName'], 'Ololade Semiola');
    });
  });

  group('AdoptionFormCubit (queried)', () {
    late FakeAdoptedChildRepository repository;
    setUp(() => repository = FakeAdoptedChildRepository());

    AdoptionFormCubit build() => AdoptionFormCubit(
      repository,
      queriedId: 'adoption-queried-0',
      now: () => _today,
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'opens the queried record on the review with its reason',
      setUp: () => repository.detailsResult = Ok(sampleRecord()),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.status, FormStatus.ready);
        expect(cubit.state.step, AdoptionStep.review);
        expect(
          cubit.state.queryReason,
          'The date of birth does not match the court order.',
        );
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'edits stay in memory and are not saved section by section',
      setUp: () => repository.detailsResult = Ok(sampleRecord()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit
          ..editStep(AdoptionStep.child)
          ..childChanged(ChildField.middleName, 'Bala');
        await cubit.next();
      },
      verify: (cubit) {
        expect(repository.draft, isNull);
        expect(repository.savedSections, isEmpty);
        expect(cubit.state.step, AdoptionStep.review);
        expect(cubit.state.draft!.child[ChildField.middleName], 'Bala');
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'Submit resends the correction and keeps the payment',
      setUp: () => repository.detailsResult = Ok(sampleRecord()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(repository.amended.single.referenceId, 'ACR-2026-0003150');
        expect(repository.submitted, isEmpty);
        expect(repository.payments.clears, 0);
        expect(cubit.state.submitStatus, SubmitStatus.submitted);
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'a record that cannot be loaded offers to try again',
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.status, FormStatus.failure),
    );
  });

  group('AdoptionDetailsCubit', () {
    late FakeAdoptedChildRepository repository;
    setUp(() => repository = FakeAdoptedChildRepository());

    blocTest<AdoptionDetailsCubit, AdoptionDetailsState>(
      'continuing a draft puts it on the device and says where to resume',
      setUp: () {
        final draft = sampleRecord(
          status: AdoptionRecordStatus.drafted,
          draft: completeDraft().copyWith(step: AdoptionStep.informant),
        );
        repository
          ..detailsResult = Ok(draft)
          ..resumeResult = Ok(draft)
          ..draft = AdoptionDraft(referenceId: 'OTHER', startedOn: _today);
      },
      build: () => AdoptionDetailsCubit(repository, id: 'adoption-drafted-0'),
      act: (cubit) async {
        await cubit.load();
        expect(await cubit.wouldReplaceDraft(), isTrue);
        await cubit.continueDraft();
      },
      verify: (cubit) {
        expect(repository.draft!.referenceId, 'ACR-2026-0003150');
        expect(repository.draft!.step, AdoptionStep.informant);
        expect(cubit.state.resumedAt, AdoptionStage.form);
      },
    );

    blocTest<AdoptionDetailsCubit, AdoptionDetailsState>(
      'a failed resume is reported',
      setUp: () => repository
        ..detailsResult = Ok(sampleRecord(status: AdoptionRecordStatus.drafted))
        ..resumeResult = const Err(NetworkFailure()),
      build: () => AdoptionDetailsCubit(repository, id: 'adoption-drafted-0'),
      act: (cubit) async {
        await cubit.load();
        await cubit.continueDraft();
      },
      verify: (cubit) {
        expect(cubit.state.resumeFailure, isA<NetworkFailure>());
        expect(cubit.state.resumedAt, isNull);
      },
    );
  });

  group('screens', () {
    testWidgets('details of a queried record offer Respond to Query', (
      tester,
    ) async {
      final repository = FakeAdoptedChildRepository()
        ..detailsResult = Ok(sampleRecord());
      var responded = false;
      await tester.pumpApp(
        AdoptionDetailsPage(
          id: 'adoption-queried-0',
          onRespondToQuery: () => responded = true,
          onContinue: (_) {},
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Certificate Details'), findsOneWidget);
      expect(
        find.text('The date of birth does not match the court order.'),
        findsOneWidget,
      );
      expect(find.text('Particulars of Adopter 1'), findsOneWidget);
      await tester.tap(find.text('Respond to Query'));
      expect(responded, isTrue);
    });

    testWidgets('details of an approved record have no action', (tester) async {
      final repository = FakeAdoptedChildRepository()
        ..detailsResult = Ok(
          sampleRecord(status: AdoptionRecordStatus.approved),
        );
      await tester.pumpApp(
        AdoptionDetailsPage(
          id: 'adoption-approved-0',
          onRespondToQuery: () {},
          onContinue: (_) {},
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Respond to Query'), findsNothing);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('a correction says so when it is sent', (tester) async {
      final repository = FakeAdoptedChildRepository()
        ..detailsResult = Ok(sampleRecord());
      await tester.pumpApp(
        AdoptionFormPage(
          queriedId: 'adoption-queried-0',
          onExit: () {},
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('REASON FOR QUERY'), findsOneWidget);
      expect(
        find.text('The date of birth does not match the court order.'),
        findsOneWidget,
      );
      final declaration = find.byType(Checkbox);
      await tester.ensureVisible(declaration);
      await tester.pumpAndSettle();
      await tester.tap(declaration);
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Corrections Submitted'), findsOneWidget);
      expect(repository.amended, hasLength(1));
    });
  });
}
