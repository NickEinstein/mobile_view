import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/data/dtos/surrogacy_dtos.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_form.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/form/cubit/surrogacy_form_cubit.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/form/view/surrogacy_form_page.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/nin/cubit/child_nin_cubit.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/nin/view/child_nin_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_surrogacy_birth_repository.dart';

final _today = DateTime(2026, 10, 4);

void main() {
  group('rules', () {
    test("the child's legally required fields are required; the rest "
        'are optional', () {
      const empty = ChildParticulars();
      for (final field in ChildField.values) {
        expect(
          empty.errorOf(field, today: _today),
          field.isRequired ? SurrogacyFieldError.required : isNull,
          reason: field.name,
        );
      }
      expect(completeChild().isComplete(today: _today), isTrue);
      expect(
        completeChild()
            .set(
              ChildField.dateOfBirth,
              DateTime(2026, 10, 5).toIso8601String(),
            )
            .errorOf(ChildField.dateOfBirth, today: _today),
        SurrogacyFieldError.futureDate,
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

    test('every court order field is required; the date is checked', () {
      for (final field in SurrogacyDetailsField.values) {
        expect(
          const SurrogacyDetails().errorOf(field, today: _today),
          SurrogacyFieldError.required,
        );
      }
      expect(completeDetails().isComplete(today: _today), isTrue);
      expect(
        completeDetails()
            .set(
              SurrogacyDetailsField.orderDate,
              DateTime(2027).toIso8601String(),
            )
            .errorOf(SurrogacyDetailsField.orderDate, today: _today),
        SurrogacyFieldError.futureDate,
      );
    });

    test('steps map onto the API sections', () {
      expect(SurrogacyStep.child.section, SurrogacySection.child);
      expect(SurrogacyStep.surrogacy.section, SurrogacySection.child);
      expect(SurrogacyStep.surrogateMother.section, SurrogacySection.parents);
      expect(SurrogacyStep.documents.section!.number, 4);
      expect(SurrogacyStep.review.section, isNull);
    });
  });

  group('draft', () {
    test('picks up at the NIN, then payment, then the form', () {
      final started = SurrogacyDraft(referenceId: 'R', startedOn: _today);
      expect(started.stage, SurrogacyStage.nin);
      final decided = started.copyWith(ninDecision: ChildNinDecision.skipped);
      expect(decided.stage, SurrogacyStage.payment);
      expect(
        decided.copyWith(paymentReference: 'P').stage,
        SurrogacyStage.form,
      );
    });

    test('a verified NIN locks the surname, first name and sex', () {
      final draft = paidDraft().copyWith(
        ninDecision: ChildNinDecision.verified,
      );
      expect(draft.isLocked(ChildField.surname), isTrue);
      expect(draft.isLocked(ChildField.sex), isTrue);
      expect(draft.isLocked(ChildField.dateOfBirth), isFalse);
      expect(paidDraft().isLocked(ChildField.surname), isFalse);
    });

    test('survives a round trip through JSON', () {
      final draft = paidDraft(step: SurrogacyStep.surrogacy).copyWith(
        childNin: () => '12345678901',
        child: completeChild().set(ChildField.facePhoto, '/face.jpg'),
        surrogacy: completeDetails(),
        legalMother: const ParentParticulars().set(ParentField.surname, 'A'),
        hasLegalFather: true,
        legalFather: const ParentParticulars().set(ParentField.nin, '1'),
        surrogateMother: const SurrogateMotherParticulars().set(
          SurrogateField.ageAtBirth,
          '28',
        ),
        uploads: {'/face.jpg': 'key/face.jpg'},
      );
      expect(SurrogacyDraft.fromJson(draft.toJson()), draft);
    });
  });

  group('API shapes', () {
    test('stats use capitalised keys', () {
      final counts = countsFromJson({
        'Pending': 2,
        'Approved': '3',
        'Queried': 1,
        'Printed': 4,
      });
      expect(counts.of(ApplicationStatus.approved), 3);
      expect(counts.of(ApplicationStatus.printed), 4);
    });

    test('list rows map status codes; a draft without a name shows its '
        'reference', () {
      final rows = applicationsFromJson({
        'result': [
          {
            'id': 7,
            'referenceId': 'SBR-1',
            'status': 2,
            'childSurname': 'Johnson',
            'childFirstName': 'Sarah',
            'createdAt': '2026-08-12',
          },
          {
            'id': 8,
            'referenceId': 'SBR-2',
            'status': 3,
            'createdAt': '2026-08-01',
          },
        ],
      }, requested: ApplicationStatus.pending);
      expect(rows.first.id, '7');
      expect(rows.first.childName, 'Johnson Sarah');
      expect(rows.first.status, ApplicationStatus.queried);
      expect(rows.last.childName, 'SBR-2');
      expect(rows.last.status, ApplicationStatus.pending);
    });

    test('a section is sent with ids as numbers and dates as YYYY-MM-DD', () {
      final draft = paidDraft().copyWith(
        child: completeChild()
            .set(ChildField.registrationCenter, '5011')
            .set(ChildField.localityOfBirth, '2')
            .set(ChildField.facePhoto, '/face.jpg'),
        surrogacy: completeDetails(),
        uploads: {'/face.jpg': 'key/face.jpg'},
      );
      final json = surrogacySectionToJson(
        draft,
        section: SurrogacySection.child,
      );
      expect(json['section'], 1);
      expect(json['paymentReference'], 'BRTPAID1');
      expect(json['childSurname'], 'Hassan');
      expect(json['childMiddleName'], isNull);
      expect(json['dateOfBirth'], '2025-09-09');
      expect(json['childSex'], 1);
      expect(json['birthOrder'], 1);
      expect(json['birthCountry'], 63);
      expect(json['birthState'], isNull);
      expect(json['regCenter'], 5011);
      expect(json['localityType'], 2);
      expect(json['childFace'], 'key/face.jpg');
      expect(json['surrogacyArrangementType'], 'traditional');
      expect(
        json['courtNameOrReference'],
        'Federal High Court / SBR-2026-0004821',
      );
      expect(json['parentalOrderDate'], '2025-09-09');
    });
  });

  group('ChildNinCubit', () {
    late FakeSurrogacyBirthRepository repository;
    setUp(() => repository = FakeSurrogacyBirthRepository());

    ChildNinCubit build() => ChildNinCubit(repository, now: () => _today);

    blocTest<ChildNinCubit, ChildNinState>(
      'creates the application on the server and keeps it',
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(repository.initiated, 1);
        expect(repository.draft?.referenceId, 'SBR-2026-0004821');
        expect(cubit.state.justCreated, isTrue);
        expect(cubit.state.step, ChildNinStep.ready);
      },
    );

    blocTest<ChildNinCubit, ChildNinState>(
      'continues the application on the device instead of creating one',
      setUp: () => repository.draft = SurrogacyDraft(
        referenceId: 'SBR-OLD',
        startedOn: _today,
      ),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(repository.initiated, 0);
        expect(cubit.state.referenceId, 'SBR-OLD');
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
        expect(repository.verified, [('SBR-2026-0004821', '12345678901')]);
        final draft = repository.draft!;
        expect(draft.ninDecision, ChildNinDecision.verified);
        expect(draft.childNin, '12345678901');
        expect(draft.child[ChildField.surname], 'Hassan');
        expect(draft.child[ChildField.sex], SurrogacyCodes.male);
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
        expect(repository.skipped, ['SBR-2026-0004821']);
        expect(repository.draft!.ninDecision, ChildNinDecision.skipped);
        expect(cubit.state.decision, ChildNinDecision.skipped);
      },
    );
  });

  group('SurrogacyFormCubit', () {
    late FakeSurrogacyBirthRepository repository;
    setUp(() => repository = FakeSurrogacyBirthRepository());

    SurrogacyFormCubit build() =>
        SurrogacyFormCubit(repository, now: () => _today);

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'needs a registration past the NIN step',
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.status, FormStatus.notStarted),
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'needs the fee paid',
      setUp: () {
        repository
          ..draft = SurrogacyDraft(
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

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'attaches the paid reference to the application once',
      setUp: () => repository.draft = SurrogacyDraft(
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

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'an incomplete step shows its errors and is not saved',
      setUp: () => repository.draft = paidDraft(),
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.showErrors, isTrue);
        expect(cubit.state.step, SurrogacyStep.child);
        expect(repository.savedSections, isEmpty);
      },
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
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
        expect(repository.savedSections.single.$1, SurrogacySection.child);
        expect(cubit.state.step, SurrogacyStep.surrogacy);
        expect(repository.draft!.step, SurrogacyStep.surrogacy);
        expect(repository.draft!.uploads, {'/face.jpg': 'key//face.jpg'});
      },
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
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
        expect(cubit.state.step, SurrogacyStep.child);
        expect(cubit.state.isSaving, isFalse);
        expect(cubit.state.saveFailure, isA<NetworkFailure>());
      },
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
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
  });

  group('screens', () {
    testWidgets('a new registration shows its reference id first', (
      tester,
    ) async {
      final repository = FakeSurrogacyBirthRepository();
      await tester.pumpApp(ChildNinPage(onDone: () {}, repository: repository));
      await tester.pumpAndSettle();
      expect(find.text('Application Reference ID Created'), findsOneWidget);
      expect(find.text('SBR-2026-0004821'), findsOneWidget);
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();
      expect(find.text("Child's National Identity Number"), findsOneWidget);
    });

    testWidgets('skipping the NIN warns first, then moves on', (tester) async {
      final repository = FakeSurrogacyBirthRepository()
        ..draft = SurrogacyDraft(referenceId: 'SBR-1', startedOn: _today);
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
      expect(repository.skipped, ['SBR-1']);
      expect(done, isTrue);
    });

    testWidgets('a validated NIN is confirmed before moving on', (
      tester,
    ) async {
      final repository = FakeSurrogacyBirthRepository()
        ..draft = SurrogacyDraft(referenceId: 'SBR-1', startedOn: _today);
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

    testWidgets('the form opens on Particulars of Child, step 1 of 8', (
      tester,
    ) async {
      final repository = FakeSurrogacyBirthRepository()..draft = paidDraft();
      await tester.pumpApp(
        SurrogacyFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 8'), findsOneWidget);
      expect(find.text('Legally Required Fields'), findsOneWidget);
      expect(find.text('Save & Continue'), findsOneWidget);
      expect(find.text('Exit Application'), findsOneWidget);
    });

    testWidgets('the surrogacy details step has Previous and Next', (
      tester,
    ) async {
      final repository = FakeSurrogacyBirthRepository()
        ..draft = paidDraft(step: SurrogacyStep.surrogacy);
      await tester.pumpApp(
        SurrogacyFormPage(onExit: () {}, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 8'), findsOneWidget);
      expect(find.text('Court Name'), findsOneWidget);
      expect(find.text('Previous'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });
  });
}
