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
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_summary.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/home/cubit/modifications_cubit.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/home/view/modifications_home_page.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_modifications_repository.dart';

void main() {
  group('DTOs', () {
    test("reads the backend's counts and dates every kind's rows", () {
      // SQL sums arrive as strings.
      expect(countFromJson({'total': '12'}), 12);
      expect(countFromJson({'total': 3}), 3);
      // Attestation rows carry no date_created; the request is dated.
      final rows = requestsFromJson(
        {
          'result': [
            {
              'id': 9,
              'attestation_number': 'AT1',
              'personData': {'surname': 'Lee', 'firstname': 'Ada'},
              'Modification': [
                {'id': 31, 'datetime_modified': '2026-09-23T10:00:00Z'},
              ],
            },
          ],
        },
        kind: ModificationKind.attestation,
        status: ModificationStatus.pending,
      );
      expect(rows.single.modifiedOn, DateTime.utc(2026, 9, 23, 10));
      expect(rows.single.certificateNumber, 'AT1');
    });

    test('reads each kind of row', () {
      final birth = requestsFromJson(
        {
          'result': [
            {
              'id': 7,
              'childData': {'surname': 'Hassan', 'firstname': 'Suleiman'},
              'birth_number': 'B123',
              'Modification': [
                {'datetime_modified': '2026-09-23T10:00:00Z'},
              ],
            },
          ],
        },
        kind: ModificationKind.birth,
        status: ModificationStatus.approved,
      ).single;
      expect(birth.id, '7');
      expect(birth.name, 'Hassan Suleiman');
      expect(birth.certificateNumber, 'B123');
      expect(birth.status, ModificationStatus.approved);
      expect(birth.modifiedOn, DateTime.utc(2026, 9, 23, 10));

      final attestation = requestsFromJson(
        {
          'result': [
            {
              '_id': 'abc',
              'personData': {
                'surname': 'Kim',
                'firstname': 'David',
                'middle_name': ' ',
              },
              'attestation_number': 'A9',
              'date_created': '2024-11-02',
            },
          ],
        },
        kind: ModificationKind.attestation,
        status: ModificationStatus.pending,
      ).single;
      expect(attestation.id, 'abc');
      expect(attestation.name, 'Kim David');
      expect(attestation.modifiedOn, DateTime(2024, 11, 2));

      final death = requestsFromJson(
        {
          'result': [
            {
              'id': 1,
              'deceasedData': {'surname': 'Ade'},
              'death_certificate_number': 'D1',
            },
          ],
        },
        kind: ModificationKind.death,
        status: ModificationStatus.queried,
      ).single;
      expect(death.certificateNumber, 'D1');
      expect(death.modifiedOn, isNull);
    });

    test('a row without an id is a contract error', () {
      expect(
        () => requestsFromJson(
          {
            'result': [<String, Object?>{}],
          },
          kind: ModificationKind.birth,
          status: ModificationStatus.pending,
        ),
        throwsFormatException,
      );
    });
  });

  test('calls the API endpoints (demo backend)', () async {
    final calls = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
      ..interceptors.addAll([
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add('${options.path} ${options.queryParameters}');
            handler.next(options);
          },
        ),
        FakeBackendInterceptor(latency: Duration.zero),
      ]);
    final repository = ModificationsRepositoryImpl(
      client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
      storage: signedInUserStorage(),
    );

    final count = await repository.count(ModificationKind.death);
    final list = await repository.requests(
      kind: ModificationKind.attestation,
      status: ModificationStatus.approved,
      query: 'sofia',
    );

    expect(calls, [
      '/modification/death-registration/stats {}',
      '/modification/birth-attestation/list '
          '{type: approved, page: 1, search: sofia}',
    ]);
    expect((count as Ok<int>).value, 6);
    final items = (list as Ok<List<ModificationSummary>>).value;
    expect(items.single.name, 'Martinez Sofia');
    expect(items.single.certificateNumber, 'BAFA30087678');
  });

  group('ModificationsCubit', () {
    late FakeModificationsRepository repository;
    setUp(() => repository = FakeModificationsRepository());

    blocTest<ModificationsCubit, ModificationsState>(
      'loads counts per kind; a failed count shows as 0',
      build: () => ModificationsCubit(repository),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.countOf(ModificationKind.birth), 3);
        expect(cubit.state.countOf(ModificationKind.death), 0);
        expect(cubit.state.items, [michael]);
        expect(cubit.state.failure, isNull);
        expect(repository.requested, [
          (ModificationKind.birth, ModificationStatus.pending, ''),
        ]);
      },
    );

    blocTest<ModificationsCubit, ModificationsState>(
      'reloads the list for the chosen kind, status and search',
      build: () => ModificationsCubit(repository, searchDelay: Duration.zero),
      act: (cubit) async {
        await cubit.kindSelected(ModificationKind.death);
        await cubit.statusSelected(ModificationStatus.queried);
        cubit.queryChanged(' kim ');
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) => expect(repository.requested, [
        (ModificationKind.death, ModificationStatus.pending, ''),
        (ModificationKind.death, ModificationStatus.queried, ''),
        (ModificationKind.death, ModificationStatus.queried, 'kim'),
      ]),
    );

    blocTest<ModificationsCubit, ModificationsState>(
      'reports a failed list',
      build: () => ModificationsCubit(
        repository..listResult = const Err(NetworkFailure()),
      ),
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.failure, const NetworkFailure()),
    );
  });

  group('ModificationsHomeView', () {
    Future<FakeModificationsRepository> pumpHome(
      WidgetTester tester, {
      StartModification? onNewRequest,
      OpenQueried? onOpenQueried,
    }) async {
      // A phone screen, so the list is laid out below the cards.
      tester.view
        ..physicalSize = const Size(1170, 2532)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repository = FakeModificationsRepository();
      await tester.pumpApp(
        BlocProvider(
          create: (_) => ModificationsCubit(repository)..load().ignore(),
          child: ModificationsHomeView(
            onNewRequest: onNewRequest ?? (_) async {},
            onOpenQueried: onOpenQueried ?? (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('shows the three kinds and the pending requests', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Birth Modifications'), findsOneWidget);
      expect(find.text('Attestation Modifications'), findsOneWidget);
      expect(find.text('Death Modifications'), findsOneWidget);
      expect(find.text('Lee Michael'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('the filter lists another status', (tester) async {
      final repository = await pumpHome(tester);

      await tester.tap(find.byTooltip('Filter by status'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is CheckedPopupMenuItem<ModificationStatus> &&
              widget.value == ModificationStatus.queried,
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.requested.last, (
        ModificationKind.birth,
        ModificationStatus.queried,
        '',
      ));
    });

    testWidgets('new request is for the selected kind', (tester) async {
      ModificationKind? started;
      await pumpHome(tester, onNewRequest: (kind) async => started = kind);

      await tester.tap(find.text('Attestation Modifications'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New modification request'));
      await tester.pumpAndSettle();

      expect(started, ModificationKind.attestation);
    });
  });
}
