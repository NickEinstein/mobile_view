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
import 'package:vital_reg_mobile/features/adopted_child/presentation/nin/cubit/child_nin_cubit.dart';
import 'package:vital_reg_mobile/features/adopted_child/presentation/nin/view/child_nin_page.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';

import '../../helpers/pump_app.dart';
import 'fake_adopted_child_repository.dart';

final _today = DateTime(2026, 10, 4);

void main() {
  group('rules', () {
    test('only surname, first name, date of birth and sex are required', () {
      const empty = ChildParticulars();
      for (final field in ChildField.values) {
        expect(
          empty.errorOf(field, today: _today),
          field.isRequired ? AdoptionFieldError.required : isNull,
          reason: field.name,
        );
      }
      expect(
        ChildField.values.where((f) => f.isRequired),
        unorderedEquals([
          ChildField.surname,
          ChildField.firstName,
          ChildField.dateOfBirth,
          ChildField.sex,
        ]),
      );
      expect(completeChild().isComplete(today: _today), isTrue);
    });

    test('the date of birth cannot be in the future', () {
      expect(
        completeChild()
            .set(
              ChildField.dateOfBirth,
              DateTime(2026, 10, 5).toIso8601String(),
            )
            .errorOf(ChildField.dateOfBirth, today: _today),
        AdoptionFieldError.futureDate,
      );
    });

    test('a new state clears what depended on it', () {
      final child = completeChild()
          .set(ChildField.registrationState, '25')
          .set(ChildField.registrationLga, '501')
          .set(ChildField.registrationCenter, '5011')
          .set(ChildField.registrationState, '15');
      expect(child[ChildField.registrationLga], isNull);
      expect(child[ChildField.registrationCenter], isNull);
    });

    test('steps map onto the API sections', () {
      expect(AdoptionStep.child.section!.number, 1);
      expect(AdoptionStep.adopter1.section, AdoptionSection.parents);
      expect(AdoptionStep.adopter2.section, AdoptionSection.parents);
      expect(AdoptionStep.adoptionDetails.section!.number, 3);
      expect(AdoptionStep.informant.section!.number, 4);
      expect(AdoptionStep.documents.section!.number, 5);
      expect(AdoptionStep.review.section, isNull);
      expect(AdoptionStep.values, hasLength(AdoptionStep.count));
    });
  });

  group('draft', () {
    test('picks up at the NIN, then payment, then the form', () {
      final started = AdoptionDraft(referenceId: 'R', startedOn: _today);
      expect(started.stage, AdoptionStage.nin);
      final decided = started.copyWith(ninDecision: ChildNinDecision.skipped);
      expect(decided.stage, AdoptionStage.payment);
      expect(decided.copyWith(paymentReference: 'P').stage, AdoptionStage.form);
    });

    test('a verified NIN locks the surname, first name and sex', () {
      final draft = paidDraft().copyWith(
        ninDecision: ChildNinDecision.verified,
      );
      expect(draft.isLocked(ChildField.surname), isTrue);
      expect(draft.isLocked(ChildField.firstName), isTrue);
      expect(draft.isLocked(ChildField.sex), isTrue);
      expect(draft.isLocked(ChildField.dateOfBirth), isFalse);
      expect(paidDraft().isLocked(ChildField.surname), isFalse);
    });

    test('survives a round trip through JSON', () {
      final draft = paidDraft(step: AdoptionStep.adopter1).copyWith(
        childNin: () => '12345678901',
        child: completeChild().set(ChildField.facePhoto, '/face.jpg'),
        uploads: {'/face.jpg': 'key/face.jpg'},
      );
      expect(AdoptionDraft.fromJson(draft.toJson()), draft);
    });
  });

  group('API shapes', () {
    test('stats use capitalised keys', () {
      final counts = countsFromJson({
        'Pending': 3,
        'Approved': '2',
        'Queried': 1,
        'Printed': 2,
      });
      expect(counts.of(ApplicationStatus.pending), 3);
      expect(counts.of(ApplicationStatus.approved), 2);
    });

    test('list rows map status codes; a draft without a name shows its '
        'reference', () {
      final rows = applicationsFromJson({
        'result': [
          {
            'id': 7,
            'referenceId': 'ACR-1',
            'status': 1,
            'childSurname': 'Johnson',
            'childFirstName': 'Sarah',
            'createdAt': '2026-08-12',
          },
          {
            'id': 8,
            'referenceId': 'ACR-2',
            'status': 3,
            'createdAt': '2026-08-01',
          },
        ],
      }, requested: ApplicationStatus.pending);
      expect(rows.first.childName, 'Johnson Sarah');
      expect(rows.first.status, ApplicationStatus.approved);
      expect(rows.last.childName, 'ACR-2');
      expect(rows.last.status, ApplicationStatus.pending);
    });

    test('the child section is sent with the API field names', () {
      final draft = paidDraft().copyWith(
        child: completeChild()
            .set(ChildField.previousFullName, 'Gimba Bala')
            .set(ChildField.birthOrder, '1')
            .set(ChildField.registrationState, '25')
            .set(ChildField.registrationLga, '501')
            .set(ChildField.registrationCenter, '5011')
            .set(ChildField.localityOfBirth, '2')
            .set(ChildField.facePhoto, '/face.jpg'),
        uploads: {'/face.jpg': 'key/face.jpg'},
      );
      final json = adoptionSectionToJson(
        draft,
        section: AdoptionSection.child,
        stateName: (_) => null,
      );
      expect(json['section'], 1);
      expect(json['paymentReference'], 'BRTPAID1');
      expect(json['childSurname'], 'Hassan');
      expect(json['childMiddleName'], isNull);
      expect(json['childPreviousFullName'], 'Gimba Bala');
      expect(json['dateOfBirth'], '2015-09-09');
      expect(json['childSex'], 1);
      expect(json['birthOrder'], 1);
      expect(json['birthCountry'], 63);
      expect(json['birthState'], isNull);
      expect(json['regState'], 25);
      expect(json['regLga'], 501);
      expect(json['regCenter'], 5011);
      expect(json['localityType'], 2);
      expect(json['childFace'], 'key/face.jpg');
    });
  });

  group('ChildNinCubit', () {
    late FakeAdoptedChildRepository repository;
    setUp(() => repository = FakeAdoptedChildRepository());

    ChildNinCubit build() => ChildNinCubit(repository, now: () => _today);

    blocTest<ChildNinCubit, ChildNinState>(
      'creates the application on the server and keeps it',
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(repository.initiated, 1);
        expect(repository.draft?.referenceId, 'ACR-2026-0003150');
        expect(cubit.state.justCreated, isTrue);
        expect(cubit.state.step, ChildNinStep.ready);
      },
    );

    blocTest<ChildNinCubit, ChildNinState>(
      'continues the application on the device instead of creating one',
      setUp: () => repository.draft = AdoptionDraft(
        referenceId: 'ACR-OLD',
        startedOn: _today,
      ),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(repository.initiated, 0);
        expect(cubit.state.referenceId, 'ACR-OLD');
        expect(cubit.state.justCreated, isFalse);
      },
    );

    blocTest<ChildNinCubit, ChildNinState>(
      'offers to try again when the application cannot be created',
      setUp: () => repository.initiateResult = const Err(NetworkFailure()),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.step, ChildNinStep.startFailed);
        expect(repository.draft, isNull);
      },
    );

    blocTest<ChildNinCubit, ChildNinState>(
      'an unknown NIN is not recorded',
      setUp: () => repository.ninResult = const Err(NotFoundFailure()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.ninChanged('12345678901');
        await cubit.validate();
      },
      verify: (cubit) {
        expect(cubit.state.failure, isA<NotFoundFailure>());
        expect(repository.verified, isEmpty);
        expect(repository.draft?.ninDecision, isNull);
      },
    );

    blocTest<ChildNinCubit, ChildNinState>(
      'a verified NIN is recorded and fills the child',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.ninChanged('12345678901');
        await cubit.validate();
      },
      verify: (cubit) {
        expect(repository.verified, [('ACR-2026-0003150', '12345678901')]);
        final draft = repository.draft!;
        expect(draft.ninDecision, ChildNinDecision.verified);
        expect(draft.childNin, '12345678901');
        expect(draft.child[ChildField.surname], 'Hassan');
        expect(draft.child[ChildField.sex], AdoptionCodes.male);
        expect(cubit.state.step, ChildNinStep.done);
      },
    );

    blocTest<ChildNinCubit, ChildNinState>(
      'skipping is recorded against the application',
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.skip();
      },
      verify: (cubit) {
        expect(repository.skipped, ['ACR-2026-0003150']);
        expect(repository.draft!.ninDecision, ChildNinDecision.skipped);
        expect(cubit.state.decision, ChildNinDecision.skipped);
      },
    );
  });

  group('AdoptionFormCubit', () {
    late FakeAdoptedChildRepository repository;
    setUp(() => repository = FakeAdoptedChildRepository());

    AdoptionFormCubit build() =>
        AdoptionFormCubit(repository, now: () => _today);

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      "the registration state and LGA are the registrar's",
      setUp: () => repository.draft = paidDraft(),
      build: () => AdoptionFormCubit(
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

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'needs a registration past the NIN step',
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.status, FormStatus.notStarted),
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'needs the fee paid',
      setUp: () {
        repository
          ..draft = AdoptionDraft(
            referenceId: 'R',
            startedOn: _today,
            ninDecision: ChildNinDecision.skipped,
          )
          ..payments.stored = null;
      },
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.status, FormStatus.notPaid),
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'attaches the paid reference to the application once',
      setUp: () => repository.draft = AdoptionDraft(
        referenceId: 'R',
        startedOn: _today,
        ninDecision: ChildNinDecision.skipped,
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.load();
      },
      verify: (cubit) {
        expect(repository.attached, [('R', 'BRTPAID1')]);
        expect(repository.draft!.paymentReference, 'BRTPAID1');
        expect(cubit.state.status, FormStatus.ready);
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'an incomplete step shows its errors and is not saved',
      setUp: () => repository.draft = paidDraft(),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.showErrors, isTrue);
        expect(cubit.state.step, AdoptionStep.child);
        expect(repository.savedSections, isEmpty);
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'a finished step saves its section, records uploads and moves on',
      setUp: () => repository.draft = paidDraft().copyWith(
        child: completeChild().set(ChildField.facePhoto, '/face.jpg'),
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.next();
        await cubit.flush();
      },
      verify: (cubit) {
        expect(repository.savedSections.single.$1, AdoptionSection.child);
        expect(cubit.state.step, AdoptionStep.adopter1);
        expect(repository.draft!.step, AdoptionStep.adopter1);
        expect(repository.draft!.uploads, {'/face.jpg': 'key//face.jpg'});
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'a failed save stays on the step',
      setUp: () {
        repository
          ..draft = paidDraft().copyWith(child: completeChild())
          ..saveFailure = const NetworkFailure();
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.step, AdoptionStep.child);
        expect(cubit.state.isSaving, isFalse);
        expect(cubit.state.saveFailure, isA<NetworkFailure>());
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'fields from a verified NIN cannot be changed',
      setUp: () => repository.draft = paidDraft().copyWith(
        ninDecision: ChildNinDecision.verified,
        child: completeChild(),
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit
          ..childChanged(ChildField.surname, 'Other')
          ..childChanged(ChildField.middleName, 'Bala');
      },
      verify: (cubit) {
        expect(cubit.state.draft!.child[ChildField.surname], 'Hassan');
        expect(cubit.state.draft!.child[ChildField.middleName], 'Bala');
      },
    );

    blocTest<AdoptionFormCubit, AdoptionFormState>(
      'a new photo replaces the old upload',
      setUp: () => repository.draft = paidDraft().copyWith(
        child: completeChild().set(ChildField.facePhoto, '/old.jpg'),
        uploads: {'/old.jpg': 'key/old'},
      ),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.childPhotoCaptured('/new.jpg');
      },
      verify: (cubit) {
        final draft = cubit.state.draft!;
        expect(draft.child[ChildField.facePhoto], 'kept//new.jpg');
        expect(draft.uploads, isEmpty);
      },
    );
  });

  group('screens', () {
    testWidgets('a new registration shows its reference id first', (
      tester,
    ) async {
      final repository = FakeAdoptedChildRepository();
      await tester.pumpApp(ChildNinPage(onDone: () {}, repository: repository));
      await tester.pumpAndSettle();
      expect(find.text('Application Reference ID Created'), findsOneWidget);
      expect(find.text('ACR-2026-0003150'), findsOneWidget);
      expect(
        find.text('A new adopted child registration has been started.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();
      expect(find.text("Child's National Identity Number"), findsOneWidget);
    });

    testWidgets('skipping the NIN warns first, then moves on', (tester) async {
      final repository = FakeAdoptedChildRepository()
        ..draft = AdoptionDraft(referenceId: 'ACR-1', startedOn: _today);
      var done = false;
      await tester.pumpApp(
        ChildNinPage(onDone: () => done = true, repository: repository),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Skip Child NIN Verification'), findsOneWidget);
      await tester.tap(find.text("Don't Skip"));
      await tester.pumpAndSettle();
      expect(repository.skipped, isEmpty);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();
      expect(repository.skipped, ['ACR-1']);
      expect(done, isTrue);
    });

    testWidgets('a validated NIN is confirmed before moving on', (
      tester,
    ) async {
      final repository = FakeAdoptedChildRepository()
        ..draft = AdoptionDraft(referenceId: 'ACR-1', startedOn: _today);
      var done = false;
      await tester.pumpApp(
        ChildNinPage(onDone: () => done = true, repository: repository),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '12345678901');
      await tester.pump();
      await tester.tap(find.text('Validate'));
      await tester.pumpAndSettle();
      expect(find.text('NIN Validated'), findsOneWidget);
      expect(done, isFalse);
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });

    testWidgets('the form opens on Particulars of Child, step 1 of 7', (
      tester,
    ) async {
      final repository = FakeAdoptedChildRepository()..draft = paidDraft();
      await tester.pumpApp(
        AdoptionFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Adopted Child Registration'), findsOneWidget);
      expect(find.text('Step 1 of 7'), findsOneWidget);
      expect(find.text('Particulars of Child'), findsWidgets);
      expect(find.text('Legally Required Fields'), findsOneWidget);
      expect(find.text('Save & Continue'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text("Child's Previous Full Name"),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Order of Child'), findsOneWidget);
    });

    testWidgets('Save & Continue on an empty step shows what is missing', (
      tester,
    ) async {
      final repository = FakeAdoptedChildRepository()..draft = paidDraft();
      await tester.pumpApp(
        AdoptionFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsWidgets);
      expect(repository.savedSections, isEmpty);
    });

    testWidgets('a finished child step saves and moves to the adopters', (
      tester,
    ) async {
      final repository = FakeAdoptedChildRepository()
        ..draft = paidDraft().copyWith(child: completeChild());
      await tester.pumpApp(
        AdoptionFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      expect(repository.savedSections.single.$1, AdoptionSection.child);
      expect(find.text('Step 2 of 7'), findsOneWidget);
      expect(find.text('Particulars of Adopter'), findsOneWidget);
    });
  });
}
