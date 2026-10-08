import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/registration_draft.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/form/cubit/registration_form_cubit.dart';
import 'package:vital_reg_mobile/features/birth_registration/presentation/form/view/registration_form_page.dart';

import '../../helpers/pump_app.dart';
import 'fake_birth_registration_repository.dart';
import 'sample_data.dart';

void main() {
  late FakeBirthRegistrationRepository repository;

  setUp(() {
    repository = FakeBirthRegistrationRepository()
      ..reference = const ReferenceData(
        typesOfBirth: [],
        birthOrders: [],
        sexes: [],
        placesOfOccurrence: [],
        localityTypes: [Option('urban', 'Urban')],
        states: [],
        countries: [Option(ReferenceData.nigeria, 'Nigeria')],
      );
  });

  var exits = 0;

  /// Opens the form on [step] (or [draft]), tall enough that every field
  /// is built.
  Future<void> pumpStep(
    WidgetTester tester,
    RegistrationStep step, {
    RegistrationDraft? draft,
  }) async {
    tester.view
      ..physicalSize = const Size(360, 12000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    exits = 0;
    repository.draft =
        draft ??
        RegistrationDraft(startedOn: DateTime(2026, 9, 29), step: step);
    await tester.pumpApp(
      BlocProvider(
        create: (_) => RegistrationFormCubit(repository)..load().ignore(),
        child: RegistrationFormView(
          onExit: () => exits++,
          onPayment: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('names take no spaces', (tester) async {
    await pumpStep(tester, RegistrationStep.child);

    await tester.enterText(find.byType(TextField).first, 'Ada Favour');
    await tester.pump();

    expect(find.text('AdaFavour'), findsOneWidget);
  });

  testWidgets("an LGA list that couldn't load offers a retry", (tester) async {
    repository.lgaFailure = const NetworkFailure();
    await pumpStep(
      tester,
      RegistrationStep.child,
      draft: RegistrationDraft(
        startedOn: DateTime(2026, 9, 29),
        child: const ChildParticulars().set(ChildField.stateOfOrigin, '15'),
      ),
    );

    expect(
      find.text("Couldn't load the LGAs. Check your connection."),
      findsOneWidget,
    );

    repository.lgaFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't load the LGAs. Check your connection."),
      findsNothing,
    );
  });

  testWidgets('the mother step asks for a maiden name', (tester) async {
    await pumpStep(tester, RegistrationStep.mother);

    expect(find.text('Particulars of Mother'), findsWidgets);
    expect(find.text('Maiden Name'), findsOneWidget);
    expect(find.text("Is it the same as mother's?"), findsNothing);
    expect(find.text('Age of Mother at Birth of Child'), findsOneWidget);
  });

  testWidgets("the father's residence can be the mother's", (tester) async {
    await pumpStep(tester, RegistrationStep.father);

    expect(find.text('Maiden Name'), findsNothing);
    expect(find.text('Country'), findsOneWidget);

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(find.text('Country'), findsNothing);
    expect(find.text('Address of Usual Residence'), findsNothing);
    expect(find.text('Nationality'), findsOneWidget);
  });

  testWidgets('the informant signs, or captures a face instead', (
    tester,
  ) async {
    await pumpStep(tester, RegistrationStep.informant);

    expect(find.text('Sign here with your finger'), findsOneWidget);
    expect(find.text('Capture Applicant Face'), findsNothing);

    await tester.tap(find.text('Capture Face'));
    await tester.pumpAndSettle();

    expect(find.text('Sign here with your finger'), findsNothing);
    expect(find.text('Capture Applicant Face'), findsOneWidget);
  });

  testWidgets('Next on an incomplete step points out what is missing', (
    tester,
  ) async {
    await pumpStep(tester, RegistrationStep.mother);
    expect(find.text('This field is required.'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required.'), findsWidgets);
    expect(find.text('Particulars of Mother'), findsWidgets);
  });

  testWidgets('the documents step offers each upload', (tester) async {
    await pumpStep(tester, RegistrationStep.documents);

    expect(find.text('Upload Immunization Card'), findsOneWidget);
    expect(find.text('Upload ID Card'), findsOneWidget);
    expect(find.text('Required · JPEG or PNG, up to 5 MB'), findsNWidgets(2));
  });

  testWidgets('submitting shows the tracking ID, and Ok leaves the form', (
    tester,
  ) async {
    await pumpStep(
      tester,
      RegistrationStep.review,
      draft: completeDraft(DateTime(2026, 9, 29)),
    );
    expect(find.text('Information Preview'), findsOneWidget);
    expect(find.text('Edit'), findsNWidgets(5));

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Tick the declaration to submit.'), findsOneWidget);
    expect(repository.submitted, isEmpty);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Application Successfully Submitted'), findsOneWidget);
    expect(find.text('BR123'), findsOneWidget);
    expect(exits, 0);

    await tester.tap(find.text('Ok'));
    await tester.pumpAndSettle();
    expect(exits, 1);
  });

  testWidgets('Edit on the review opens that step', (tester) async {
    await pumpStep(
      tester,
      RegistrationStep.review,
      draft: completeDraft(DateTime(2026, 9, 29)),
    );

    await tester.tap(find.text('Edit').at(1));
    await tester.pumpAndSettle();

    expect(find.text('Maiden Name'), findsOneWidget);
  });
}
