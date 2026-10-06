import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/face_source.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/face/cubit/face_validation_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/supporting_documents.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/certificate/cubit/legacy_certificate_cubit.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/certificate/view/legacy_certificate_page.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/validation/cubit/nin_validation_cubit.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/validation/view/nin_validation_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_reissuance_repository.dart';

final _today = DateTime(2026, 10, 4);

ReissuanceDraft _started({LegacyCertificate? certificate}) => ReissuanceDraft(
  startedOn: _today,
  mode: ValidationMode.nin,
  ninRecord: ninRecord,
  facePhoto: 'face.jpg',
  certificate: certificate,
);

final _oldCertificate = LegacyCertificate(
  kind: ReissuanceKind.birth,
  number: 'CR603/2609-15',
  issuedOn: DateTime(2023, 11, 8),
  filePath: 'old.jpg',
  fileName: 'old.jpg',
  sizeBytes: 61440,
);

/// A face source that remembers what it was asked.
class _FakeFace implements FaceSource {
  _FakeFace(this.subjectValue);

  final FaceSubject? subjectValue;
  final kept = <String>[];

  @override
  Future<FaceSubject?> subject() async => subjectValue;

  @override
  Future<Result<bool>> matchFace(
    String photoPath, {
    required String nin,
  }) async => const Ok(true);

  @override
  Future<String> keepPhoto(String capturedPath, {String? replacing}) async =>
      capturedPath;

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Future<void> keepFace(String photo, {required bool matched}) async =>
      kept.add('$photo matched: $matched');
}

void main() {
  test('a draft reads back the same, and knows where it stopped', () {
    final draft = _started(certificate: _oldCertificate);

    expect(ReissuanceDraft.fromJson(draft.toJson()), draft);
    expect(draft.files, ['face.jpg', 'old.jpg']);
    expect(draft.nextStep, ReissuanceStep.form);
    expect(_started().nextStep, ReissuanceStep.certificate);
    expect(
      ReissuanceDraft(
        startedOn: _today,
        mode: ValidationMode.vitalRegPro,
        ninRecord: ninRecord,
      ).nextStep,
      ReissuanceStep.face,
    );
  });

  group('face', () {
    blocTest<FaceValidationCubit, FaceValidationState>(
      "a reissuance face must match the NIN's photo",
      build: () => FaceValidationCubit.source(_FakeFace((nin: ninRecord.nin))),
      act: (cubit) async {
        await cubit.load();
        await cubit.captured('face.jpg');
        await cubit.validate();
      },
      verify: (cubit) {
        expect(cubit.state.matchesNin, isTrue);
        expect(cubit.state.isDone, isTrue);
      },
    );

    blocTest<FaceValidationCubit, FaceValidationState>(
      "can't continue when no request was started",
      build: () => FaceValidationCubit.source(_FakeFace(null)),
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.missingApplication, isTrue),
    );
  });

  group('NinValidationCubit', () {
    late FakeReissuanceRepository repository;
    setUp(() => repository = FakeReissuanceRepository());

    NinValidationCubit build() =>
        NinValidationCubit(repository, now: () => _today);

    test('needs a mode and an 11-digit NIN; a new mode clears the NIN', () {
      final cubit = build()..ninChanged('12345678901');
      expect(cubit.state.canValidate, isFalse);

      cubit.modeChanged(ValidationMode.nin);
      expect(cubit.state.nin, '');
      cubit.ninChanged('1234567890');
      expect(cubit.state.canValidate, isFalse);
      cubit.ninChanged('12345678901');
      expect(cubit.state.canValidate, isTrue);

      cubit.modeChanged(ValidationMode.legacyCertificate);
      expect(cubit.state.nin, '');
      expect(cubit.state.mode, ValidationMode.legacyCertificate);
    });

    blocTest<NinValidationCubit, NinValidationState>(
      'a verified NIN shows its details; Face Match starts a new request',
      build: build,
      act: (cubit) async {
        cubit
          ..modeChanged(ValidationMode.vitalRegPro)
          ..ninChanged('12345678901');
        await cubit.validate();
        expect(cubit.state.record, ninRecord);
        expect(repository.draft, isNull);
        await cubit.confirmed();
      },
      verify: (cubit) {
        expect(cubit.state.isDone, isTrue);
        expect(repository.discards, 1);
        expect(
          repository.draft,
          ReissuanceDraft(
            startedOn: _today,
            mode: ValidationMode.vitalRegPro,
            ninRecord: ninRecord,
          ),
        );
      },
    );

    blocTest<NinValidationCubit, NinValidationState>(
      'Cancel on the details starts nothing',
      build: build,
      act: (cubit) async {
        cubit
          ..modeChanged(ValidationMode.nin)
          ..ninChanged('12345678901');
        await cubit.validate();
        cubit.detailsDismissed();
      },
      verify: (cubit) {
        expect(cubit.state.record, isNull);
        expect(cubit.state.isDone, isFalse);
        expect(repository.draft, isNull);
      },
    );

    blocTest<NinValidationCubit, NinValidationState>(
      'reports a NIN with no record',
      setUp: () => repository.ninResult = const Err(NotFoundFailure()),
      build: build,
      act: (cubit) async {
        cubit
          ..modeChanged(ValidationMode.nin)
          ..ninChanged('00000000000');
        await cubit.validate();
      },
      verify: (cubit) {
        expect(cubit.state.notFound, isTrue);
        expect(cubit.state.record, isNull);
      },
    );
  });

  testWidgets('NIN page: mode, NIN, Validate, details, Face Match', (
    tester,
  ) async {
    final repository = FakeReissuanceRepository();
    var done = 0;
    await tester.pumpApp(
      NinValidationPage(repository: repository, onDone: () => done++),
    );

    await tester.tap(find.byType(DropdownButtonFormField<ValidationMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('National Identity Number').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '12345678901');
    await tester.pump();
    await tester.tap(find.text('Validate'));
    await tester.pumpAndSettle();

    expect(find.text('NIN Details'), findsOneWidget);
    expect(find.text('Ogunlade'), findsOneWidget);
    expect(find.text('16-06-1999'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
    expect(find.text('Bogoro'), findsOneWidget);

    await tester.tap(find.text('Face Match'));
    await tester.pumpAndSettle();

    expect(done, 1);
    expect(repository.draft?.ninRecord, ninRecord);
  });

  group('LegacyCertificateCubit', () {
    late FakeReissuanceRepository repository;
    setUp(() => repository = FakeReissuanceRepository()..draft = _started());

    LegacyCertificateCubit build() => LegacyCertificateCubit(repository);

    Future<void> fill(
      LegacyCertificateCubit cubit, {
      DateTime? issuedOn,
    }) async {
      await cubit.load();
      cubit
        ..kindChanged(ReissuanceKind.attestation)
        ..numberChanged(' CR6032/609-1 ')
        ..issuedOnChanged(issuedOn ?? DateTime(2010, 3, 1));
      await cubit.filePicked(
        path: 'copy.png',
        name: 'copy.png',
        sizeBytes: 2048,
      );
    }

    blocTest<LegacyCertificateCubit, LegacyCertificateState>(
      'Validate with nothing filled in points out everything',
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.validate();
      },
      verify: (cubit) {
        expect(cubit.state.showErrors, isTrue);
        expect(cubit.state.isDone, isFalse);
        expect(cubit.state.errors, {
          CertificateError.typeRequired,
          CertificateError.numberRequired,
          CertificateError.issuedDateRequired,
          CertificateError.fileRequired,
        });
      },
    );

    blocTest<LegacyCertificateCubit, LegacyCertificateState>(
      'checks the number',
      build: build,
      act: (cubit) => cubit.numberChanged('CR 60#3'),
      verify: (cubit) =>
          expect(cubit.state.errors, contains(CertificateError.numberInvalid)),
    );

    blocTest<LegacyCertificateCubit, LegacyCertificateState>(
      'only certificates issued by the e-CRVS commission date',
      build: build,
      act: (cubit) => fill(cubit, issuedOn: DateTime(2023, 11, 9)),
      verify: (cubit) =>
          expect(cubit.state.errors, {CertificateError.issuedDateTooLate}),
    );

    blocTest<LegacyCertificateCubit, LegacyCertificateState>(
      'only photos up to 5 MB',
      build: build,
      act: (cubit) async {
        expect(
          await cubit.filePicked(path: 'a.pdf', name: 'a.pdf', sizeBytes: 10),
          DocumentError.unsupportedType,
        );
        expect(
          await cubit.filePicked(
            path: 'a.jpg',
            name: 'a.jpg',
            sizeBytes: 6 * 1024 * 1024,
          ),
          DocumentError.tooLarge,
        );
      },
      verify: (cubit) => expect(cubit.state.file, isNull),
    );

    blocTest<LegacyCertificateCubit, LegacyCertificateState>(
      'Validate keeps the certificate in the request',
      build: build,
      act: (cubit) async {
        await fill(cubit);
        await cubit.validate();
      },
      verify: (cubit) {
        expect(cubit.state.isDone, isTrue);
        expect(
          repository.draft?.certificate,
          LegacyCertificate(
            kind: ReissuanceKind.attestation,
            number: 'CR6032/609-1',
            issuedOn: DateTime(2010, 3, 1),
            filePath: 'copy.png',
            fileName: 'copy.png',
            sizeBytes: 2048,
          ),
        );
        expect(repository.draft?.facePhoto, 'face.jpg');
        expect(repository.deleted, isEmpty);
      },
    );

    blocTest<LegacyCertificateCubit, LegacyCertificateState>(
      'a new copy replaces the kept one only once validated',
      setUp: () => repository.draft = _started(certificate: _oldCertificate),
      build: build,
      act: (cubit) async {
        await cubit.load();
        expect(cubit.state.number, _oldCertificate.number);
        await cubit.filePicked(path: 'new.png', name: 'new.png', sizeBytes: 9);
        // The kept copy stays until the new one is saved.
        expect(repository.deleted, isEmpty);
        await cubit.validate();
      },
      verify: (cubit) {
        expect(repository.draft?.certificate?.filePath, 'new.png');
        expect(repository.deleted, ['old.jpg']);
      },
    );

    test('a copy picked but never kept is deleted on leaving', () async {
      final cubit = build();
      await cubit.load();
      await cubit.filePicked(path: 'tmp.png', name: 'tmp.png', sizeBytes: 9);
      await cubit.close();

      expect(repository.deleted, ['tmp.png']);
    });
  });

  testWidgets('certificate page: shows errors, then moves on with the type', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(400, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = FakeReissuanceRepository()
      ..draft = _started(certificate: _oldCertificate);
    final done = <ReissuanceKind>[];
    await tester.pumpApp(
      LegacyCertificatePage(repository: repository, onDone: done.add),
    );
    await tester.pumpAndSettle();

    // Filled in from the request.
    expect(find.text('Birth Certificate'), findsOneWidget);
    expect(find.text('08/11/2023'), findsOneWidget);
    expect(find.text('old.jpg · 60 KB'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Validate'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the certificate number.'), findsOneWidget);
    expect(done, isEmpty);

    await tester.enterText(find.byType(TextField), 'CR1');
    await tester.pump();
    await tester.tap(find.text('Validate'));
    await tester.pumpAndSettle();
    expect(done, [ReissuanceKind.birth]);
  });

  testWidgets('certificate page attaches a picked photo', (tester) async {
    final repository = FakeReissuanceRepository()..draft = _started();
    await tester.pumpApp(_PickingCertificatePage(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload copy of old certificate'));
    await tester.pumpAndSettle();

    expect(find.text('scan.jpg · 1 KB'), findsOneWidget);
  });
}

/// The certificate view with a picker that returns a fixed photo.
class _PickingCertificatePage extends StatelessWidget {
  const _PickingCertificatePage({required this.repository});

  final FakeReissuanceRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LegacyCertificateCubit(repository)..load().ignore(),
      child: LegacyCertificateView(
        onDone: (_) {},
        pickCertificate: (_) async =>
            XFile.fromData(Uint8List(1000), name: 'scan.jpg', path: 'scan.jpg'),
      ),
    );
  }
}
