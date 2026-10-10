import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/birth_registration_repository_impl.dart';
import 'package:vital_reg_mobile/features/birth_registration/data/dtos/application_payload.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/person_fields.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/form/cubit/registration_form_cubit.dart';

import '../../helpers/demo_backend.dart';
import '../../helpers/fakes.dart';
import 'fake_birth_registration_repository.dart';
import 'sample_data.dart';

final _today = DateTime(2026, 9, 29);

void main() {
  group('SupportingDocuments', () {
    test('accepts JPEG and PNG images up to 5 MB', () {
      expect(SupportingDocuments.check('card.JPG', 1000), isNull);
      expect(SupportingDocuments.check('card.png', 1000), isNull);
      expect(
        SupportingDocuments.check('card.pdf', 1000),
        DocumentError.unsupportedType,
      );
      expect(
        SupportingDocuments.check('card.jpg', SupportingDocuments.maxBytes + 1),
        DocumentError.tooLarge,
      );
    });

    test('only the immunization card and birth notification are always '
        'required', () {
      expect(const SupportingDocuments().isComplete, isFalse);
      expect(completeDraft(_today).documents.isComplete, isTrue);
    });
  });

  group('registrationToJson', () {
    const places = ReferenceData(
      typesOfBirth: [],
      birthOrders: [],
      sexes: [],
      placesOfOccurrence: [],
      localityTypes: [],
      states: [
        StateOption(
          option: Option('15', 'FCT'),
          code: 'FC',
          lgas: [
            LgaOption(
              option: Option('151', 'AMAC'),
              code: '151',
              registrationCenters: [Option('1510', 'AMAC Centre')],
            ),
          ],
        ),
      ],
    );
    const uploads = (
      childFace: 'keys/face.jpg',
      informantIdentity: 'keys/signature.png',
      documents: {
        DocumentType.immunizationCard: 'keys/imc.jpg',
        DocumentType.birthNotification: 'keys/nb.png',
      },
    );

    RegistrationDraft numbered() {
      final draft = completeDraft(_today);
      return draft.copyWith(
        child: draft.child
            .set(ChildField.typeOfBirth, '1')
            .set(ChildField.registrationState, '15')
            .set(ChildField.registrationLga, '151')
            .set(ChildField.registrationCenter, '1510'),
        informant: draft.informant.set(InformantField.relationship, '2'),
      );
    }

    test("sends option ids as numbers and the registration place's codes", () {
      final json = registrationToJson(
        numbered(),
        places: places,
        uploads: uploads,
      );

      expect(json['Birth_type'], 1);
      expect(json['Reg_Center'], 1510);
      expect(json['State_Code'], 'FC');
      expect(json['LGA_Code'], '151');
      expect(json['Date_Of_Birth'], '2026-01-15');
      expect(json['Claimed'], isTrue);
      expect(json['ChildFace'], 'keys/face.jpg');
      expect(json['informant_signature'], 'keys/signature.png');
      expect(json['Mother_Is_Informant'], isTrue);
      expect(json['Father_Is_Informant'], isFalse);
      expect(json.containsKey('paymentReference'), isFalse);
      expect(
        json['SupportingDocument'],
        contains(
          equals({
            'type': 'notification-of-birth',
            'file': 'keys/nb.png',
            'mimeType': 'image/jpeg',
          }),
        ),
      );
      expect(
        json['SupportingDocument'],
        contains(equals({'type': 'valid-id', 'file': null, 'mimeType': null})),
      );
    });

    test("fills in a father's residence from the mother's", () {
      final draft = numbered().copyWith(
        mother: completeParent().set(ParentField.address, 'No 2 Agwada St'),
        father: completeParent()
            .set(ParentField.sameResidenceAsMother, answerYes)
            .set(ParentField.address, 'stale address'),
      );

      final json = registrationToJson(draft, places: places, uploads: uploads);

      expect(json['Father_Address'], 'No 2 Agwada St');
      expect(json['Father_Country_of_Residence'], 63);
    });

    test('sends answers hidden by a later choice as null', () {
      final draft = numbered().copyWith(
        mother: completeParent()
            .set(ParentField.nationality, '31')
            .set(ParentField.literacy, '2'),
      );

      final json = registrationToJson(draft, places: places, uploads: uploads);

      expect(json['Mother_Nationality'], 31);
      expect(json['MotherStateOriginId'], isNull);
      expect(json['Mother_Ethnic_Group'], isNull);
      expect(json['Mother_Education'], isNull);
      expect(json.containsKey('Mother_Passport'), isTrue);
      expect(json.containsKey('Father_Passport'), isFalse);
    });

    test('carries the payment reference once paid', () {
      final json = registrationToJson(
        numbered().copyWith(paymentReference: 'BR-PAID'),
        places: places,
        uploads: uploads,
      );
      expect(json['paymentReference'], 'BR-PAID');
    });
  });

  test('places come from the API: LGAs state by state, '
      'and no other lists', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final backend = demoBackend();
    final repository = BirthRegistrationRepositoryImpl(
      client: backend.client,
      storage: signedInUserStorage(),
    );
    final places = ok(await repository.referenceData());
    final state = places.states.first.option.id;
    expect(places.lgasOf(state), isEmpty);

    final withLgas = ok(await repository.referenceData(withLgasOf: [state]));
    await repository.referenceData(withLgasOf: [state]);

    expect(withLgas.lgasOf(state), isNotEmpty);
    expect(withLgas.sexes, const [Option('1', 'Male'), Option('2', 'Female')]);
    // As the forms send it: 1 is Urban (not the shared list's).
    expect(withLgas.localityTypes, const [
      Option('1', 'Urban'),
      Option('2', 'Rural'),
    ]);
    expect(
      backend.paths,
      unorderedEquals([
        'GET /option/country',
        'GET /option/states/63',
        'GET /option/registration-centres',
        'GET /option/lga/$state',
      ]),
    );
  });

  group('BirthRegistrationRepositoryImpl.submit', () {
    late Directory files;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      files = await Directory.systemTemp.createTemp('br-submit');
    });
    tearDown(() => files.delete(recursive: true));

    Future<String> file(String name) async {
      final path = '${files.path}/$name';
      await File(path).writeAsBytes([1, 2, 3]);
      return path;
    }

    test(
      'saved for later, the draft moves to the outbox with its files',
      () async {
        final storage = signedInUserStorage();
        final repository = BirthRegistrationRepositoryImpl(
          client: demoBackend().client,
          storage: storage,
        );
        final face = await file('face.jpg');
        final draft = completeDraft(_today).copyWith(
          submissionKey: 'key-1',
          child: completeChild().set(ChildField.facePhoto, face),
        );
        await repository.saveDraft(draft);

        await repository.saveForLater(draft);

        expect(await repository.loadDraft(), isNull);
        expect(File(face).existsSync(), isTrue);
        final entry = (await repository.outbox()).single;
        expect(entry.item, draft);

        await repository.removeFromOutbox(entry.id);

        expect(await repository.outbox(), isEmpty);
        expect(File(face).existsSync(), isFalse);
      },
    );

    test('uploads each file, then sends the registration', () async {
      final backend = demoBackend();
      final repository = BirthRegistrationRepositoryImpl(
        client: backend.client,
        storage: signedInUserStorage(),
      );
      final firstState = ok(await repository.referenceData()).states.first;
      final places = ok(
        await repository.referenceData(withLgasOf: [firstState.option.id]),
      );
      final state = places.states.first;
      final lga = state.lgas.first;
      final draft = completeDraft(_today).copyWith(
        submissionKey: 'key-1',
        child: completeChild()
            .set(ChildField.registrationState, state.option.id)
            .set(ChildField.registrationLga, lga.option.id)
            .set(
              ChildField.registrationCenter,
              lga.registrationCenters.first.id,
            )
            .set(ChildField.facePhoto, await file('face.jpg')),
        informant: informantWithoutId().set(
          InformantField.signature,
          await file('signature.png'),
        ),
        documents: SupportingDocuments({
          DocumentType.immunizationCard: AttachedFile(
            path: await file('imc.jpg'),
            name: 'imc.jpg',
            sizeBytes: 3,
          ),
          DocumentType.birthNotification: AttachedFile(
            path: await file('nb.jpg'),
            name: 'nb.jpg',
            sizeBytes: 3,
          ),
        }),
      );
      final progress = <int>[];
      final keys = <String, String>{};

      final result = await repository.submit(
        draft,
        onProgress: (sent, total) => progress.add(sent),
        onUploaded: (path, key) => keys[path] = key,
      );

      expect(result, isA<Ok<String?>>());
      expect(progress, [1, 2, 3, 4]);
      expect(
        backend.paths.where((path) => path.startsWith('GET /file-upload-url')),
        hasLength(4),
      );
      expect(backend.paths.last, 'POST /birth-registration/add');
      expect(keys.keys, unorderedEquals(draft.files));

      // A retry sends the uploaded files by key.
      backend.paths.clear();
      await repository.submit(draft, uploaded: keys);
      expect(backend.paths, ['POST /birth-registration/add']);
    });

    test('a tracking ID gives its name, or none', () async {
      final repository = BirthRegistrationRepositoryImpl(
        client: demoBackend().client,
        storage: signedInUserStorage(),
      );

      expect(ok(await repository.verifyTrackingId('ABCDEFGHIJ12345')), (
        surname: 'Ogunlade',
        firstName: 'Bolaji',
      ));
      expect(
        await repository.verifyTrackingId('000000000000000'),
        isA<Err<Object?>>(),
      );
    });
  });

  group('RegistrationFormCubit', () {
    late FakeBirthRegistrationRepository repository;

    setUp(() {
      repository = FakeBirthRegistrationRepository()
        ..draft = completeDraft(_today);
    });

    RegistrationFormCubit build() => RegistrationFormCubit(
      repository,
      now: () => _today,
      newSubmissionKey: () => 'key-1',
    );

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      'Edit on the review returns there after Next',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit
          ..editStep(RegistrationStep.mother)
          ..next();
      },
      verify: (cubit) => expect(cubit.state.step, RegistrationStep.review),
    );

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      'does not submit until the declaration is ticked',
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

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      'submits with a key, then deletes the draft',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.submitStatus, SubmitStatus.submitted);
        expect(cubit.state.trackingId, 'BR123');
        expect(repository.submitted.single.submissionKey, 'key-1');
        expect(repository.draft, isNull);
      },
    );

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      'offline, the application goes to the outbox, not the server',
      build: () => RegistrationFormCubit(
        repository,
        offline: true,
        now: () => _today,
        newSubmissionKey: () => 'key-1',
      ),
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.submitStatus, SubmitStatus.savedForLater);
        expect(repository.submitted, isEmpty);
        expect(repository.draft, isNull);
        expect(repository.outboxEntries.single.item.submissionKey, 'key-1');
      },
    );

    test('leaving the screen mid-upload cancels it', () async {
      final gate = repository.submitGate = Completer<void>();
      final cubit = build();
      await cubit.load();
      cubit.declarationChanged(declared: true);
      final submitting = cubit.submit();
      await pumpEventQueue();
      expect(repository.submitCancellation?.isCancelled, isFalse);

      await cubit.close();
      gate.complete();
      await submitting;

      expect(repository.submitCancellation?.isCancelled, isTrue);
      // Unsent, so the draft stays for next time.
      expect(repository.draft?.submissionKey, 'key-1');
    });

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      'a failed submission keeps the draft and its key for a retry',
      setUp: () => repository.submitResult = const Err(NetworkFailure()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.submitStatus, SubmitStatus.failed);
        expect(cubit.state.submitFailure, isA<NetworkFailure>());
        expect(repository.draft?.submissionKey, 'key-1');
        expect(repository.submitted.map((draft) => draft.submissionKey), [
          'key-1',
          'key-1',
        ]);
      },
    );

    blocTest<RegistrationFormCubit, RegistrationFormState>(
      'refuses a document that is too large',
      build: build,
      act: (cubit) async {
        await cubit.load();
        final error = await cubit.documentPicked(
          DocumentType.idCard,
          path: '/tmp/id.jpg',
          name: 'id.jpg',
          sizeBytes: SupportingDocuments.maxBytes + 1,
        );
        expect(error, DocumentError.tooLarge);
        await cubit.documentPicked(
          DocumentType.baptismalCard,
          path: '/tmp/bc.jpg',
          name: 'bc.jpg',
          sizeBytes: 1000,
        );
      },
      verify: (cubit) {
        final documents = cubit.state.draft!.documents;
        expect(documents[DocumentType.idCard], isNull);
        expect(documents[DocumentType.baptismalCard]?.path, 'kept-/tmp/bc.jpg');
      },
    );
  });
}
