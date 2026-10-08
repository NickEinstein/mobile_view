import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/face/cubit/face_validation_cubit.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/face/view/face_validation_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_birth_attestation_repository.dart';

final _started = DateTime(2026, 10, 3);

void main() {
  late FakeBirthAttestationRepository repository;

  setUp(
    () => repository = FakeBirthAttestationRepository()
      ..draft = AttestationDraft(
        startedOn: _started,
        hasNin: true,
        ninRecord: adultRecord,
      ),
  );

  FaceValidationCubit build() => FaceValidationCubit(repository);

  Future<void> photoAndContinue(FaceValidationCubit cubit, String path) async {
    await cubit.load();
    await cubit.captured(path);
    await cubit.validate();
  }

  group('FaceValidationCubit', () {
    blocTest<FaceValidationCubit, FaceValidationState>(
      'goes from the guidelines to the camera and back',
      build: build,
      act: (cubit) => cubit
        ..guidelinesRead()
        ..backToGuidelines(),
      expect: () => [
        const FaceValidationState(stage: FaceValidationStage.capture),
        const FaceValidationState(),
      ],
    );

    blocTest<FaceValidationCubit, FaceValidationState>(
      'with a NIN, a face matching its photo is kept in the application',
      build: build,
      act: (cubit) => photoAndContinue(cubit, 'face.jpg'),
      verify: (cubit) {
        expect(cubit.state.isDone, isTrue);
        expect(repository.facesChecked, ['face.jpg']);
        expect(repository.draft?.facePhoto, 'face.jpg');
        expect(repository.draft?.faceMatched, isTrue);
        expect(repository.draft?.ninRecord, adultRecord);
      },
    );

    blocTest<FaceValidationCubit, FaceValidationState>(
      'a face that does not match asks for a retake',
      setUp: () => repository.faceResult = const Ok(false),
      build: build,
      act: (cubit) => photoAndContinue(cubit, 'face.jpg'),
      verify: (cubit) {
        expect(cubit.state.notMatched, isTrue);
        expect(cubit.state.isDone, isFalse);
        expect(repository.draft?.facePhoto, isNull);
      },
    );

    blocTest<FaceValidationCubit, FaceValidationState>(
      'without a NIN the face is only captured',
      setUp: () => repository.draft = AttestationDraft(
        startedOn: _started,
        hasNin: false,
      ),
      build: build,
      act: (cubit) => photoAndContinue(cubit, 'face.jpg'),
      verify: (cubit) {
        expect(cubit.state.isDone, isTrue);
        expect(cubit.state.matchesNin, isFalse);
        expect(repository.facesChecked, isEmpty);
        expect(repository.draft?.facePhoto, 'face.jpg');
        expect(repository.draft?.faceMatched, isFalse);
      },
    );

    blocTest<FaceValidationCubit, FaceValidationState>(
      'replaces the face of an application resumed here',
      setUp: () => repository.draft = AttestationDraft(
        startedOn: _started,
        hasNin: false,
        facePhoto: 'old.jpg',
      ),
      build: build,
      act: (cubit) => photoAndContinue(cubit, 'new.jpg'),
      verify: (cubit) {
        expect(repository.draft?.facePhoto, 'new.jpg');
        expect(repository.deleted, ['old.jpg']);
      },
    );

    blocTest<FaceValidationCubit, FaceValidationState>(
      'a retake clears the last result',
      setUp: () => repository.faceResult = const Err(NetworkFailure()),
      build: build,
      act: (cubit) async {
        await photoAndContinue(cubit, 'face.jpg');
        expect(cubit.state.failure, const NetworkFailure());
        await cubit.captured('again.jpg');
      },
      verify: (cubit) {
        expect(cubit.state.failure, isNull);
        expect(cubit.state.photoPath, 'again.jpg');
      },
    );

    blocTest<FaceValidationCubit, FaceValidationState>(
      'cannot continue without an application',
      setUp: () => repository.draft = null,
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.captured('face.jpg');
      },
      verify: (cubit) {
        expect(cubit.state.missingApplication, isTrue);
        expect(cubit.state.canContinue, isFalse);
      },
    );

    test('deletes an unkept photo on leaving, but not a kept one', () async {
      final unkept = build();
      await unkept.load();
      await unkept.captured('unkept.jpg');
      await unkept.close();

      final kept = build();
      await photoAndContinue(kept, 'kept.jpg');
      await kept.close();

      expect(repository.deleted, ['unkept.jpg']);
    });
  });

  testWidgets('guidelines, photo, match, then on to the application', (
    tester,
  ) async {
    var validated = 0;
    await tester.pumpApp(
      BlocProvider(
        create: (_) => build()..load().ignore(),
        child: FaceValidationView(
          onValidated: () => validated++,
          // A path that doesn't exist: Image.file shows nothing, which is
          // fine for this test.
          takePhoto: () async => 'face.jpg',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GUIDELINES'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Position your face'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Face match successful'), findsOneWidget);
    await tester.tap(find.text('Proceed'));
    await tester.pumpAndSettle();
    expect(validated, 1);
  });

  testWidgets('without a NIN, says the face was captured', (tester) async {
    repository.draft = AttestationDraft(startedOn: _started, hasNin: false);
    await tester.pumpApp(
      BlocProvider(
        create: (_) => build()
          ..load().ignore()
          ..guidelinesRead(),
        child: FaceValidationView(
          onValidated: () {},
          takePhoto: () async => 'face.jpg',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Face captured successfully'), findsOneWidget);
  });

  testWidgets('says when the face does not match', (tester) async {
    repository.faceResult = const Ok(false);
    await tester.pumpApp(
      BlocProvider(
        create: (_) => build()
          ..load().ignore()
          ..guidelinesRead(),
        child: FaceValidationView(
          onValidated: () {},
          takePhoto: () async => 'face.jpg',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't match"), findsOneWidget);
  });
}
