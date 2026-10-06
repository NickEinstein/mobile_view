import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_reg_mobile/app/dev/fake_backend_interceptor.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/network/api_client.dart';
import 'package:vital_reg_mobile/core/observability/app_logger.dart';
import 'package:vital_reg_mobile/core/observability/crash_reporter.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_stat_card.dart';
import 'package:vital_reg_mobile/features/birth_attestation/data/face_verifier.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/data/dtos/reissuance_dtos.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/data/reissuance_repository_impl.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/home/cubit/reissuance_home_cubit.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/home/view/reissuance_home_page.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'fake_reissuance_repository.dart';

/// The real repository against the demo backend, recording requests.
(ReissuanceRepositoryImpl, List<String>) _demo() {
  final requests = <String>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://demo.test'))
    ..interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(
            '${options.method} ${options.uri.path}?${options.uri.query}',
          );
          handler.next(options);
        },
      ),
      FakeBackendInterceptor(latency: Duration.zero),
    ]);
  final repository = ReissuanceRepositoryImpl(
    client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
    storage: signedInUserStorage(),
    faces: FaceVerifier(
      client: ApiClient(dio, LoggingCrashReporter(AppLogger())),
      url: demoFaceUrl,
    ),
  );
  return (repository, requests);
}

T _ok<T>(Result<T> result) => (result as Ok<T>).value;

void main() {
  group('reissuance JSON', () {
    test('reads the API stats, missing counts as 0', () {
      expect(
        countsFromJson({'Total': 5, 'Pending': '2', 'Approved': 3}),
        const ReissuanceCounts(total: 5, pending: 2, approved: 3),
      );
    });

    test('reads list rows: name parts, status 0/1/2, date', () {
      final rows = requestsFromJson({
        'result': [
          {
            'id': 7,
            'surname': 'Ogunlade',
            'firstName': 'Bolaji',
            'middleName': null,
            'reference': 'BRT9',
            'date_created': '2026-09-23T10:00:00.000Z',
            'approvedStatus': 2,
          },
          {'id': 8, 'surname': 'Kim', 'approvedStatus': 1},
          {'id': 9, 'firstName': 'Amina', 'approvedStatus': 0},
        ],
        'pagination': <String, Object?>{},
      });

      expect(rows.map((row) => row.id), ['7', '8', '9']);
      expect(rows.map((row) => row.name), ['Ogunlade Bolaji', 'Kim', 'Amina']);
      expect(rows.map((row) => row.status), [
        ReissuanceStatus.queried,
        ReissuanceStatus.approved,
        ReissuanceStatus.pending,
      ]);
      expect(rows.first.reference, 'BRT9');
      expect(rows.first.createdOn, DateTime.utc(2026, 9, 23, 10));
      expect(rows[1].reference, '');
    });
  });

  test('the demo backend lists requests on the API paths', () async {
    final (repository, requests) = _demo();

    final counts = _ok(await repository.counts(ReissuanceKind.attestation));
    final approved = _ok(
      await repository.requests(
        kind: ReissuanceKind.birth,
        status: ReissuanceStatus.approved,
      ),
    );
    final all = _ok(
      await repository.requests(kind: ReissuanceKind.birth, query: 'kim'),
    );

    expect(counts.total, 4);
    expect(approved, hasLength(2));
    expect(
      approved.every((r) => r.status == ReissuanceStatus.approved),
      isTrue,
    );
    expect(all.single.name, 'Kim David');
    expect(requests, [
      'GET /certificate-reissuance-assisted/birth-attest-stats?',
      'GET /certificate-reissuance-assisted/birth-reg-list?page=1&type=approved',
      'GET /certificate-reissuance-assisted/birth-reg-list?page=1&search=kim',
    ]);
  });

  group('ReissuanceHomeCubit', () {
    late FakeReissuanceRepository repository;
    setUp(() => repository = FakeReissuanceRepository());

    ReissuanceHomeCubit build() =>
        ReissuanceHomeCubit(repository, searchDelay: Duration.zero);

    blocTest<ReissuanceHomeCubit, ReissuanceHomeState>(
      'loads the birth tab: all requests and the counts',
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.isLoading, isFalse);
        expect(cubit.state.counts.total, 4);
        expect(cubit.state.items, sampleRequests);
        expect(repository.requestsAsked, [(ReissuanceKind.birth, null, '')]);
      },
    );

    blocTest<ReissuanceHomeCubit, ReissuanceHomeState>(
      'a card filters by its status; Total shows them all again',
      build: build,
      act: (cubit) async {
        await cubit.statusSelected(ReissuanceStatus.queried);
        await cubit.statusSelected(null);
      },
      verify: (cubit) {
        expect(cubit.state.status, isNull);
        expect(repository.requestsAsked, [
          (ReissuanceKind.birth, ReissuanceStatus.queried, ''),
          (ReissuanceKind.birth, null, ''),
        ]);
      },
    );

    blocTest<ReissuanceHomeCubit, ReissuanceHomeState>(
      'the attestation tab loads its own counts and list',
      build: build,
      act: (cubit) => cubit.kindSelected(ReissuanceKind.attestation),
      verify: (cubit) {
        expect(cubit.state.kind, ReissuanceKind.attestation);
        expect(repository.countsAsked, [ReissuanceKind.attestation]);
        expect(repository.requestsAsked.single.$1, ReissuanceKind.attestation);
      },
    );

    blocTest<ReissuanceHomeCubit, ReissuanceHomeState>(
      'searches after typing stops',
      build: build,
      act: (cubit) async {
        cubit.queryChanged(' lee ');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      verify: (_) => expect(repository.requestsAsked, [
        (ReissuanceKind.birth, null, 'lee'),
      ]),
    );

    blocTest<ReissuanceHomeCubit, ReissuanceHomeState>(
      'a failed list is reported; failed counts show as 0',
      setUp: () => repository
        ..countsResult = const Err(NetworkFailure())
        ..requestsResult = const Err(ServerFailure(statusCode: 500)),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.failure, const ServerFailure(statusCode: 500));
        expect(cubit.state.counts, const ReissuanceCounts());
      },
    );
  });

  group('home page', () {
    late FakeReissuanceRepository repository;
    late List<String> opened;
    setUp(() {
      repository = FakeReissuanceRepository();
      opened = [];
    });

    Future<void> pumpHome(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(400, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        ReissuanceHomePage(
          repository: repository,
          onStart: () async => opened.add('start'),
          onResume: (draft) async => opened.add(draft.nextStep.name),
          onOpenDetails: (kind, id) async => opened.add('details $id'),
          onUpdate: (kind, id) async => opened.add('update $id'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the tabs, the four cards and the requests', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Certificate Reissuance'), findsOneWidget);
      expect(find.text('Birth Reissuance'), findsOneWidget);
      expect(find.text('Attestation Reissuance'), findsOneWidget);
      for (final label in ['Total', 'Pending', 'Approved', 'Queried']) {
        expect(find.widgetWithText(AppStatCard, label), findsOneWidget);
      }
      expect(find.text('Lee Michael'), findsOneWidget);
      expect(find.text('Martinez Sofia'), findsOneWidget);
    });

    testWidgets('a new request starts with payment', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.byTooltip('New reissuance'));
      await tester.pumpAndSettle();

      expect(opened, ['start']);
    });

    testWidgets('an unfinished request can be resumed where it stopped', (
      tester,
    ) async {
      repository.draft = ReissuanceDraft(
        startedOn: DateTime(2026, 10, 4),
        mode: ValidationMode.nin,
        ninRecord: ninRecord,
        facePhoto: 'face.jpg',
      );
      await pumpHome(tester);

      await tester.tap(find.byTooltip('New reissuance'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(opened, ['certificate']);
      expect(repository.discards, 0);
    });

    testWidgets('starting over deletes the unfinished request', (tester) async {
      repository.draft = ReissuanceDraft(
        startedOn: DateTime(2026, 10, 4),
        mode: ValidationMode.nin,
        ninRecord: ninRecord,
        facePhoto: 'face.jpg',
      );
      await pumpHome(tester);

      await tester.tap(find.byTooltip('New reissuance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start new'));
      await tester.pumpAndSettle();

      expect(opened, ['start']);
      expect(repository.deleted, ['face.jpg']);
    });
  });
}
