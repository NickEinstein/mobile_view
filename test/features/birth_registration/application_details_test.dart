import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/birth_registration_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/application_details.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/details/cubit/application_details_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/details/view/application_details_page.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/cubit/applications_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/view/birth_registration_home_page.dart';

import '../../helpers/demo_backend.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_birth_registration_repository.dart';
import 'sample_data.dart';

final _summary = BirthApplicationSummary(
  id: 'approved-0',
  childName: 'Michael Lee',
  trackingId: 'FA30087677',
  submittedOn: DateTime(2026, 9, 23),
  status: ApplicationStatus.approved,
);

ApplicationDetails _details() {
  final draft = completeDraft(DateTime(2026, 9, 23));
  return ApplicationDetails(
    summary: _summary,
    child: draft.child,
    mother: draft.mother,
    father: draft.father,
    informant: draft.informant,
    documents: draft.documents,
  );
}

void main() {
  test("the demo backend's records decode with known option ids", () async {
    FlutterSecureStorage.setMockInitialValues({});
    final repository = BirthRegistrationRepositoryImpl(
      client: demoBackend().client,
      storage: signedInUserStorage(),
    );
    bool known(List<Option> options, String? id) =>
        id == null || options.any((option) => option.id == id);

    for (final (id, status) in [
      ('2001', ApplicationStatus.approved),
      ('3000', ApplicationStatus.printed),
      ('4000', ApplicationStatus.queried),
    ]) {
      final record = ok(await repository.details(id));
      final data = ok(
        await repository.referenceData(
          withLgasOf: statesChosenIn(
            child: record.child,
            mother: record.mother,
            father: record.father,
            informant: record.informant,
          ),
        ),
      );
      expect(record.summary.status, status);
      final c = record.child;
      expect(c.isComplete(today: DateTime(2026, 9, 30)), isTrue);
      expect(known(data.typesOfBirth, c[ChildField.typeOfBirth]), isTrue);
      expect(known(data.sexes, c[ChildField.sex]), isTrue);
      expect(known(data.stateOptions, c[ChildField.stateOfBirth]), isTrue);
      expect(
        known(
          data.centersOf(
            c[ChildField.registrationState],
            c[ChildField.registrationLga],
          ),
          c[ChildField.registrationCenter],
        ),
        isTrue,
      );
      for (final parent in [record.mother, record.father]) {
        expect(known(data.countries, parent[ParentField.country]), isTrue);
        expect(
          known(
            data.lgasOf(parent[ParentField.state]),
            parent[ParentField.lga],
          ),
          isTrue,
        );
        expect(known(data.occupations, parent[ParentField.occupation]), isTrue);
        expect(
          known(data.educationLevels, parent[ParentField.educationLevel]),
          isTrue,
        );
      }
      expect(
        known(
          data.relationships,
          record.informant[InformantField.relationship],
        ),
        isTrue,
      );
      expect(record.documents.isComplete, isTrue);
      // Entries without a file weren't uploaded.
      expect(record.documents[DocumentType.idCard], isNull);
    }
  });

  group('ApplicationDetailsCubit', () {
    late FakeBirthRegistrationRepository repository;

    setUp(() => repository = FakeBirthRegistrationRepository());

    blocTest<ApplicationDetailsCubit, ApplicationDetailsState>(
      'loads the record with the reference data',
      setUp: () => repository.detailsResult = Ok(_details()),
      build: () => ApplicationDetailsCubit(repository, id: 'approved-0'),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.status, DetailsStatus.ready);
        expect(cubit.state.details?.summary, _summary);
      },
    );

    blocTest<ApplicationDetailsCubit, ApplicationDetailsState>(
      'shows why it could not load',
      build: () => ApplicationDetailsCubit(repository, id: 'missing'),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.status, DetailsStatus.failure);
        expect(cubit.state.failure, isA<NotFoundFailure>());
      },
    );
  });

  testWidgets('Certificate Details is read-only', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 12000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = FakeBirthRegistrationRepository()
      ..detailsResult = Ok(_details());

    await tester.pumpApp(
      BlocProvider(
        create: (_) =>
            ApplicationDetailsCubit(repository, id: 'approved-0')
              ..load().ignore(),
        child: const ApplicationDetailsView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Certificate Details'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Particulars of Mother'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('an application opens from its row or its ⋮ menu', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 2000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = FakeBirthRegistrationRepository()..items = [_summary];
    final opened = <String>[];

    await tester.pumpApp(
      BlocProvider(
        create: (_) => ApplicationsCubit(repository)..load().ignore(),
        child: BirthRegistrationHomeView(
          onStartApplication: () async {},
          onResumeApplication: () async {},
          onOpenApplication: (id) async => opened.add(id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Michael Lee'));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();

    expect(opened, ['approved-0', 'approved-0']);
  });
}
