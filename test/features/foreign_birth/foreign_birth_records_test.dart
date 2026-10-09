import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/features/foreign_birth/data/dtos/foreign_birth_dtos.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_form.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/details/cubit/foreign_birth_details_cubit.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/details/view/foreign_birth_details_page.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/form/cubit/foreign_birth_form_cubit.dart';
import 'package:vital_reg_mobile/features/foreign_birth/presentation/form/view/foreign_birth_form_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_foreign_birth_repository.dart';

final _today = DateTime(2026, 10, 4);

/// `GET /birth-notification/540` as the backend returns it.
Map<String, Object?> _response({Object? informantData, int status = 2}) => {
  'data': {
    'id': 540,
    'notification_number': 'GB261000540',
    'reference': 'BN-7540',
    'email': 'ololade@example.com',
    'approved_status': status,
    'date_registered': '2026-09-23T10:00:00.000Z',
    'mother_age_at_birth': 30,
    'father_age_at_birth': 35,
    'informant_relationship': 2,
    'birth_typeData': {'Birth_Type_ID': 1},
    'birth_orderData': {'Birth_Order_ID': 1},
    'birth_placeData': {'BirthPlace_ID': 1},
    'childData': {
      'id': 5401,
      'surname': 'Garba',
      'firstname': 'Amina',
      'middle_name': null,
      'gender': 2,
      'birth_date': '2025-12-12T00:00:00.000Z',
      'birth_country': 181,
      'birth_state': 951,
    },
    'motherData': {
      'id': 5402,
      'surname': 'Ololade',
      'firstname': 'Adegoke',
      'maiden_name': 'Bello',
      'nin': '90289384945',
      'current_marital_status': 1,
      'current_nationality': 63,
      'origin_state': 25,
      'origin_lga': 501,
      'ethnic_group': 5,
      'current_occupation': 100,
      'current_residence_country': 63,
      'current_residence_state': 25,
      'current_residence_lga': 501,
      'current_address': 'No 12 Adeleke road, Lekki',
      'current_literacy_level': 2,
      'current_phone_number': '',
    },
    'fatherData': {
      'id': 5403,
      'surname': 'Keith',
      'firstname': 'Ryan',
      'nin': null,
      'current_marital_status': 1,
      'current_nationality': 181,
      'origin_state': 951,
      'current_residence_country': 181,
      'current_residence_state': 951,
      'current_address': '10 Baker Street, London',
      'current_literacy_level': 2,
    },
    'informantData': informantData,
    'informant_consent': 'https://files.test/sig.png?sig=1',
    'supporting_document': 'https://files.test/cert.jpg?sig=1',
    'child_face': null,
    'rawInformantConsent': 'fb/sig.png',
    'rawSupportingDocument': 'fb/cert.jpg',
    'rawFace': null,
  },
  'queried': status == 2
      ? {'title': 'Document', 'reason': 'The certificate is unreadable.'}
      : null,
};

void main() {
  group('reading a notification back (the backend\'s shape)', () {
    final record = foreignBirthRecordFromJson(_response());
    final draft = record.draft;

    test('status, number, reason, payment reference and ids', () {
      expect(record.id, 540);
      expect(record.status, ApplicationStatus.queried);
      expect(record.notificationNumber, 'GB261000540');
      expect(record.queryReason, 'The certificate is unreadable.');
      expect(draft.paymentReference, 'BN-7540');
      // The mother is the informant: her person record.
      expect(record.partyIds, (
        child: 5401,
        mother: 5402,
        father: 5403,
        informant: 5402,
      ));
    });

    test('the child, with type, order and place from their *Data', () {
      expect(draft.child.isComplete(today: _today), isTrue);
      expect(draft.child.dateOfBirth, DateTime(2025, 12, 12));
      expect(draft.child[ChildField.typeOfBirth], '1');
      expect(draft.child[ChildField.placeOfOccurrence], '1');
      expect(draft.child[ChildField.stateOfBirth], '951');
      expect(draft.child[ChildField.facePhoto], isNull);
    });

    test('the parents, complete, with a NIN on record as verified', () {
      expect(draft.mother.isComplete(Parent.mother), isTrue);
      expect(draft.mother.isNinVerified, isTrue);
      expect(draft.mother[ParentField.age], '30');
      expect(draft.mother[ParentField.phone], isNull);
      expect(draft.father.isComplete(Parent.father), isTrue);
      expect(draft.father[ParentField.nin], isNull);
    });

    test('a parent informant is filled from that parent', () {
      final informant = draft.informant;
      expect(informant[InformantField.relationship], '2');
      expect(informant[InformantField.surname], 'Ololade');
      expect(informant[InformantField.email], 'ololade@example.com');
      expect(informant[InformantField.consentType], ConsentType.signature);
      expect(informant[InformantField.signature], 'fb/sig.png');
    });

    test('files on record are keys, already uploaded, with viewable URLs', () {
      expect(draft.certificate?.path, 'fb/cert.jpg');
      expect(draft.uploads, {
        'fb/sig.png': 'fb/sig.png',
        'fb/cert.jpg': 'fb/cert.jpg',
      });
      expect(record.fileUrls['fb/sig.png'], 'https://files.test/sig.png?sig=1');
    });

    test('an informant of their own is read from informantData', () {
      final other = foreignBirthRecordFromJson(
        _response(
          informantData: {
            'id': 5404,
            'surname': 'Musa',
            'firstname': 'Bala',
            'current_nationality': 181,
          },
        ),
      );
      expect(other.partyIds.informant, 5404);
      expect(other.draft.informant[InformantField.surname], 'Musa');
    });

    test('the update body adds the record and people ids', () {
      final json = foreignBirthAmendToJson(
        draft,
        record: record,
        data: sampleReferenceData,
      );
      expect(json['id'], 540);
      expect(json['childId'], 5401);
      expect(json['motherId'], 5402);
      expect(json['fatherId'], 5403);
      expect(json['informantId'], 5402);
      expect(json['reference'], 'BN-7540');
      expect(json['supporting_document'], 'fb/cert.jpg');
      expect(json['informant_consent'], 'fb/sig.png');
    });
  });

  group('ForeignBirthDetailsCubit', () {
    blocTest<ForeignBirthDetailsCubit, ForeignBirthDetailsState>(
      'loads the record and the names of its places',
      build: () => ForeignBirthDetailsCubit(
        FakeForeignBirthRepository()..detailsResult = Ok(queriedRecord()),
        id: '540',
      ),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.record, queriedRecord());
        expect(cubit.state.stateName('181', '951'), 'England');
        expect(cubit.state.lgaName('25', '501'), 'Agege');
      },
    );

    blocTest<ForeignBirthDetailsCubit, ForeignBirthDetailsState>(
      'offers to try again when it cannot load',
      build: () => ForeignBirthDetailsCubit(
        FakeForeignBirthRepository()
          ..detailsResult = const Err(NetworkFailure()),
        id: '540',
      ),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.isLoading, isFalse);
        expect(cubit.state.failure, isA<NetworkFailure>());
      },
    );
  });

  group('correcting a queried notification', () {
    late FakeForeignBirthRepository repository;
    setUp(
      () =>
          repository = FakeForeignBirthRepository()
            ..detailsResult = Ok(queriedRecord()),
    );
    ForeignBirthFormCubit build() =>
        ForeignBirthFormCubit(repository, queriedId: '540', now: () => _today);

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'opens on the review with the reason, and keeps nothing on the device',
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.childChanged(ChildField.middleName, 'Zara');
        await cubit.flush();
      },
      verify: (cubit) {
        expect(cubit.state.status, FormStatus.ready);
        expect(cubit.state.step, ForeignBirthStep.review);
        expect(cubit.state.record?.queryReason, isNotNull);
        expect(cubit.state.fileUrl('fb/sig.png'), 'https://files.test/sig.png');
        expect(repository.draft, isNull);
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'resends it with only the new file uploaded, keeping the payment',
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.certificatePicked(
          path: '/clear.jpg',
          name: 'clear.jpg',
          sizeBytes: 1000,
        );
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(repository.uploadedPaths, ['kept//clear.jpg']);
        final (draft, record) = repository.amended.single;
        expect(record.id, 540);
        expect(draft.certificate?.path, 'kept//clear.jpg');
        expect(draft.uploads['kept//clear.jpg'], 'key/kept//clear.jpg');
        expect(repository.submitted, isEmpty);
        expect(repository.payments.clears, 0);
        expect(cubit.state.submitStatus, SubmitStatus.submitted);
        expect(cubit.state.trackingId, 'GB261000540');
      },
    );

    blocTest<ForeignBirthFormCubit, ForeignBirthFormState>(
      'a refused correction can be sent again',
      setUp: () => repository.amendResult = const Err(NetworkFailure()),
      build: build,
      act: (cubit) async {
        await cubit.load();
        cubit.declarationChanged(declared: true);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.submitStatus, SubmitStatus.idle);
        expect(cubit.state.submitFailure, isA<NetworkFailure>());
      },
    );
  });

  group('screens', () {
    testWidgets('details of a queried notification offer Respond to Query', (
      tester,
    ) async {
      var responded = false;
      await tester.pumpApp(
        ForeignBirthDetailsPage(
          id: '540',
          onRespondToQuery: () => responded = true,
          repository: FakeForeignBirthRepository()
            ..detailsResult = Ok(queriedRecord()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Certificate Details'), findsOneWidget);
      expect(find.text('GB261000540'), findsOneWidget);
      expect(find.text('The certificate is unreadable.'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      await tester.tap(find.text('Respond to Query'));
      expect(responded, isTrue);
    });

    testWidgets('an approved notification has no action', (tester) async {
      await tester.pumpApp(
        ForeignBirthDetailsPage(
          id: '530',
          onRespondToQuery: () {},
          repository: FakeForeignBirthRepository()
            ..detailsResult = Ok(
              foreignBirthRecordFromJson(_response(status: 1)),
            ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Certificate Details'), findsOneWidget);
      expect(find.text('Respond to Query'), findsNothing);
      expect(find.text('The certificate is unreadable.'), findsNothing);
    });

    testWidgets('the correction shows the reason and resubmits', (
      tester,
    ) async {
      final repository = FakeForeignBirthRepository()
        ..detailsResult = Ok(queriedRecord());
      var exited = false;
      await tester.pumpApp(
        ForeignBirthFormPage(
          queriedId: '540',
          onExit: () => exited = true,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 6 of 6'), findsOneWidget);
      expect(find.text('The certificate is unreadable.'), findsOneWidget);
      final declaration = find.byType(Checkbox);
      await tester.ensureVisible(declaration);
      await tester.pumpAndSettle();
      await tester.tap(declaration);
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Corrections Submitted'), findsOneWidget);
      expect(repository.amended, hasLength(1));
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(exited, isTrue);
    });
  });
}
