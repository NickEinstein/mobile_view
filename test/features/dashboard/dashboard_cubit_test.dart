import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:vital_reg_mobile/features/dashboard/data/dtos/dashboard_summary_dto.dart';
import 'package:vital_reg_mobile/features/dashboard/domain/dashboard_repository.dart';
import 'package:vital_reg_mobile/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:vital_reg_mobile/features/dashboard/presentation/cubit/dashboard_cubit.dart';

import '../../helpers/demo_backend.dart';

class _MockDashboardRepository extends Mock implements DashboardRepository {}

DashboardSummary _summary(int year, int births) => DashboardSummary(
  year: year,
  stats: {
    RegistrationCategory.birthRegistration: CategoryStats(
      total: births,
      monthly: [births, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ),
  },
);

void main() {
  late _MockDashboardRepository repository;

  setUp(() => repository = _MockDashboardRepository());

  DashboardCubit build() => DashboardCubit(repository, currentYear: 2026);

  group('DashboardSummaryDto', () {
    test('reads counts sent as numbers or as SQL strings', () {
      final counts = DashboardSummaryDto.countsFromJson({
        'birth': '12',
        'attestation': 3,
        'death': '0',
      });

      expect(counts, {
        RegistrationCategory.birthRegistration: 12,
        RegistrationCategory.birthAttestation: 3,
        RegistrationCategory.deathRegistration: 0,
        RegistrationCategory.stillBirth: 0,
      });
    });

    test('rejects a monthly series without 12 values', () {
      expect(
        () => DashboardSummaryDto.monthlyFromJson([1, 2]),
        throwsFormatException,
      );
    });
  });

  test('reads the API statistics: all-time cards, yearly chart', () async {
    final backend = demoBackend();
    final summary = ok(
      await DashboardRepositoryImpl(backend.client).summary(year: 2025),
    );

    expect(
      backend.paths,
      unorderedEquals([
        'GET /statistics/counts',
        'GET /statistics/birth',
        'GET /statistics/attestation',
        'GET /statistics/death',
        'GET /statistics/stillbirth',
      ]),
    );
    final births = summary.of(RegistrationCategory.birthRegistration);
    expect(births.monthly, hasLength(12));
    expect(
      births.total,
      greaterThan(births.monthly.reduce((a, b) => a + b)),
      reason: 'the card counts all time, the chart one year',
    );
  });

  blocTest<DashboardCubit, DashboardState>(
    'loads the current year',
    setUp: () => when(
      () => repository.summary(year: 2026),
    ).thenAnswer((_) async => Ok(_summary(2026, 5))),
    build: build,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.status, DashboardStatus.ready);
      expect(
        cubit.state.statsOf(RegistrationCategory.birthRegistration).total,
        5,
      );
    },
  );

  blocTest<DashboardCubit, DashboardState>(
    'changing the year reloads that year',
    setUp: () => when(
      () => repository.summary(year: 2025),
    ).thenAnswer((_) async => Ok(_summary(2025, 9))),
    build: build,
    act: (cubit) => cubit.yearChanged(2025),
    verify: (cubit) {
      expect(cubit.state.year, 2025);
      expect(cubit.state.summary?.year, 2025);
      verify(() => repository.summary(year: 2025)).called(1);
    },
  );

  blocTest<DashboardCubit, DashboardState>(
    'tapping a card selects its category for the chart',
    build: build,
    act: (cubit) =>
        cubit.categorySelected(RegistrationCategory.deathRegistration),
    verify: (cubit) =>
        expect(cubit.state.category, RegistrationCategory.deathRegistration),
  );

  blocTest<DashboardCubit, DashboardState>(
    'shows the failure when loading fails',
    setUp: () => when(
      () => repository.summary(year: 2026),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.status, DashboardStatus.failure);
      expect(cubit.state.failure, const NetworkFailure());
    },
  );

  test('offers the last five years, newest first', () {
    expect(const DashboardState(year: 2026, currentYear: 2026).years, [
      2026,
      2025,
      2024,
      2023,
      2022,
    ]);
  });
}
