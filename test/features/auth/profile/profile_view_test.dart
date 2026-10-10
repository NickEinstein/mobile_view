import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/places/bundled_place_names.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/permission.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/user.dart';
import 'package:vital_reg_mobile/features/auth/presentation/profile/profile_page.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets("shows the registrar's details in a card", (tester) async {
    await tester.pumpApp(
      ProfileView(
        placeNames: BundledPlaceNames(),
        user: const User(
          id: '7',
          fullName: 'Favour Allison',
          role: UserRole.registrar,
          stateId: '11',
          lgaId: '249',
          userName: 'favour.allison',
          email: 'favour@npc.gov.ng',
          roleName: 'Registrar',
          centreName: 'Kaduna North Centre',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FA'), findsOneWidget);
    expect(find.text('Favour Allison'), findsOneWidget);
    expect(find.text('Registrar'), findsOneWidget);
    expect(find.text('favour.allison'), findsOneWidget);
    expect(find.text('favour@npc.gov.ng'), findsOneWidget);
    expect(find.text('Kaduna North Centre'), findsOneWidget);
    // Names of the state and LGA ids, from the bundled lists.
    expect(find.text('KADUNA'), findsOneWidget);
    expect(find.text('KADUNA NORTH'), findsOneWidget);
    // No phone number was given, so there's no such row.
    expect(find.text('Phone number'), findsNothing);
    expect(find.text('Email address'), findsOneWidget);
  });
}
