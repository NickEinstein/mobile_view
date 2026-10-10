import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/birth_registration_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/application_payload.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/application_details.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/details/cubit/application_details_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/details/view/application_details_page.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/form/cubit/registration_form_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/home/view/birth_registration_home_page.dart';

import '../../helpers/demo_backend.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_birth_registration_repository.dart';
import 'sample_data.dart';

final _today = DateTime(2026, 10, 9);

/// The demo backend's queried record.
const _queriedId = '4000';

ApplicationDetails _queried() {
  final draft = completeDraft(DateTime(2026, 9, 23));
  return ApplicationDetails(
    summary: BirthApplicationSummary(
      id: '4000',
      childName: 'Ada Obi',
      trackingId: 'FC4000',
      submittedOn: DateTime(2026, 9, 23),
      status: ApplicationStatus.queried,
    ),
    child: draft.child,
    mother: draft.mother,
    father: draft.father,
    informant: draft.informant,
    documents: draft.documents,
    queryReason: 'The birth notification is unreadable.',
    paymentReference: 'BR-PAID',
    faceKey: 'keys/face.jpg',
    documentKeys: const {
      DocumentType.immunizationCard: 'keys/imc.jpg',
      DocumentType.birthNotification: 'keys/nb.jpg',
    },
  );
}

void main() {
  group('a queried record', () {
    test('reads its reason, fee and storage keys from the API', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final repository = BirthRegistrationRepositoryImpl(
        client: demoBackend().client,
        storage: signedInUserStorage(),
      );

      final record = ok(await repository.details(_queriedId));

      expect(record.summary.status, ApplicationStatus.queried);
      expect(record.queryReason, 'The birth notification is unreadable.');
      expect(record.faceKey, 'demo/BR-CHILD-FACE.jpg');
      expect(
        record.documentKeys[DocumentType.birthNotification],
        'demo/notification-of-birth.jpg',
      );
    });

    test('becomes a complete draft on the review, files still on file', () {
      final draft = _queried().toQueriedDraft(_today);

      expect(draft.step, RegistrationStep.review);
      expect(draft.startedOn, _today);
      expect(draft.queried?.recordId, '4000');
      expect(draft.queried?.reason, 'The birth notification is unreadable.');
      expect(draft.child[ChildField.facePhoto], serverPath('keys/face.jpg'));
      expect(draft.child.isComplete(today: _today), isTrue);
      expect(
        draft.informant.isComplete(parentsGaveNin: draft.parentsGaveNin),
        isTrue,
      );
      expect(draft.documentsComplete, isTrue);
      // Nothing to delete from the device.
      expect(draft.files, isEmpty);
      // The fee was paid with the application.
      expect(draft.isPaidFor(_today), isTrue);
    });

    test('is sent back with keys for unchanged files', () {
      final draft = _queried().toQueriedDraft(_today);
      final json = registrationUpdateToJson(
        draft,
        queried: draft.queried!,
        places: FakeBirthRegistrationRepository().reference,
        uploads: (
          childFace: 'keys/face.jpg',
          informantIdentity: null,
          documents: const {
            DocumentType.immunizationCard: 'keys/imc.jpg',
            DocumentType.birthNotification: 'keys/new-nb.jpg',
          },
        ),
      );

      expect(json['Birth_Reg_ID'], 4000);
      expect(json['NIN'], isNull);
      expect(json['paymentReference'], 'BR-PAID');
      expect(json['ChildFace'], 'keys/face.jpg');
      // Not redrawn: the backend keeps the signature on file.
      expect(json['informant_signature'], isNull);
      expect(
        (json['SupportingDocument']! as List).map((d) => (d as Map)['file']),
        containsAll(['keys/imc.jpg', 'keys/new-nb.jpg']),
      );
    });

    test(
      'a correction uploads nothing unchanged and patches the record',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final backend = demoBackend();
        final repository = BirthRegistrationRepositoryImpl(
          client: backend.client,
          storage: signedInUserStorage(),
        );
        final draft = ok(
          await repository.details(_queriedId),
        ).toQueriedDraft(_today);
        backend.paths.clear();

        final result = await repository.updateQueried(draft);

        expect(result, isA<Ok<void>>());
        expect(backend.paths, contains('PATCH /birth-registration/update'));
        expect(
          backend.paths.where((p) => p.contains('/file-upload-url/')),
          isEmpty,
        );
      },
    );
  });

  group('RegistrationFormCubit correcting a queried record', () {
    late FakeBirthRegistrationRepository repository;
    final ownDraft = RegistrationDraft(startedOn: _today, childHasNin: false);

    setUp(() {
      repository = FakeBirthRegistrationRepository()
        ..draft = ownDraft
        ..detailsResult = Ok(_queried());
    });

    RegistrationFormCubit build() => RegistrationFormCubit(
      repository,
      queriedRecordId: '4000',
      now: () => _today,
    );

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      'opens the record on the review and keeps changes off the device',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.childChanged(ChildField.middleName, 'Ngozi');
        await cubit.flush();
      },
      verify: (cubit) {
        expect(cubit.state.step, RegistrationStep.review);
        expect(cubit.state.draft?.child[ChildField.middleName], 'Ngozi');
        expect(repository.saves, 0);
        // The user's own unfinished application is untouched.
        expect(repository.draft, ownDraft);
      },
    );

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      'submitting updates the record instead of adding one',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.submitStatus, SubmitStatus.submitted);
        expect(cubit.state.trackingId, 'FC4000');
        expect(repository.corrected, hasLength(1));
        expect(repository.submitted, isEmpty);
        expect(repository.draft, ownDraft);
      },
    );
  });

  testWidgets('a queried row opens its details, without a dialog', (
    tester,
  ) async {
    final repository = FakeBirthRegistrationRepository()
      ..items = [_queried().summary];
    final opened = <String>[];

    await tester.pumpApp(
      BirthRegistrationHomePage(
        repository: repository,
        onStartApplication: () async {},
        onResumeApplication: () async {},
        onOpenApplication: (id) async => opened.add(id),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ada Obi'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ada Obi'));
    await tester.pumpAndSettle();

    expect(opened, ['4000']);
    expect(find.text('Queried Record'), findsNothing);
  });

  testWidgets('details of a queried record show the reason and Update', (
    tester,
  ) async {
    final repository = FakeBirthRegistrationRepository()
      ..detailsResult = Ok(_queried());
    var updates = 0;

    await tester.pumpApp(
      BlocProvider(
        create: (_) =>
            ApplicationDetailsCubit(repository, id: '4000')..load().ignore(),
        child: ApplicationDetailsView(onUpdate: () => updates++),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reason for query'), findsOneWidget);
    expect(find.text('The birth notification is unreadable.'), findsOneWidget);
    await tester.tap(find.text('Update record'));
    expect(updates, 1);
  });

  test('the informant step keeps a signature on file without a picture', () {
    final draft = _queried().toQueriedDraft(_today);
    expect(draft.informant[InformantField.signature], serverPath(''));
    expect(serverKeyOf(serverPath('')), isNull);
  });
}
