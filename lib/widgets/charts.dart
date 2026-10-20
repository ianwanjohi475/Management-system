import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';

class ChartPoint {
  const ChartPoint(this.label, this.value, {this.value2});
  final String label;
  final double value;
  final double? value2;
}

/// Smooth area line chart for trends (growth, eggs per day).
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.points, this.color = AppColors.forest, this.height = 200, this.format, this.showDots = false});

  final List<ChartPoint> points;
  final Color color;
  final double height;
  final String Function(double)? format;
  final bool showDots;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (points.length < 2) {
      return SizedBox(
        height: height * 0.6,
        child: Center(child: Text('Add at least two records to see a trend.', style: context.text.bodySmall)),
      );
    }
    final values = points.map((e) => e.value).toList();
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final pad = (maxV - minV).abs() * 0.15 + (maxV == 0 ? 1 : maxV * 0.02);
    final step = (points.length / 5).ceil().clamp(1, 1000);
    final fmt = format ?? (double v) => Fmt.axis(v);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: math.max(0, minV - pad),
          maxY: maxV + pad,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: ((maxV + pad) - math.max(0, minV - pad)) / 4 == 0 ? 1 : ((maxV + pad) - math.max(0, minV - pad)) / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: p.border, strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (v, meta) => (v == meta.max || v == meta.min)
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(fmt(v), maxLines: 1, softWrap: false, style: context.text.labelSmall),
                      ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= points.length || (i % step != 0 && i != points.length - 1)) return const SizedBox.shrink();
                  if (i != points.length - 1 && points.length - 1 - i < step / 2) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(points[i].label, style: context.text.labelSmall),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.forestDeep,
              tooltipBorderRadius: BorderRadius.circular(10),
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      '${points[s.x.round()].label}\n',
                      const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Inter'),
                      children: [
                        TextSpan(
                          text: fmt(s.y),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value)],
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 3,
              dotData: FlDotData(
                show: showDots,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 3.5, color: Colors.white, strokeColor: color, strokeWidth: 2),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

/// Grouped bars: income (value) vs costs (value2).
class DualBarChart extends StatelessWidget {
  const DualBarChart({super.key, required this.points, this.height = 220, this.color1 = AppColors.forest, this.color2 = AppColors.amber});

  final List<ChartPoint> points;
  final double height;
  final Color color1;
  final Color color2;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxV = points.fold<double>(0, (m, e) => math.max(m, math.max(e.value, e.value2 ?? 0)));
    final top = maxV == 0 ? 100.0 : maxV * 1.15;
    final w = points.length > 8 ? 6.0 : 10.0;
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: top,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: top / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: p.border, strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: top / 4,
                getTitlesWidget: (v, meta) => v == meta.max
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(Fmt.axis(v), style: context.text.labelSmall),
                      ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  if (points.length > 8 && i % 2 == 1) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(points[i].label, style: context.text.labelSmall),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.forestDeep,
              tooltipBorderRadius: BorderRadius.circular(10),
              getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                '${rodIndex == 0 ? 'Sales' : 'Costs'}\n',
                const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Inter'),
                children: [
                  TextSpan(
                    text: Fmt.money(rod.toY),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 3,
                barRods: [
                  BarChartRodData(toY: points[i].value, color: color1, width: w, borderRadius: BorderRadius.circular(4)),
                  BarChartRodData(toY: points[i].value2 ?? 0, color: color2, width: w, borderRadius: BorderRadius.circular(4)),
                ],
              ),
          ],
        ),
        duration: const Duration(milliseconds: 600),
      ),
    );
  }
}

class DonutSlice {
  const DonutSlice(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// Donut with a legend, for "where the money comes from / goes".
class DonutChart extends StatefulWidget {
  const DonutChart({super.key, required this.slices, required this.centerLabel, this.size = 160});
  final List<DonutSlice> slices;
  final String centerLabel;
  final double size;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final total = widget.slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) {
      return SizedBox(
        height: 120,
        child: Center(child: Text('No data for this period yet.', style: context.text.bodySmall)),
      );
    }
    final slices = widget.slices.where((s) => s.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    return Row(
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: widget.size * 0.32,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (e, r) =>
                        setState(() => _touched = (e.isInterestedForInteractions && r?.touchedSection != null) ? r!.touchedSection!.touchedSectionIndex : -1),
                  ),
                  sections: [
                    for (var i = 0; i < slices.length; i++)
                      PieChartSectionData(
                        value: slices[i].value,
                        color: slices[i].color,
                        radius: _touched == i ? widget.size * 0.2 : widget.size * 0.16,
                        showTitle: false,
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 500),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _touched >= 0 && _touched < slices.length ? '${(slices[_touched].value / total * 100).round()}%' : Fmt.money(total, compact: true),
                    style: context.text.titleMedium,
                  ),
                  Text(_touched >= 0 && _touched < slices.length ? slices[_touched].label : widget.centerLabel, style: context.text.labelSmall),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in slices.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.label,
                          style: context.text.bodySmall?.copyWith(color: context.palette.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('${(s.value / total * 100).round()}%', style: context.text.labelMedium),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
