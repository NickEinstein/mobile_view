part of 'dashboard_page.dart';

/// Category name, year picker and year total, above a monthly line chart.
class _RegistrationsChart extends StatelessWidget {
  const _RegistrationsChart();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<DashboardCubit>().state;
    final stats = state.statsOf(state.category);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppPalette.cardBorder),
        borderRadius: BorderRadius.circular(Spacing.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.sm + Spacing.xs,
          Spacing.xs,
          Spacing.sm + Spacing.xs,
          Spacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Title and year take all the width the total doesn't need.
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          state.category.shortLabel(l10n),
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppPalette.inkStrong,
                          ),
                        ),
                      ),
                      const _YearPicker(),
                    ],
                  ),
                ),
                Text(
                  l10n.chartYearTotal(stats.total),
                  style: textTheme.labelSmall?.copyWith(color: AppPalette.ink),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            if (state.status == DashboardStatus.failure)
              _LoadFailed(state: state)
            else
              SizedBox(
                height: 160,
                child: _MonthlyLine(
                  monthly: stats.monthly,
                  // Months still to come in the current year aren't drawn.
                  lastMonth: state.year == state.currentYear
                      ? DateTime.now().month
                      : 12,
                  loading: state.status == DashboardStatus.loading,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _YearPicker extends StatelessWidget {
  const _YearPicker();

  @override
  Widget build(BuildContext context) {
    final (year, years) = context.select(
      (DashboardCubit cubit) => (cubit.state.year, cubit.state.years),
    );
    return PopupMenuButton<int>(
      tooltip: context.l10n.chartChooseYear,
      initialValue: year,
      onSelected: (year) =>
          unawaited(context.read<DashboardCubit>().yearChanged(year)),
      itemBuilder: (_) => [
        for (final y in years) PopupMenuItem(value: y, child: Text('$y')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$year',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.inkStrong),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),
      ),
    );
  }
}

class _MonthlyLine extends StatelessWidget {
  const _MonthlyLine({
    required this.monthly,
    required this.loading,
    required this.lastMonth,
  });

  final List<int> monthly;

  /// 1–12: the line stops after this month.
  final int lastMonth;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final axisStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AppPalette.muted, fontSize: 9);
    final locale = Localizations.localeOf(context).toString();
    final months = [
      for (var m = 1; m <= 12; m++)
        DateFormat.MMM(locale).format(DateTime(2000, m)),
    ];
    final peak = monthly.fold<int>(0, (a, b) => a > b ? a : b);
    // An empty year still shows a 0–1 scale, as in the designs.
    final maxY = peak == 0 ? 1.0 : (peak * 1.2).ceilToDouble();

    return AnimatedOpacity(
      opacity: loading ? 0.4 : 1,
      duration: const Duration(milliseconds: 200),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 11,
          minY: 0,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppPalette.cardBorder, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: maxY / 5,
                getTitlesWidget: (value, _) => Text(
                  peak == 0
                      ? value.toStringAsFixed(1)
                      : value.round().toString(),
                  style: axisStyle,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, _) => Padding(
                  padding: const EdgeInsets.only(top: Spacing.xs),
                  child: Text(months[value.toInt()], style: axisStyle),
                ),
              ),
            ),
          ),
          lineTouchData: const LineTouchData(enabled: true),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < lastMonth; i++)
                  FlSpot(i.toDouble(), monthly[i].toDouble()),
              ],
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppPalette.brand,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppPalette.brand.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 160,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            state.failure?.localize(l10n) ?? l10n.dashboardLoadFailed,
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: () => unawaited(context.read<DashboardCubit>().load()),
            child: Text(l10n.tryAgain),
          ),
        ],
      ),
    );
  }
}
