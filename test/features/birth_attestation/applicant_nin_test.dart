import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/applicant_nin_record.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';
import 'package:vital_reg_mobile/features/birth_attestation/presentation/nin/cubit/applicant_nin_cubit.dart';

import 'fake_birth_attestation_repository.dart';

final _today = DateTime(2026, 10, 3);

void main() {
  late FakeBirthAttestationRepository repository;

  setUp(() => repository = FakeBirthAttestationRepository());

  ApplicantNinCubit build() => ApplicantNinCubit(repository, now: () => _today);

  test('an applicant is an adult from their 18th birthday', () {
    ApplicantNinRecord bornOn(DateTime dob) => ApplicantNinRecord(
      nin: '1',
      surname: 'A',
      firstName: 'B',
      dateOfBirth: dob,
    );
    expect(bornOn(DateTime(2008, 10, 3)).isAdultOn(_today), isTrue);
    expect(bornOn(DateTime(2008, 10, 4)).isAdultOn(_today), isFalse);
  });

  blocTest<ApplicantNinCubit, ApplicantNinState>(
    'a verified adult NIN starts the application with its record',
    build: build,
    act: (cubit) async {
      cubit
        ..answered(true)
        ..ninChanged('12345678901');
      await cubit.proceed();
    },
    verify: (cubit) {
      expect(cubit.state.isDone, isTrue);
      expect(
        repository.draft,
        AttestationDraft(
          startedOn: _today,
          hasNin: true,
          ninRecord: adultRecord,
        ),
      );
    },
  );

  blocTest<ApplicantNinCubit, ApplicantNinState>(
    'turns away a NIN that belongs to a child',
    setUp: () => repository.ninResult = Ok(
      ApplicantNinRecord(
        nin: '11111111111',
        surname: 'Ogunlade',
        firstName: 'Ada',
        dateOfBirth: DateTime(2016, 3, 12),
      ),
    ),
    build: build,
    act: (cubit) async {
      cubit
        ..answered(true)
        ..ninChanged('11111111111');
      await cubit.proceed();
    },
    verify: (cubit) {
      expect(cubit.state.isUnderAge, isTrue);
      expect(cubit.state.isDone, isFalse);
      expect(repository.draft, isNull);
    },
  );

  blocTest<ApplicantNinCubit, ApplicantNinState>(
    'reports a NIN with no record',
    setUp: () => repository.ninResult = const Err(NotFoundFailure()),
    build: build,
    act: (cubit) async {
      cubit
        ..answered(true)
        ..ninChanged('00000000000');
      await cubit.proceed();
    },
    verify: (cubit) {
      expect(cubit.state.failure, const NotFoundFailure());
      expect(repository.draft, isNull);
    },
  );

  blocTest<ApplicantNinCubit, ApplicantNinState>(
    'without a NIN the applicant goes on',
    build: build,
    act: (cubit) async {
      cubit.answered(false);
      await cubit.proceed();
    },
    verify: (cubit) {
      expect(cubit.state.isDone, isTrue);
      expect(repository.draft?.hasNin, isFalse);
      expect(repository.draft?.ninRecord, isNull);
    },
  );

  blocTest<ApplicantNinCubit, ApplicantNinState>(
    'a new application replaces an unfinished one and its photo',
    setUp: () => repository.draft = AttestationDraft(
      startedOn: DateTime(2026, 9),
      hasNin: false,
      facePhoto: 'old.jpg',
    ),
    build: build,
    act: (cubit) async {
      cubit.answered(false);
      await cubit.proceed();
    },
    verify: (cubit) {
      expect(repository.deleted, ['old.jpg']);
      expect(repository.draft?.startedOn, _today);
      expect(repository.draft?.facePhoto, isNull);
    },
  );

  test('NIN must be 11 digits before it can be checked', () {
    final cubit = build()
      ..answered(true)
      ..ninChanged('123');
    expect(cubit.state.canProceed, isFalse);
    cubit.ninChanged('12345678901');
    expect(cubit.state.canProceed, isTrue);
  });
}
