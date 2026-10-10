import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/informant_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/parent_particulars.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/person_fields.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/form/cubit/registration_form_cubit.dart';

import 'fake_birth_registration_repository.dart';
import 'sample_data.dart';

final _today = DateTime(2026, 10, 9);

void main() {
  late FakeBirthRegistrationRepository repository;

  setUp(() {
    final draft = completeDraft(_today);
    repository = FakeBirthRegistrationRepository()
      ..draft = draft.copyWith(
        step: RegistrationStep.informant,
        mother: draft.mother
            .set(ParentField.surname, 'Obi')
            .set(ParentField.firstName, 'Faith')
            .set(ParentField.phone, '08134534456'),
        father: draft.father
            .set(ParentField.surname, 'Obi')
            .set(ParentField.firstName, 'Daniel')
            .set(ParentField.sameResidenceAsMother, answerNo)
            .set(ParentField.address, '12 Father Street')
            .set(ParentField.phone, null),
        informant: const InformantParticulars({
          InformantField.relationship: '3',
          InformantField.surname: 'Brother',
          InformantField.phone: '08000000000',
        }),
      );
  });

  RegistrationFormCubit build() =>
      RegistrationFormCubit(repository, now: () => _today);

  InformantParticulars informantOf(RegistrationFormCubit cubit) =>
      cubit.state.draft!.informant;

  blocTest<RegistrationFormCubit, RegistrationFormState>(
    "choosing Mother fills the informant in from the mother's step",
    build: build,
    act: (cubit) async {
      await cubit.load();
      cubit.informantChanged(InformantField.relationship, '2');
    },
    verify: (cubit) {
      final informant = informantOf(cubit);
      expect(informant[InformantField.surname], 'Obi');
      expect(informant[InformantField.firstName], 'Faith');
      expect(informant[InformantField.phone], '08134534456');
      expect(informant.livesWithMother, isTrue);
    },
  );

  blocTest<RegistrationFormCubit, RegistrationFormState>(
    "choosing Father takes the father's own residence",
    build: build,
    act: (cubit) async {
      await cubit.load();
      cubit.informantChanged(InformantField.relationship, '1');
    },
    verify: (cubit) {
      final informant = informantOf(cubit);
      expect(informant[InformantField.firstName], 'Daniel');
      expect(informant.livesWithMother, isFalse);
      expect(informant[InformantField.address], '12 Father Street');
      // The father gave no phone, so the brother's isn't kept.
      expect(informant[InformantField.phone], isNull);
    },
  );

  blocTest<RegistrationFormCubit, RegistrationFormState>(
    "follows the parent's step, and its phone is the parent's",
    build: build,
    act: (cubit) async {
      await cubit.load();
      cubit
        ..informantChanged(InformantField.relationship, '2')
        ..parentChanged(ParentRole.mother, ParentField.surname, 'Adeyemi')
        ..informantChanged(InformantField.phone, '08099999999');
    },
    verify: (cubit) {
      final draft = cubit.state.draft!;
      expect(draft.informant[InformantField.surname], 'Adeyemi');
      expect(draft.informant[InformantField.phone], '08099999999');
      expect(draft.mother[ParentField.phone], '08099999999');
    },
  );

  blocTest<RegistrationFormCubit, RegistrationFormState>(
    'choosing someone else afterwards clears what came from the parent',
    build: build,
    act: (cubit) async {
      await cubit.load();
      cubit
        ..informantChanged(InformantField.relationship, '2')
        ..informantChanged(InformantField.relationship, '4');
    },
    verify: (cubit) {
      final informant = informantOf(cubit);
      expect(informant[InformantField.relationship], '4');
      expect(informant[InformantField.surname], isNull);
      expect(informant[InformantField.phone], isNull);
    },
  );
}
