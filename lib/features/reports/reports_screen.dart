import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../customers/customers_screen.dart';
import '../finance/expenses_screen.dart';
import '../sales/receipt_pdf.dart';
import 'report_pdf.dart';

enum _Period { days30, days90, year, all }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Period _period = _Period.days30;
  bool _exporting = false;

  DateRange get _range => switch (_period) {
    _Period.days30 => DateRange.lastDays(30),
    _Period.days90 => DateRange.lastDays(90),
    _Period.year => DateRange.thisYear(),
    _Period.all => DateRange.allTime(),
  };

  String get _label => switch (_period) {
    _Period.days30 => 'Last 30 days',
    _Period.days90 => 'Last 90 days',
    _Period.year => 'This year',
    _Period.all => 'All time',
  };

  /// Weekly buckets for 30 days, monthly otherwise.
  List<ChartPoint> _cashflow(FarmStore store) {
    final now = DateTime.now();
    if (_period == _Period.days30) {
      final end = dateOnly(now).add(const Duration(days: 1));
      return [
        for (var w = 4; w >= 0; w--)
          () {
            final r = DateRange(end.subtract(Duration(days: (w + 1) * 7)), end.subtract(Duration(days: w * 7)));
            return ChartPoint(Fmt.dateShort(r.start), store.revenueIn(r), value2: store.expenseTotalIn(r));
          }(),
      ];
    }
    final months = switch (_period) {
      _Period.days90 => 3,
      _Period.year => now.month,
      _ => () {
        final all = [...store.sales.map((s) => s.date), ...store.expenses.map((e) => e.date)];
        if (all.isEmpty) return 1;
        final first = all.reduce((a, b) => a.isBefore(b) ? a : b);
        return ((now.year - first.year) * 12 + now.month - first.month + 1).clamp(1, 12);
      }(),
    };
    return [
      for (var m = months - 1; m >= 0; m--)
        () {
          final start = DateTime(now.year, now.month - m);
          final r = DateRange(start, DateTime(start.year, start.month + 1));
          return ChartPoint(Fmt.monthShort(start), store.revenueIn(r), value2: store.expenseTotalIn(r));
        }(),
    ];
  }

  Future<void> _export(FarmStore store) async {
    setState(() => _exporting = true);
    await guard(() async {
      final bytes = await buildFarmReport(store, _range, _label);
      await sharePdf(bytes, 'farm-report-${DateTime.now().toIso8601String().substring(0, 10)}.pdf');
    }, haptic: false);
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final r = _range;
    final revenue = store.revenueIn(r);
    final costs = store.expenseTotalIn(r);
    final profit = revenue - costs;
    final margin = revenue == 0 ? 0.0 : profit / revenue * 100;
    final byProduct = store.revenueByProduct(r);
    final days = _period == _Period.days30 ? 30 : 60;
    final now = DateTime.now();
    final eggPoints = [
      for (var i = days - 1; i >= 0; i -= (days > 30 ? 2 : 1))
        () {
          final d = now.subtract(Duration(days: i));
          return ChartPoint(Fmt.dateShort(d), store.eggsOnDay(d).toDouble());
        }(),
    ];
    final topCustomers =
        store.customers
            .map((c) => (c, store.salesOf(c.id).where((s) => r.contains(s.date)).fold<double>(0, (a, s) => a + s.total)))
            .where((e) => e.$2 > 0)
            .toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(child: Text('Reports', style: context.text.displaySmall)),
                    _exporting
                        ? const SizedBox(
                            width: 44,
                            height: 44,
                            child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2.4)),
                          )
                        : CircleIconButton(icon: PhosphorIconsBold.filePdf, tooltip: 'Export PDF', onTap: () => _export(store)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FilterChips<_Period>(
                value: _period,
                onChanged: (v) => setState(() => _period = v),
                items: const [(_Period.days30, '30 days'), (_Period.days90, '90 days'), (_Period.year, 'This year'), (_Period.all, 'All time')],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: MoneySummary(
                  title: profit >= 0 ? 'Net profit · $_label' : 'Net loss · $_label',
                  amount: profit,
                  signed: true,
                  badge: '${margin.abs().toStringAsFixed(0)}% margin',
                  split: (revenue, costs),
                  stats: [
                    SummaryStat('Sales', Fmt.money(revenue, compact: true), AppColors.lime),
                    SummaryStat('Costs', Fmt.money(costs, compact: true), AppColors.terracottaLight),
                    SummaryStat('Owed to you', Fmt.money(store.totalOwed, compact: true), AppColors.amber),
                  ],
                ).enter(0),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader('Sales vs costs', action: 'Expenses', onAction: () => go(context, const ExpensesScreen())),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(8, 18, 16, 10),
                  child: Column(
                    children: [
                      DualBarChart(points: _cashflow(store), color1: AppColors.sageDeep, color2: AppColors.forest),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [_legend(context, AppColors.sageDeep, 'Sales'), const SizedBox(width: 18), _legend(context, AppColors.forest, 'Costs')],
                      ),
                    ],
                  ),
                ).enter(1),
              ),
            ),
            const SliverToBoxAdapter(child: SectionHeader('Where sales come from')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  child: DonutChart(centerLabel: 'sales', slices: [for (final e in byProduct.entries) DonutSlice(e.key.label, e.value, _productColor(e.key))]),
                ).enter(2),
              ),
            ),
            if (store.farm?.birdTypes.any((b) => b.laysEggs) ?? true) ...[
              const SliverToBoxAdapter(child: SectionHeader('Egg production')),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(8, 18, 16, 10),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 12),
                          child: Row(
                            children: [
                              _MiniStat(label: 'Good eggs', value: Fmt.number(store.eggsInRange(r))),
                              _MiniStat(label: 'Broken', value: Fmt.number(store.brokenInRange(r))),
                              _MiniStat(label: 'In stock', value: '${(store.eggStock / store.eggsPerTray).toStringAsFixed(1)} tr'),
                            ],
                          ),
                        ),
                        TrendChart(points: eggPoints, color: AppColors.warning, height: 180),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SectionHeader('Livestock')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      InfoRow(label: 'Active pigs', value: '${store.activePigs.length}', icon: PhosphorIconsRegular.pawPrint, bold: true),
                      for (final e in store.pigsByStage.entries) InfoRow(label: '   ${e.key.label}', value: '${e.value}'),
                      const Divider(),
                      InfoRow(label: 'Birds alive', value: Fmt.number(store.totalBirds), icon: PhosphorIconsRegular.bird, bold: true),
                      InfoRow(
                        label: 'Bird deaths in period',
                        value: Fmt.number(store.deathsInRange(r)),
                        icon: PhosphorIconsRegular.skull,
                        valueColor: AppColors.danger,
                      ),
                      InfoRow(label: 'Feed used in period', value: Fmt.kg(store.feedUsedIn(r).round()), icon: PhosphorIconsRegular.grains),
                    ],
                  ),
                ),
              ),
            ),
            if (topCustomers.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader('Top customers', action: 'All', onAction: () => go(context, const CustomersScreen())),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(
                      children: [
                        for (final (i, (c, v)) in topCustomers.take(5).indexed)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  child: Text('${i + 1}', style: context.text.titleSmall?.copyWith(color: context.palette.inkMuted)),
                                ),
                                Avatar(initials: c.initials, size: 36),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(c.name, style: context.text.titleSmall, overflow: TextOverflow.ellipsis),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(Fmt.money(v), style: context.text.titleSmall),
                                    SizedBox(
                                      width: 90,
                                      child: Meter(value: v / topCustomers.first.$2, height: 5, color: AppColors.lime),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 130),
                child: PrimaryButton(label: 'Export full report (PDF)', icon: PhosphorIconsBold.filePdf, loading: _exporting, onPressed: () => _export(store)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _productColor(Product p) => switch (p) {
    Product.eggs => AppColors.amber,
    Product.liveChicken => AppColors.pinkDeep,
    Product.dressedChicken => AppColors.warning,
    Product.pig => AppColors.forest,
    Product.piglet => AppColors.lime,
    Product.manure => AppColors.inkSoft,
  };

  Widget _legend(BuildContext context, Color c, String l) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 6),
      Text(l, style: context.text.labelMedium),
    ],
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: context.text.titleMedium),
        Text(label, style: context.text.labelSmall),
      ],
    ),
  );
}
