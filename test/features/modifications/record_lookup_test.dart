import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/modifications/data/dtos/modification_dtos.dart';
import 'package:vital_reg_mobile/features/modifications/data/modifications_repository_impl.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_record.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_request.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/lookup/cubit/record_lookup_cubit.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/lookup/view/record_lookup_page.dart';
import 'package:vital_reg_mobile/features/payments/domain/entities/payment.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_modifications_repository.dart';

void main() {
  group('fees', () {
    test('each kind pays its own fee; a date of birth change, the DOB fee', () {
      ModificationRequest request(
        ModificationKind kind,
        ModificationType type,
      ) => ModificationRequest(kind: kind).withType(type);

      expect(
        request(
          ModificationKind.birth,
          ModificationType.fatherName,
        ).paymentType,
        'birth_modification_payment',
      );
      expect(
        request(
          ModificationKind.attestation,
          ModificationType.applicantMotherName,
        ).paymentType,
        'attest_modification_payment',
      );
      expect(
        request(
          ModificationKind.death,
          ModificationType.deceasedSex,
        ).paymentType,
        'death_modification_payment',
      );
      expect(
        request(
          ModificationKind.attestation,
          ModificationType.applicantParticulars,
        ).withField(ModificationField.applicantDateOfBirth).paymentType,
        'dob_modification_payment',
      );
      expect(
        ModificationKind.death.paymentDescription,
        'payment for death modification',
      );
    });

    test('the payment calls carry the request\'s fee type', () async {
      final calls = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
        ..interceptors.addAll([
          InterceptorsWrapper(
            onRequest: (options, handler) {
              calls.add(options);
              handler.next(options);
            },
          ),
          FakeBackendInterceptor(latency: Duration.zero),
        ]);
      final repository = ModificationsRepositoryImpl(
        client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
        storage: signedInUserStorage(),
      );
      final payments = repository.payments(
        const ModificationRequest(kind: ModificationKind.birth)
            .withType(ModificationType.childParticulars)
            .withField(ModificationField.childDateOfBirth),
      );

      final quote = await payments.quote();
      final session = await payments.startPayment('ada@example.com');

      expect(quote, isA<Ok<PaymentQuote>>());
      expect(session, isA<Ok<PaymentSession>>());
      expect(calls.first.path, '/payments/price/dob_modification_payment');
      expect(calls.last.data, {
        'email': 'ada@example.com',
        'type': 'dob_modification_payment',
        'description': 'payment for birth modification',
        'redirectUrl': isA<String>(),
      });
    });
  });

  group('record lookup', () {
    test('reads the record, preferring its own certificate number', () {
      final record = recordFromJson(
        {
          'data': {
            'Birth_Reg_ID': 7,
            'Certificate_No': 'B-123',
            'childData': {'surname': 'Hassan', 'firstname': 'Suleiman'},
          },
        },
        kind: ModificationKind.birth,
        certificateNumber: 'B123',
      );
      expect(record?.certificateNumber, 'B-123');
      expect(record?.name, 'Hassan Suleiman');
      expect(record?.recordId, '7');

      expect(
        recordFromJson(
          {'data': null},
          kind: ModificationKind.death,
          certificateNumber: 'D1',
        ),
        isNull,
      );
    });

    test('calls the API endpoint; no record is NotFound', () async {
      final paths = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
        ..interceptors.addAll([
          InterceptorsWrapper(
            onRequest: (options, handler) {
              paths.add(options.path);
              handler.next(options);
            },
          ),
          FakeBackendInterceptor(latency: Duration.zero),
        ]);
      final repository = ModificationsRepositoryImpl(
        client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
        storage: signedInUserStorage(),
      );

      final found = await repository.findRecord(
        ModificationKind.death,
        'DR123',
      );
      final missing = await repository.findRecord(
        ModificationKind.birth,
        '000000',
      );

      expect(paths, [
        '/modification/death-registration/cert/DR123',
        '/modification/birth-registration/cert/000000',
      ]);
      expect(
        (found as Ok<ModificationRecord>).value.certificateNumber,
        'DR123',
      );
      expect(
        (missing as Err<ModificationRecord>).failure,
        isA<NotFoundFailure>(),
      );
    });
  });

  group('RecordLookupCubit', () {
    late FakeModificationsRepository repository;
    setUp(() => repository = FakeModificationsRepository());

    blocTest<RecordLookupCubit, RecordLookupState>(
      'keeps letters and digits in capitals, then finds the record',
      build: () => RecordLookupCubit(repository, ModificationKind.birth),
      act: (cubit) async {
        cubit.numberChanged(' b-12/3 ');
        await cubit.lookUp();
      },
      expect: () => const [
        RecordLookupState(number: 'B123'),
        RecordLookupState(number: 'B123', isLoading: true),
        RecordLookupState(number: 'B123', record: sampleRecord),
      ],
      verify: (_) =>
          expect(repository.lookedUp, [(ModificationKind.birth, 'B123')]),
    );

    blocTest<RecordLookupCubit, RecordLookupState>(
      'does nothing without a number',
      build: () => RecordLookupCubit(repository, ModificationKind.birth),
      act: (cubit) => cubit.lookUp(),
      expect: () => const <RecordLookupState>[],
    );

    blocTest<RecordLookupCubit, RecordLookupState>(
      'typing again clears the last error',
      build: () => RecordLookupCubit(
        repository..recordResult = const Err(NotFoundFailure()),
        ModificationKind.birth,
      ),
      act: (cubit) async {
        cubit.numberChanged('X1');
        await cubit.lookUp();
        cubit.numberChanged('X12');
      },
      verify: (cubit) {
        expect(cubit.state.failure, isNull);
        expect(cubit.state.number, 'X12');
      },
    );
  });

  group('RecordLookupView', () {
    Future<FakeModificationsRepository> pump(
      WidgetTester tester, {
      required ValueChanged<ModificationRecord> onFound,
    }) async {
      final repository = FakeModificationsRepository();
      await tester.pumpApp(
        BlocProvider(
          create: (_) => RecordLookupCubit(repository, ModificationKind.birth),
          child: RecordLookupView(onFound: onFound),
        ),
      );
      return repository;
    }

    testWidgets('moves on with the record that was found', (tester) async {
      ModificationRecord? found;
      await pump(tester, onFound: (record) => found = record);

      expect(find.text('Birth Modifications'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'b123');
      await tester.pump();
      expect(find.text('B123'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(found, sampleRecord);
    });

    testWidgets('says when there is no such record', (tester) async {
      ModificationRecord? found;
      final repository = await pump(
        tester,
        onFound: (record) => found = record,
      );
      repository.recordResult = const Err(NotFoundFailure());

      await tester.enterText(find.byType(TextField), 'B999');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No record was found with this certificate number. '
          'Check it and try again.',
        ),
        findsOneWidget,
      );
      expect(found, isNull);
    });
  });
}
