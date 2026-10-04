import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/request/view/modification_request_page.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('ModificationRequest', () {
    test('each kind offers its modification types', () {
      expect(ModificationKind.birth.types, [
        ModificationType.childParticulars,
        ModificationType.motherName,
        ModificationType.fatherName,
      ]);
      expect(ModificationKind.attestation.types, hasLength(3));
      expect(ModificationKind.death.types, hasLength(4));
    });

    test('particulars need a field before a reason', () {
      const empty = ModificationRequest(kind: ModificationKind.birth);
      final child = empty.withType(ModificationType.childParticulars);

      expect(child.needsField, isTrue);
      expect(child.reasons, isEmpty);
      expect(child.isComplete, isFalse);

      final name = child.withField(ModificationField.childName);
      expect(name.reasons, [
        ModificationReason.misspelledName,
        ModificationReason.switchedNameOrder,
      ]);
      expect(name.reason, isNull);
      expect(
        name.withReason(ModificationReason.switchedNameOrder).isComplete,
        isTrue,
      );
    });

    test('a single reason is chosen for you', () {
      final dob = const ModificationRequest(kind: ModificationKind.birth)
          .withType(ModificationType.childParticulars)
          .withField(ModificationField.childDateOfBirth);
      expect(dob.reason, ModificationReason.incorrectAge);
      expect(dob.isComplete, isTrue);
      expect(dob.changesDateOfBirth, isTrue);

      final sex = const ModificationRequest(
        kind: ModificationKind.death,
      ).withType(ModificationType.deceasedSex);
      expect(sex.reason, ModificationReason.changeOfSex);
      expect(sex.changesDateOfBirth, isFalse);
    });

    test('changing the type or field clears the choices below it', () {
      final chosen = const ModificationRequest(kind: ModificationKind.birth)
          .withType(ModificationType.childParticulars)
          .withField(ModificationField.childName)
          .withReason(ModificationReason.misspelledName)
          .withComment('Typo at registration');

      final otherField = chosen.withField(ModificationField.childSex);
      expect(otherField.reason, ModificationReason.changeOfSex);

      final otherType = chosen.withType(ModificationType.fatherName);
      expect(otherType.field, isNull);
      expect(otherType.reason, isNull);
      expect(otherType.comment, 'Typo at registration');
    });

    test('a reason that no longer applies is not complete', () {
      const stale = ModificationRequest(
        kind: ModificationKind.birth,
        type: ModificationType.fatherName,
        reason: ModificationReason.changeOfSex,
      );
      expect(stale.isComplete, isFalse);
    });
  });

  group('ModificationRequestPage', () {
    Future<ModificationRequest?> fill(
      WidgetTester tester,
      Future<void> Function() steps,
    ) async {
      ModificationRequest? proceeded;
      await tester.pumpApp(
        ModificationRequestPage(
          kind: ModificationKind.birth,
          onProceed: (request) => proceeded = request,
        ),
      );
      await steps();
      await tester.tap(find.text('Proceed'));
      await tester.pump();
      return proceeded;
    }

    Future<void> choose<T>(WidgetTester tester, String option) async {
      await tester.tap(find.byType(DropdownButtonFormField<T>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    testWidgets('Proceed stays off until the request is complete', (
      tester,
    ) async {
      final proceeded = await fill(tester, () async {});
      expect(proceeded, isNull);
      expect(find.text('Fields to Edit'), findsNothing);
      expect(find.text('Reason for Modification'), findsNothing);
    });

    testWidgets('particulars of child: field, then its reason', (tester) async {
      final proceeded = await fill(tester, () async {
        await choose<ModificationType>(tester, 'Particulars of Child');
        expect(find.text('Fields to Edit'), findsOneWidget);
        await choose<ModificationField>(tester, 'Date of Birth');
        expect(find.text('Incorrect age entered'), findsOneWidget);
      });

      expect(proceeded?.field, ModificationField.childDateOfBirth);
      expect(proceeded?.reason, ModificationReason.incorrectAge);
    });

    testWidgets('a name change asks which reason', (tester) async {
      final proceeded = await fill(tester, () async {
        await choose<ModificationType>(tester, 'Father Name');
        expect(find.text('Fields to Edit'), findsNothing);
        await tester.tap(find.text('Switching of name order'));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'Names swapped');
        await tester.pump();
      });

      expect(
        proceeded,
        const ModificationRequest(
          kind: ModificationKind.birth,
          type: ModificationType.fatherName,
          reason: ModificationReason.switchedNameOrder,
          comment: 'Names swapped',
        ),
      );
    });
  });
}
