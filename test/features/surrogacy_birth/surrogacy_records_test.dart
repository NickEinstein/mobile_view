import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/data/dtos/surrogacy_dtos.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/data/surrogacy_birth_repository_impl.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_form.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_record.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_reference_data.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/details/cubit/surrogacy_details_cubit.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/details/view/surrogacy_details_page.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/presentation/form/cubit/surrogacy_form_cubit.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_surrogacy_birth_repository.dart';

final _today = DateTime(2026, 10, 4);

/// A record in the backend's flat shape, as `GET …/{id}` answers.
Map<String, Object?> _recordJson({int status = 2, int? lastSection}) => {
  'data': {
    'id': 7,
    'referenceId': 'SBR-2026-0004821',
    'status': status,
    'createdAt': '2026-08-12',
    'paymentReference': 'PAIDDEMO',
    'childNinVerified': true,
    'remarks': 'Order date mismatch',
    'lastCompletedSection': ?lastSection,
    'childSurname': 'Johnson',
    'childFirstName': 'Sarah',
    'dateOfBirth': '2025-09-09',
    'childSex': 2,
    'birthType': 1,
    'birthOrder': 1,
    'regCenter': 5011,
    'childFace': 'surrogacy/face.png',
    'courtNameOrReference': 'Federal High Court / FHC/L/2025/48',
    'parentalOrderDate': '2025-09-01',
    'surrogacyArrangementType': 'gestational',
    'lp1FullName': 'Ololade Simisola Ada',
    'lp1MaritalStatus': 1,
    'lp1Address': 'No 12 Adeleke road',
    'lp1ResidenceCountry': 63,
    'lp1ResidenceState': 25,
    'lp1ResidenceLga': 501,
    'lp1LocalityType': 2,
    'lp1Occupation': 100,
    'lp1Nationality': 63,
    'lp1Nin': '72921010909',
    'lp2Present': false,
    'smFullName': 'Bala Michelle',
    'smAgeAtBirth': 28,
    'smBirthOrder': 1,
    'infSurname': 'Keith',
    'infFirstName': 'Ryan',
    'infSameResidenceAsLp1': false,
    'infCountry': 31,
    'infResidenceAddress': 'No 12 Adeleke road',
    'infRelationshipToChild': 13,
    'infPhone': '08123212820',
    'infConsentType': 'signature_pad',
    'infSignature': 'surrogacy/sign.png',
    'supportingDocument': [
      for (final type in [
        'court_surrogacy_agreement_order',
        'parental_order',
        'legal_mother_identity_document',
        'international-passport',
      ])
        {'type': type, 'file': 'surrogacy/$type.jpg', 'mimeType': 'image/jpeg'},
    ],
  },
};

SurrogacyRecord _record({int status = 2}) =>
    surrogacyRecordFromJson(_recordJson(status: status));

void main() {
  group('reading a saved application (the API\'s record shape)', () {
    test('every section comes back into the form', () {
      final record = _record();
      final draft = record.draft;
      expect(record.status, SurrogacyRecordStatus.queried);
      expect(record.remarks, 'Order date mismatch');
      expect(draft.referenceId, 'SBR-2026-0004821');
      expect(draft.isNinVerified, isTrue);
      expect(draft.child[ChildField.dateOfBirth], startsWith('2025-09-09'));
      expect(
        draft.surrogacy[SurrogacyDetailsField.courtName],
        'Federal High Court',
      );
      expect(
        draft.surrogacy[SurrogacyDetailsField.orderReference],
        'FHC/L/2025/48',
      );
      expect(draft.legalMother[ParentField.surname], 'Ololade');
      expect(draft.legalMother[ParentField.middleName], 'Ada');
      expect(draft.legalMother.isNinVerified, isTrue);
      expect(draft.hasLegalFather, isFalse);
      expect(draft.surrogateMother[SurrogateField.ageAtBirth], '28');
      expect(
        draft.informant[InformantField.consentType],
        ConsentType.signature,
      );
      expect(draft.documents, hasLength(3));
      expect(draft.informantPassport, isNotNull);
    });

    test('saved files count as uploaded, so they are sent unchanged', () {
      final draft = _record().draft;
      expect(draft.uploads['surrogacy/sign.png'], 'surrogacy/sign.png');
      final json = surrogacySectionToJson(draft, section: null);
      expect(json.containsKey('section'), isFalse);
      expect(json['childFace'], 'surrogacy/face.png');
      expect(json['infSignature'], 'surrogacy/sign.png');
      expect(json['lp1FullName'], 'Ololade Simisola Ada');
      expect(json['lp1Nin'], '72921010909');
      expect(
        json['courtNameOrReference'],
        'Federal High Court / FHC/L/2025/48',
      );
      expect(json['parentalOrderDate'], '2025-09-01');
      expect((json['supportingDocument']! as List).length, 4);
    });

    test('a draft resumes after the last section it saved', () {
      expect(
        surrogacyRecordFromJson(
          _recordJson(status: 3, lastSection: 2),
        ).draft.step,
        SurrogacyStep.informant,
      );
      final record = surrogacyRecordFromJson({
        'success': true,
        'lastCompletedSection': 1,
        'data': {'referenceId': 'SBR-1', 'status': 3},
      });
      expect(record.status, SurrogacyRecordStatus.drafted);
      expect(record.draft.step, SurrogacyStep.legalMother);
      // No NIN decision or payment yet: it starts again at the NIN.
      expect(record.draft.stage, SurrogacyStage.nin);
    });

    test('the registration state and LGA come from the centre', () {
      final draft = _record().draft.withRegistrationLocation(
        sampleReferenceData.locationOfCenter,
      );
      expect(draft.child[ChildField.registrationState], '25');
      expect(draft.child[ChildField.registrationLga], '501');
      expect(draft.child[ChildField.registrationCenter], '5011');
    });

    test("without the state's LGAs loaded, the state is left to choose", () {
      // LGAs load per state; the centre still names its LGA.
      const data = SurrogacyReferenceData(
        sexes: [],
        birthOrders: [],
        typesOfBirth: [],
        placesOfBirth: [],
        localityTypes: [],
        arrangementTypes: [],
        states: [StateOption(option: Option('25', 'Lagos'), lgas: [])],
        countries: [],
        nationalities: [],
        maritalStatuses: [],
        occupations: [],
        literacyLevels: [],
        educationLevels: [],
        relationships: [],
        centres: [(option: Option('5011', 'PHC'), lga: '501')],
      );
      final draft = _record().draft.withRegistrationLocation(
        data.locationOfCenter,
      );
      expect(draft.child[ChildField.registrationState], isNull);
      expect(draft.child[ChildField.registrationLga], '501');
      expect(draft.child[ChildField.registrationCenter], '5011');
      expect(data.centersOf(null, '501').single.label, 'PHC');
    });
  });

  group('SurrogacyDetailsCubit', () {
    late FakeSurrogacyBirthRepository repository;
    setUp(() => repository = FakeSurrogacyBirthRepository());

    blocTest<SurrogacyDetailsCubit, SurrogacyDetailsState>(
      'continuing a draft puts it on the device at its stage',
      setUp: () => repository
        ..detailsResult = Ok(_record(status: 3))
        ..resumeResult = Ok(_record(status: 3)),
      build: () => SurrogacyDetailsCubit(repository, id: '7'),
      act: (cubit) async {
        await cubit.load();
        await cubit.continueDraft();
      },
      verify: (cubit) {
        expect(cubit.state.resumedAt, SurrogacyStage.form);
        expect(repository.draft?.referenceId, 'SBR-2026-0004821');
        expect(repository.draft?.child[ChildField.registrationState], '25');
      },
    );

    test('warns before replacing another unfinished registration', () async {
      repository
        ..detailsResult = Ok(_record(status: 3))
        ..draft = SurrogacyDraft(referenceId: 'SBR-OTHER', startedOn: _today);
      final cubit = SurrogacyDetailsCubit(repository, id: '7');
      await cubit.load();
      expect(await cubit.wouldReplaceDraft(), isTrue);
      repository.draft = _record().draft;
      expect(await cubit.wouldReplaceDraft(), isFalse);
      await cubit.close();
    });
  });

  group('SurrogacyFormCubit (respond to query)', () {
    late FakeSurrogacyBirthRepository repository;
    setUp(
      () =>
          repository = FakeSurrogacyBirthRepository()
            ..detailsResult = Ok(_record()),
    );

    SurrogacyFormCubit build() =>
        SurrogacyFormCubit(repository, queriedId: '7', now: () => _today);

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'opens on the review with the reason, and keeps nothing on the device',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.editStep(SurrogacyStep.surrogacy);
        cubit.surrogacyChanged(
          SurrogacyDetailsField.orderDate,
          DateTime(2025, 9, 2).toIso8601String(),
        );
        await cubit.next();
      },
      verify: (cubit) {
        expect(cubit.state.queryReason, 'Order date mismatch');
        expect(cubit.state.step, SurrogacyStep.review);
        expect(repository.draft, isNull);
        expect(repository.savedSections, isEmpty);
      },
    );

    blocTest<SurrogacyFormCubit, SurrogacyFormState>(
      'submit resends the whole application as an update',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(repository.amended.single.referenceId, 'SBR-2026-0004821');
        expect(repository.submitted, isEmpty);
        expect(repository.payments.clears, 0);
        expect(cubit.state.submitStatus, SubmitStatus.submitted);
      },
    );
  });

  group('screens', () {
    testWidgets('a queried application shows why, and Respond to Query', (
      tester,
    ) async {
      var responded = false;
      final repository = FakeSurrogacyBirthRepository()
        ..detailsResult = Ok(_record());
      await tester.pumpApp(
        SurrogacyDetailsPage(
          id: '7',
          repository: repository,
          onRespondToQuery: () => responded = true,
          onContinue: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Order date mismatch'), findsOneWidget);
      expect(find.text('SBR-2026-0004821'), findsOneWidget);
      await tester.tap(find.text('Respond to Query'));
      expect(responded, isTrue);
    });

    testWidgets('a draft offers Continue', (tester) async {
      SurrogacyStage? continued;
      final repository = FakeSurrogacyBirthRepository()
        ..detailsResult = Ok(_record(status: 3))
        ..resumeResult = Ok(_record(status: 3));
      await tester.pumpApp(
        SurrogacyDetailsPage(
          id: '7',
          repository: repository,
          onRespondToQuery: () {},
          onContinue: (stage) => continued = stage,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Drafted'), findsOneWidget);
      expect(find.text('Respond to Query'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(continued, SurrogacyStage.form);
    });
  });

  test('the demo backend serves records, drafts and resumes', () async {
    final paths = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
      ..interceptors.addAll([
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paths.add('${options.method} ${options.path}');
            handler.next(options);
          },
        ),
        FakeBackendInterceptor(latency: Duration.zero),
      ]);
    final repository = SurrogacyBirthRepositoryImpl(
      client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
      storage: signedInUserStorage(),
    );
    T ok<T>(Result<T> result) => (result as Ok<T>).value;

    final queried = ok(await repository.details('surrogacy-queried-0'));
    expect(queried.status, SurrogacyRecordStatus.queried);
    expect(queried.remarks, isNotNull);
    expect(queried.draft.documents, hasLength(4));

    final drafts = ok(await repository.drafts());
    expect(drafts.single.trackingId, startsWith('SBR-'));
    final resumed = ok(await repository.resume(drafts.single.trackingId));
    expect(resumed.status, SurrogacyRecordStatus.drafted);
    expect(resumed.draft.step, SurrogacyStep.informant);
    expect(resumed.draft.stage, SurrogacyStage.form);

    ok(await repository.amend(queried.draft));
    expect(
      paths,
      contains('PATCH /surrogacy-birth-registration/SBR-2026-0004821/update'),
    );
  });
}
