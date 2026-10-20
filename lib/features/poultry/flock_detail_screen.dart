import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../health/health_form_screen.dart';
import '../health/health_widgets.dart';
import '../sales/new_sale_screen.dart';
import '../system/not_found_screen.dart';
import 'flock_form_screen.dart';
import 'flock_sheets.dart';

class FlockDetailScreen extends StatelessWidget {
  const FlockDetailScreen({super.key, required this.flockId});
  final String flockId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final f = store.flock(flockId);
    if (f == null) return const NotFoundScreen(message: 'This flock was deleted.');

    final alive = store.birdsAlive(f.id);
    final deaths = store.deathsIn(f.id);
    final sold = store.birdsSoldFrom(f.id);
    final mort = store.mortalityRate(f.id);
    final eggs = store.eggsOf(f.id);
    final deathsList = store.mortalityOf(f.id);
    final health = store.healthOf(TargetType.flock, f.id);
    final now = DateTime.now();
    final last14 = [
      for (var i = 13; i >= 0; i--)
        () {
          final d = now.subtract(Duration(days: i));
          return ChartPoint(Fmt.dateShort(d), store.eggsOnDay(d, flockId: f.id).toDouble());
        }(),
    ];
    final eggsWeek = store.eggsInRange(DateRange.lastDays(7));

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: f.type.color.withValues(alpha: 0.25),
            leading: const Padding(padding: EdgeInsets.all(6), child: BackButtonX()),
            leadingWidth: 60,
            actions: [
              CircleIconButton(
                icon: PhosphorIconsBold.pencilSimple,
                tooltip: 'Edit',
                onTap: () => go(context, FlockFormScreen(flock: f)),
              ),
              const SizedBox(width: 8),
              _FlockMenu(flock: f),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [f.type.color.withValues(alpha: 0.35), context.palette.background],
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: Hero(tag: 'flock-${f.id}', child: Image.asset(f.type.image, height: 150)),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(f.name, style: context.text.displaySmall)),
                    StatusPill(f.status.label, color: f.status.color),
                  ],
                ).enter(0),
                const SizedBox(height: 4),
                Text(
                  '${f.type.label} · ${f.breed} · ${f.ageWeeks} weeks old${f.house.isNotEmpty ? ' · ${f.house}' : ''}',
                  style: context.text.bodyMedium,
                ).enter(1),
                const SizedBox(height: 18),
                GridView.count(
                  padding: EdgeInsets.zero,
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.3,
                  children: [
                    StatTile(
                      icon: PhosphorIconsBold.bird,
                      color: AppColors.forest,
                      value: alive,
                      label: 'Birds alive',
                      caption: 'Started with ${Fmt.number(f.initialCount)}',
                    ),
                    StatTile(
                      icon: PhosphorIconsBold.heartbeat,
                      color: mort > 5 ? AppColors.danger : AppColors.success,
                      value: mort,
                      format: (v) => Fmt.percent(v, decimals: 1),
                      label: 'Mortality',
                      caption: '$deaths died · $sold sold',
                    ),
                    if (f.type.laysEggs) ...[
                      StatTile(
                        icon: PhosphorIconsBold.egg,
                        color: AppColors.amber,
                        value: store.layRate(f.id),
                        format: (v) => Fmt.percent(v),
                        label: 'Lay rate (7 days)',
                      ),
                      StatTile(icon: PhosphorIconsBold.basket, color: AppColors.warning, value: eggsWeek, label: 'Eggs this week'),
                    ],
                  ].indexed.map((e) => e.$2.enter(e.$1 + 2)).toList(),
                ),
                if (f.isActive) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (f.type.laysEggs) ...[
                        Expanded(
                          child: _Btn(
                            icon: PhosphorIconsBold.egg,
                            label: 'Eggs',
                            onTap: () => showEggSheet(context, flockId: f.id),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _Btn(
                          icon: PhosphorIconsBold.skull,
                          label: 'Deaths',
                          onTap: () => showMortalitySheet(context, flockId: f.id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Btn(
                          icon: PhosphorIconsBold.syringe,
                          label: 'Health',
                          onTap: () => go(context, HealthFormScreen(targetType: TargetType.flock, targetId: f.id)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Btn(
                          icon: PhosphorIconsBold.receipt,
                          label: 'Sell',
                          onTap: () =>
                              go(context, NewSaleScreen(product: f.type == BirdType.broilers ? Product.dressedChicken : Product.liveChicken, flockId: f.id)),
                        ),
                      ),
                    ],
                  ),
                ],
                if (f.type.laysEggs) ...[
                  const SectionHeader('Eggs – last 14 days', padding: EdgeInsets.fromLTRB(0, 24, 0, 10)),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    child: TrendChart(points: last14, color: AppColors.warning),
                  ),
                  if (eggs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (final (i, e) in eggs.take(7).indexed) ...[
                            if (i > 0) const Divider(),
                            RecordTile(
                              icon: PhosphorIconsBold.egg,
                              color: AppColors.warning,
                              title: '${Fmt.number(e.good)} good eggs',
                              subtitle: '${Fmt.dayMonth(e.date)}${e.broken > 0 ? ' · ${e.broken} broken' : ''}',
                              trailing: (e.good / store.eggsPerTray).toStringAsFixed(1),
                              trailingSub: 'trays',
                              onTap: () => showEggSheet(context, existing: e),
                              onLongPress: () async {
                                if (await confirm(context, title: 'Delete egg record?', message: '${e.good} eggs on ${Fmt.date(e.date)} will be removed.')) {
                                  await guard(() => store.deleteEggs(e.id), success: 'Deleted');
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
                const SectionHeader('Deaths', padding: EdgeInsets.fromLTRB(0, 24, 0, 10)),
                if (deathsList.isEmpty)
                  AppCard(
                    child: Row(
                      children: [
                        const IconTile(icon: PhosphorIconsBold.heart, color: AppColors.success),
                        const SizedBox(width: 12),
                        Expanded(child: Text('No deaths recorded. Great work!', style: context.text.bodyMedium)),
                      ],
                    ),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, m) in deathsList.take(6).indexed) ...[
                          if (i > 0) const Divider(),
                          RecordTile(
                            icon: PhosphorIconsBold.skull,
                            color: AppColors.danger,
                            title: '${m.count} ${m.count == 1 ? 'bird' : 'birds'} · ${m.cause}',
                            subtitle: '${Fmt.date(m.date)}${m.notes.isNotEmpty ? ' · ${m.notes}' : ''}',
                            onLongPress: () async {
                              if (await confirm(context, title: 'Delete record?', message: 'The birds will be counted as alive again.')) {
                                await guard(() => store.deleteMortality(m.id), success: 'Deleted');
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                SectionHeader(
                  'Health & vaccination',
                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 10),
                  action: f.isActive ? 'Add' : null,
                  onAction: () => go(context, HealthFormScreen(targetType: TargetType.flock, targetId: f.id)),
                ),
                if (health.isEmpty)
                  AppCard(child: Text('No vaccinations recorded. Keep your schedule here to get reminders.', style: context.text.bodyMedium))
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, h) in health.indexed) ...[if (i > 0) const Divider(), HealthTile(record: h, showTarget: false)],
                      ],
                    ),
                  ),
                const SectionHeader('Details', padding: EdgeInsets.fromLTRB(0, 24, 0, 10)),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      InfoRow(label: 'Date in', value: Fmt.date(f.startDate), icon: PhosphorIconsRegular.calendarBlank),
                      InfoRow(label: 'Age when bought', value: '${f.ageAtStartWeeks} weeks', icon: PhosphorIconsRegular.clock),
                      if (f.costPerBird != null) InfoRow(label: 'Cost per bird', value: Fmt.money(f.costPerBird!), icon: PhosphorIconsRegular.money),
                      if (f.notes.isNotEmpty) InfoRow(label: 'Notes', value: f.notes, icon: PhosphorIconsRegular.note),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: context.palette.brandTint, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          Text(label, style: context.text.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    ),
  );
}

class _FlockMenu extends StatelessWidget {
  const _FlockMenu({required this.flock});
  final Flock flock;

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    return CircleIconButton(
      icon: PhosphorIconsBold.dotsThreeVertical,
      tooltip: 'More',
      onTap: () async {
        final a = await showOptionsSheet<String>(
          context,
          title: flock.name,
          options: [
            PickerOption(
              'close',
              flock.isActive ? 'Close flock' : 'Re-open flock',
              subtitle: flock.isActive ? 'All sold or finished. Keeps its history.' : null,
              icon: flock.isActive ? PhosphorIconsBold.archive : PhosphorIconsBold.arrowCounterClockwise,
            ),
            const PickerOption(
              'delete',
              'Delete flock',
              subtitle: 'Removes eggs, deaths and health records',
              icon: PhosphorIconsBold.trash,
              color: AppColors.danger,
            ),
          ],
        );
        if (!context.mounted || a == null) return;
        if (a == 'close') {
          await guard(() => store.closeFlock(flock.id), success: flock.isActive ? 'Flock closed' : 'Flock re-opened');
        } else if (await confirm(context, title: 'Delete ${flock.name}?', message: 'All egg, death and health records for this flock will be deleted.')) {
          final ok = await guard(() => store.deleteFlock(flock.id), success: 'Flock deleted');
          if (ok && context.mounted) Navigator.pop(context);
        }
      },
    );
  }
}
