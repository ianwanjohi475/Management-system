import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import 'flock_sheets.dart';

class EggLogScreen extends StatefulWidget {
  const EggLogScreen({super.key});

  @override
  State<EggLogScreen> createState() => _EggLogScreenState();
}

class _EggLogScreenState extends State<EggLogScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final range = DateRange.lastDays(_days);
    final records = store.eggRecords.where((e) => range.contains(e.date)).toList();
    final perTray = store.eggsPerTray;
    final good = store.eggsInRange(range);
    final broken = store.brokenInRange(range);
    final now = DateTime.now();
    final points = [
      for (var i = _days - 1; i >= 0; i--)
        () {
          final d = now.subtract(Duration(days: i));
          return ChartPoint(Fmt.dateShort(d), store.eggsOnDay(d).toDouble());
        }(),
    ];

    // Group records by day.
    final byDay = <DateTime, List<EggRecord>>{};
    for (final r in records) {
      byDay.putIfAbsent(dateOnly(r.date), () => []).add(r);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showEggSheet(context),
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.ink,
        icon: const Icon(PhosphorIconsBold.egg),
        label: const Text('Collect eggs'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: PageHeader(title: 'Egg log', subtitle: 'Collection, breakages and stock'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: AppCard(
                  gradient: const LinearGradient(colors: [Color(0xFFF5B700), Color(0xFFFFD45C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Eggs in stock',
                              style: TextStyle(fontFamily: 'Inter', color: Color(0xFF4A3300), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            CountUp(
                              value: store.eggStock / perTray,
                              format: (v) => '${v.toStringAsFixed(1)} trays',
                              style: const TextStyle(fontFamily: 'Poppins', color: Color(0xFF2E2000), fontSize: 26, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${Fmt.number(store.eggStock)} eggs ready to sell',
                              style: const TextStyle(fontFamily: 'Inter', color: Color(0xFF4A3300), fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Image.asset(Assets.prodEggTray, width: 96),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(icon: PhosphorIconsBold.egg, color: AppColors.forest, value: good, label: 'Good eggs'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(icon: PhosphorIconsBold.eggCrack, color: AppColors.danger, value: broken, label: 'Broken'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        icon: PhosphorIconsBold.chartBar,
                        color: AppColors.info,
                        value: good / _days,
                        format: (v) => v.round().toString(),
                        label: 'Avg per day',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilterChips<int>(
                  value: _days,
                  onChanged: (v) => setState(() => _days = v),
                  items: const [(7, '7 days'), (30, '30 days'), (90, '90 days')],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                  child: TrendChart(points: points, color: AppColors.warning),
                ),
              ),
            ),
            if (days.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  image: Assets.emptyBasket,
                  title: 'No eggs recorded',
                  message: 'Record each collection to track your lay rate and stock.',
                  compact: true,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                sliver: SliverList.builder(
                  itemCount: days.length,
                  itemBuilder: (_, i) {
                    final d = days[i];
                    final recs = byDay[d]!;
                    final total = recs.fold<int>(0, (s, r) => s + r.good);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                          child: Row(
                            children: [
                              Text(
                                Fmt.relativeDay(d) == Fmt.dateShort(d) ? Fmt.dayMonth(d) : '${Fmt.relativeDay(d)} · ${Fmt.dateShort(d)}',
                                style: context.text.titleSmall,
                              ),
                              const Spacer(),
                              Text('${Fmt.number(total)} eggs', style: context.text.labelMedium),
                            ],
                          ),
                        ),
                        AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          child: Column(
                            children: [
                              for (final (j, r) in recs.indexed) ...[
                                if (j > 0) const Divider(),
                                RecordTile(
                                  icon: PhosphorIconsBold.egg,
                                  color: AppColors.warning,
                                  title: store.flock(r.flockId)?.name ?? 'Removed flock',
                                  subtitle: '${r.collected} collected${r.broken > 0 ? ' · ${r.broken} broken' : ''}',
                                  trailing: Fmt.number(r.good),
                                  trailingSub: 'good',
                                  onTap: () => showEggSheet(context, existing: r),
                                  onLongPress: () async {
                                    if (await confirm(context, title: 'Delete egg record?', message: 'This removes ${r.good} eggs from your stock.')) {
                                      await guard(() => store.deleteEggs(r.id), success: 'Deleted');
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ).enter(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
