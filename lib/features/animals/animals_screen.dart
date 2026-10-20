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
import '../pigs/breeding_screen.dart';
import '../pigs/pig_detail_screen.dart';
import '../pigs/pig_form_screen.dart';
import '../pigs/pig_sheets.dart';
import '../poultry/egg_log_screen.dart';
import '../poultry/flock_detail_screen.dart';
import '../poultry/flock_form_screen.dart';
import '../poultry/flock_sheets.dart';

class AnimalsScreen extends StatefulWidget {
  const AnimalsScreen({super.key, required this.tab});
  final ValueNotifier<int> tab;

  @override
  State<AnimalsScreen> createState() => _AnimalsScreenState();
}

class _AnimalsScreenState extends State<AnimalsScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this, initialIndex: widget.tab.value);

  @override
  void initState() {
    super.initState();
    widget.tab.addListener(_sync);
    _tabs.addListener(() => setState(() {}));
  }

  void _sync() {
    if (_tabs.index != widget.tab.value) _tabs.animateTo(widget.tab.value);
  }

  @override
  void dispose() {
    widget.tab.removeListener(_sync);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(child: Text('Animals', style: context.text.displaySmall)),
                  CircleIconButton(
                    icon: PhosphorIconsBold.plus,
                    tooltip: _tabs.index == 0 ? 'Add pig' : 'Add flock',
                    background: Theme.of(context).colorScheme.primary,
                    color: Theme.of(context).colorScheme.onPrimary,
                    onTap: () => go(context, _tabs.index == 0 ? const PigFormScreen() : const FlockFormScreen()),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.border),
              ),
              child: TabBar(
                controller: _tabs,
                onTap: (i) => widget.tab.value = i,
                tabs: const [
                  Tab(
                    height: 44,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(PhosphorIconsBold.piggyBank, size: 18), SizedBox(width: 8), Text('Pigs')]),
                  ),
                  Tab(
                    height: 44,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(PhosphorIconsBold.bird, size: 18), SizedBox(width: 8), Text('Poultry')]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(controller: _tabs, children: const [_PigsTab(), _PoultryTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PigFilter { all, breeding, growing, young, sold, dead }

class _PigsTab extends StatefulWidget {
  const _PigsTab();

  @override
  State<_PigsTab> createState() => _PigsTabState();
}

class _PigsTabState extends State<_PigsTab> with AutomaticKeepAliveClientMixin {
  _PigFilter _filter = _PigFilter.all;
  String _q = '';

  @override
  bool get wantKeepAlive => true;

  bool _match(Pig p) {
    final okFilter = switch (_filter) {
      _PigFilter.all => p.isActive,
      _PigFilter.breeding => p.isActive && p.stage.isBreeder,
      _PigFilter.growing => p.isActive && (p.stage == PigStage.grower || p.stage == PigStage.finisher),
      _PigFilter.young => p.isActive && p.stage.isYoung,
      _PigFilter.sold => p.status == PigStatus.sold,
      _PigFilter.dead => p.status == PigStatus.dead,
    };
    if (!okFilter) return false;
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return p.tag.toLowerCase().contains(q) || p.name.toLowerCase().contains(q) || p.breed.toLowerCase().contains(q) || p.pen.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final store = context.watch<FarmStore>();
    final pigs = store.pigs.where(_match).toList();
    final open = store.openBreedings.length;
    final nursing = store.nursingLitters.length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SearchBox(hint: 'Search tag, name, breed or pen', onChanged: (v) => setState(() => _q = v.trim())),
          ),
        ),
        SliverToBoxAdapter(
          child: FilterChips<_PigFilter>(
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
            items: [
              (_PigFilter.all, 'All active (${store.activePigs.length})'),
              (_PigFilter.breeding, 'Breeding'),
              (_PigFilter.growing, 'Growers'),
              (_PigFilter.young, 'Piglets & weaners'),
              (_PigFilter.sold, 'Sold'),
              (_PigFilter.dead, 'Dead'),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: AppCard(
              onTap: () => go(context, const BreedingScreen()),
              padding: const EdgeInsets.all(14),
              color: AppColors.pinkSoft.withValues(alpha: context.isDark ? 0.12 : 1),
              border: false,
              shadow: false,
              child: Row(
                children: [
                  Image.asset(Assets.prodPiglet, width: 50, height: 50),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Breeding & litters', style: context.text.titleMedium),
                        Text('$open served / pregnant · $nursing nursing', style: context.text.bodySmall?.copyWith(color: context.palette.inkSoft)),
                      ],
                    ),
                  ),
                  const Icon(PhosphorIconsBold.caretRight, size: 16, color: AppColors.pinkDeep),
                ],
              ),
            ),
          ),
        ),
        if (pigs.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              image: Assets.emptyPen,
              title: _q.isNotEmpty ? 'No pigs match "$_q"' : (store.pigs.isEmpty ? 'No pigs yet' : 'No pigs here'),
              message: store.pigs.isEmpty ? 'Add your sows, boars and growers to start tracking them.' : 'Try another filter or search.',
              actionLabel: store.pigs.isEmpty ? 'Add first pig' : null,
              onAction: () => go(context, const PigFormScreen()),
              compact: true,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            sliver: SliverGrid.builder(
              itemCount: pigs.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.74,
              ),
              itemBuilder: (_, i) => PigCard(pig: pigs[i]).enter(i),
            ),
          ),
      ],
    );
  }
}

class PigCard extends StatelessWidget {
  const PigCard({super.key, required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final w = store.latestWeight(pig.id);
    final breeding = pig.sex == Sex.female ? store.activeBreeding(pig.id) : null;
    return AppCard(
      onTap: () => go(context, PigDetailScreen(pigId: pig.id)),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Hero(
                  tag: 'pig-${pig.id}',
                  child: PigPhoto(photo: pig.photo, size: double.infinity, radius: 14, young: pig.stage.isYoung),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: breeding != null
                      ? StatusPill(breeding.status.label, color: breeding.status.color, solid: true)
                      : (!pig.isActive ? StatusPill(pig.status.label, color: pig.status.color, solid: true) : const SizedBox.shrink()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(pig.sex.icon, size: 14, color: pig.sex == Sex.female ? AppColors.pinkDeep : AppColors.info),
              const SizedBox(width: 4),
              Expanded(
                child: Text(pig.displayName, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('${pig.tag} · ${pig.stage.label}', style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w == null ? '— kg' : Fmt.kg(w.kg), style: context.text.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    Text(pig.birthDate == null ? '' : Fmt.age(pig.birthDate!), style: context.text.labelSmall),
                  ],
                ),
              ),
              if (pig.isActive)
                Pressable(
                  onTap: () => showWeightSheet(context, pigId: pig.id),
                  scale: 0.85,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: AppColors.forest, borderRadius: BorderRadius.circular(11)),
                    child: const Icon(PhosphorIconsBold.scales, size: 17, color: Colors.white),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PoultryTab extends StatefulWidget {
  const _PoultryTab();

  @override
  State<_PoultryTab> createState() => _PoultryTabState();
}

class _PoultryTabState extends State<_PoultryTab> with AutomaticKeepAliveClientMixin {
  BirdType? _type;
  bool _closed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final store = context.watch<FarmStore>();
    final flocks = store.flocks.where((f) => (_closed ? !f.isActive : f.isActive) && (_type == null || f.type == _type)).toList();
    final today = DateTime.now();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                for (final (i, t) in BirdType.values.indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _BirdSummary(type: t, count: store.birdsOfType(t), selected: _type == t, onTap: () => setState(() => _type = _type == t ? null : t)),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: AppCard(
              onTap: () => go(context, const EggLogScreen()),
              padding: const EdgeInsets.all(14),
              color: AppColors.amberSoft.withValues(alpha: context.isDark ? 0.1 : 1),
              border: false,
              shadow: false,
              child: Row(
                children: [
                  Image.asset(Assets.catEggs, width: 50, height: 50),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Egg log', style: context.text.titleMedium),
                        Text(
                          '${Fmt.number(store.eggsOnDay(today))} today · ${(store.eggStock / store.eggsPerTray).toStringAsFixed(1)} trays in stock',
                          style: context.text.bodySmall?.copyWith(color: context.palette.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: () => showEggSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIconsBold.plus, size: 14, color: AppColors.ink),
                          SizedBox(width: 4),
                          Text(
                            'Record',
                            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: FilterChips<bool>(
              value: _closed,
              onChanged: (v) => setState(() => _closed = v),
              items: [(false, 'Active (${store.activeFlocks.length})'), (true, 'Closed')],
            ),
          ),
        ),
        if (flocks.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              image: Assets.emptyPen,
              title: _closed ? 'No closed flocks' : 'No flocks yet',
              message: _closed ? 'Flocks you close (sold out or finished) show here.' : 'Add a flock of layers, broilers or kienyeji to start.',
              actionLabel: _closed ? null : 'Add a flock',
              onAction: () => go(context, const FlockFormScreen()),
              compact: true,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            sliver: SliverList.separated(
              itemCount: flocks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => FlockCard(flock: flocks[i]).enter(i),
            ),
          ),
      ],
    );
  }
}

class _BirdSummary extends StatelessWidget {
  const _BirdSummary({required this.type, required this.count, required this.selected, required this.onTap});
  final BirdType type;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? p.brandTint : p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : p.border, width: selected ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Image.asset(type.image, width: 44, height: 44),
            const SizedBox(height: 6),
            CountUp(value: count, style: context.text.titleLarge),
            Text(type.label, style: context.text.labelSmall),
          ],
        ),
      ),
    );
  }
}

class FlockCard extends StatelessWidget {
  const FlockCard({super.key, required this.flock});
  final Flock flock;

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final alive = store.birdsAlive(flock.id);
    final mort = store.mortalityRate(flock.id);
    final lay = flock.type.laysEggs ? store.layRate(flock.id) : null;
    final today = store.eggsOnDay(DateTime.now(), flockId: flock.id);
    return AppCard(
      onTap: () => go(context, FlockDetailScreen(flockId: flock.id)),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Hero(
                tag: 'flock-${flock.id}',
                child: Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: flock.type.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
                  child: Image.asset(flock.type.image),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(flock.name, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${flock.breed} · ${flock.ageWeeks} weeks old', style: context.text.bodySmall),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatusPill(flock.type.label, color: Color.lerp(flock.type.color, AppColors.ink, 0.25)!),
                        if (flock.house.isNotEmpty) ...[const SizedBox(width: 6), StatusPill(flock.house, color: context.palette.inkSoft)],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CountUp(value: alive, style: context.text.headlineMedium),
                  Text('of ${Fmt.number(flock.initialCount)} birds', style: context.text.labelSmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (lay != null) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Lay rate (7d)', style: context.text.labelSmall),
                          const Spacer(),
                          Text(Fmt.percent(lay), style: context.text.labelMedium?.copyWith(color: AppColors.warning)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Meter(value: lay / 100, color: AppColors.amber),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Mortality', style: context.text.labelSmall),
                        const Spacer(),
                        Text(Fmt.percent(mort, decimals: 1), style: context.text.labelMedium?.copyWith(color: mort > 5 ? AppColors.danger : AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Meter(value: (mort / 10).clamp(0, 1), color: mort > 5 ? AppColors.danger : AppColors.success),
                  ],
                ),
              ),
            ],
          ),
          if (flock.isActive) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (flock.type.laysEggs)
                  Expanded(
                    child: _MiniAction(
                      icon: PhosphorIconsBold.egg,
                      label: today > 0 ? '$today eggs today' : 'Record eggs',
                      color: AppColors.warning,
                      onTap: () => showEggSheet(context, flockId: flock.id),
                    ),
                  ),
                if (flock.type.laysEggs) const SizedBox(width: 10),
                Expanded(
                  child: _MiniAction(
                    icon: PhosphorIconsBold.skull,
                    label: 'Record deaths',
                    color: AppColors.danger,
                    onTap: () => showMortalitySheet(context, flockId: flock.id),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      height: 40,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}
