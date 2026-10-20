import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/constants/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/auth_controller.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../alerts/alerts_screen.dart';
import '../finance/expenses_screen.dart';
import '../health/health_screen.dart';
import '../inventory/inventory_screen.dart';
import '../pigs/pig_form_screen.dart';
import '../poultry/egg_log_screen.dart';
import '../poultry/flock_form_screen.dart';
import '../poultry/flock_sheets.dart';
import '../sales/sales_widgets.dart';
import '../settings/settings_screen.dart';
import '../shell/main_shell.dart';
import '../tasks/task_sheet.dart';
import '../tasks/tasks_screen.dart';
import 'alert_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final user = context.watch<AuthController>().user;
    if (!store.isOpen) return const Center(child: CircularProgressIndicator());
    final alerts = store.alerts;
    final month = DateRange.thisMonth();
    final revenue = store.revenueIn(month);
    final spent = store.expenseTotalIn(month);
    final today = DateTime.now();
    final tasks = store.tasksFor(today).take(4).toList();
    final shell = ShellScope.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => store.refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(name: user?.firstName ?? 'Farmer', initials: user?.initials ?? '?', farm: store.farm, alertCount: alerts.length),
            ),
            if (store.isEmpty)
              SliverToBoxAdapter(child: _GetStarted(store: store))
            else ...[
              SliverToBoxAdapter(
                child: _BannerCarousel(store: store, alerts: alerts).enter(1),
              ),
              SliverToBoxAdapter(child: _Categories(store: store).enter(2)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: GridView.count(
                    padding: EdgeInsets.zero,
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.32,
                    children: [
                      if (store.farm?.keepsPigs ?? true)
                        StatTile(
                          icon: PhosphorIconsBold.piggyBank,
                          color: AppColors.pinkDeep,
                          value: store.activePigs.length,
                          label: 'Pigs on farm',
                          caption: '${store.sows.length} breeding · ${store.nursingLitters.fold(0, (s, b) => s + (b.bornAlive ?? 0))} nursing',
                          onTap: () => shell?.switchTab(1, subTab: 0),
                        ),
                      if (store.farm?.keepsPoultry ?? true)
                        StatTile(
                          icon: PhosphorIconsBold.bird,
                          color: AppColors.lime,
                          value: store.totalBirds,
                          label: 'Birds alive',
                          caption: '${store.activeFlocks.length} active flocks',
                          onTap: () => shell?.switchTab(1, subTab: 1),
                        ),
                      StatTile(
                        icon: PhosphorIconsBold.egg,
                        color: AppColors.amber,
                        value: store.eggStock / store.eggsPerTray,
                        format: (v) => v.toStringAsFixed(1),
                        label: 'Trays in stock',
                        caption: '${Fmt.number(store.eggsOnDay(today))} eggs today',
                        onTap: () => go(context, const EggLogScreen()),
                      ),
                      StatTile(
                        icon: PhosphorIconsBold.handCoins,
                        color: AppColors.danger,
                        value: store.totalOwed,
                        format: (v) => Fmt.money(v, compact: true),
                        label: 'Customers owe you',
                        caption: '${store.unpaidSales.length} unpaid receipts',
                        onTap: () => shell?.switchTab(2),
                      ),
                    ].indexed.map((e) => e.$2.enter(e.$1 + 3)).toList(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _MoneyCard(revenue: revenue, spent: spent).enter(6),
              ),
              if (alerts.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader('Needs attention', action: 'See all (${alerts.length})', onAction: () => go(context, const AlertsScreen())),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: alerts.length.clamp(0, 3),
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => AlertTile(alert: alerts[i]).enter(i),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: SectionHeader("Today's tasks", action: 'All tasks', onAction: () => go(context, const TasksScreen())),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: tasks.isEmpty
                      ? AppCard(
                          onTap: () => showTaskSheet(context),
                          child: Row(
                            children: [
                              Image.asset(Assets.tasksDone, width: 64, height: 64),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Nothing planned today', style: context.text.titleMedium),
                                    const SizedBox(height: 2),
                                    Text('Tap to add a task or daily chore.', style: context.text.bodySmall),
                                  ],
                                ),
                              ),
                              const Icon(PhosphorIconsBold.plus, size: 20),
                            ],
                          ),
                        )
                      : AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          child: Column(
                            children: [for (final t in tasks) TaskCheckRow(task: t, day: today)],
                          ),
                        ),
                ),
              ),
              if (store.sales.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader('Recent sales', action: 'See all', onAction: () => shell?.switchTab(2)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (final (i, s) in store.sales.take(4).indexed) ...[if (i > 0) const Divider(), SaleRow(sale: s)],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.initials, required this.farm, required this.alertCount});

  final String name;
  final String initials;
  final FarmProfile? farm;
  final int alertCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            Pressable(
              onTap: () => go(context, const SettingsScreen()),
              child: Hero(
                tag: 'avatar',
                child: Avatar(initials: initials, size: 48),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text('${Fmt.greeting()}, $name', style: context.text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        PhosphorIconsFill.handWaving,
                        color: AppColors.amber,
                        size: 20,
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).rotate(begin: -0.05, end: 0.08, duration: 600.ms, alignment: Alignment.bottomRight),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(PhosphorIconsFill.mapPin, size: 13, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${farm?.name ?? 'My farm'}${farm?.location.isNotEmpty == true ? ' · ${farm!.location}' : ''}',
                          style: context.text.bodySmall?.copyWith(color: context.palette.inkSoft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CircleIconButton(icon: PhosphorIconsRegular.bell, tooltip: 'Alerts', badge: alertCount > 0, onTap: () => go(context, const AlertsScreen())),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),
    );
  }
}

class _BannerData {
  const _BannerData(this.image, this.kicker, this.title, this.subtitle, this.cta, this.dark, this.onTap);
  final String image;
  final String kicker;
  final String title;
  final String subtitle;
  final String cta;
  final bool dark;
  final VoidCallback onTap;
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.store, required this.alerts});
  final FarmStore store;
  final List<FarmAlert> alerts;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = ((_controller.page ?? 0).round() + 1) % 3;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final shell = ShellScope.of(context);
    final farrow = widget.alerts.where((a) => a.kind == AlertKind.farrowing).firstOrNull;
    final month = DateRange.thisMonth();
    final profit = s.revenueIn(month) - s.expenseTotalIn(month);
    final eggsToday = s.eggsOnDay(DateTime.now());

    final banners = [
      farrow != null
          ? _BannerData(Assets.bannerFarrowing, 'FARROWING ALERT', farrow.title, farrow.subtitle, 'View alerts', true, () => go(context, const AlertsScreen()))
          : _BannerData(
              Assets.bannerFarrowing,
              'YOUR HERD',
              '${s.activePigs.length} pigs on the farm',
              '${s.openBreedings.length} sows served or pregnant',
              'View pigs',
              true,
              () => shell?.switchTab(1, subTab: 0),
            ),
      _BannerData(
        Assets.bannerEggs,
        'EGGS TODAY',
        eggsToday == 0 ? 'Collect today\'s eggs' : '${Fmt.number(eggsToday)} eggs collected',
        '${(s.eggStock / s.eggsPerTray).toStringAsFixed(1)} trays ready to sell',
        eggsToday == 0 ? 'Record eggs' : 'Egg log',
        false,
        () => eggsToday == 0 ? showEggSheet(context) : go(context, const EggLogScreen()),
      ),
      _BannerData(
        Assets.bannerProfit,
        Fmt.monthYear(DateTime.now()).toUpperCase(),
        '${profit >= 0 ? 'Profit' : 'Loss'} ${Fmt.money(profit.abs(), compact: true)}',
        'Sales ${Fmt.money(s.revenueIn(month), compact: true)} · Costs ${Fmt.money(s.expenseTotalIn(month), compact: true)}',
        'View report',
        true,
        () => shell?.switchTab(3),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _Banner(data: banners[i]),
            ),
          ),
        ),
        SmoothPageIndicator(
          controller: _controller,
          count: banners.length,
          effect: WormEffect(dotHeight: 6, dotWidth: 6, spacing: 6, activeDotColor: Theme.of(context).colorScheme.primary, dotColor: context.palette.border),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.data});
  final _BannerData data;

  @override
  Widget build(BuildContext context) {
    final fg = data.dark ? Colors.white : const Color(0xFF4A3300);
    return Pressable(
      onTap: data.onTap,
      scale: 0.98,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: context.palette.shadow, blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(data.image, fit: BoxFit.cover, alignment: Alignment.centerRight),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (data.dark ? AppColors.forestDark : const Color(0xFFF5B700)).withValues(alpha: 0.92),
                      (data.dark ? AppColors.forestDark : const Color(0xFFF5B700)).withValues(alpha: 0.0),
                    ],
                    stops: const [0.35, 0.75],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 120, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.kicker,
                      style: TextStyle(fontFamily: 'Inter', color: fg.withValues(alpha: 0.8), fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Poppins', color: fg, fontSize: 19, fontWeight: FontWeight.w700, height: 1.15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Inter', color: fg.withValues(alpha: 0.85), fontSize: 12),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: data.dark ? AppColors.amber : AppColors.forestDark, borderRadius: BorderRadius.circular(30)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            data.cta,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: data.dark ? AppColors.forestDeep : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(PhosphorIconsBold.arrowRight, size: 13, color: data.dark ? AppColors.forestDeep : Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.store});
  final FarmStore store;

  @override
  Widget build(BuildContext context) {
    final shell = ShellScope.of(context);
    final farm = store.farm;
    final items = <(String, String, VoidCallback)>[
      if (farm?.keepsPigs ?? true) (Assets.catPigs, 'Pigs', () => shell?.switchTab(1, subTab: 0)),
      for (final b in BirdType.values)
        if (farm?.birdTypes.contains(b) ?? true) (b.image, b.label, () => shell?.switchTab(1, subTab: 1)),
      if (farm?.birdTypes.any((b) => b.laysEggs) ?? true) (Assets.catEggs, 'Eggs', () => go(context, const EggLogScreen())),
      (Assets.catFeed, 'Feed & store', () => go(context, const InventoryScreen())),
      (Assets.catHealth, 'Health', () => go(context, const HealthScreen())),
      (Assets.catSales, 'Expenses', () => go(context, const ExpensesScreen())),
    ];
    return Column(
      children: [
        SectionHeader('Your farm', padding: const EdgeInsets.fromLTRB(20, 20, 12, 8)),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final (img, label, onTap) = items[i];
              return Pressable(
                onTap: onTap,
                scale: 0.92,
                child: SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.palette.card,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: context.palette.shadow, blurRadius: 14, offset: const Offset(0, 5))],
                        ),
                        child: Image.asset(img),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: context.text.labelMedium?.copyWith(color: context.palette.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ).enter(i, dy: 0.3);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.revenue, required this.spent});
  final double revenue;
  final double spent;

  @override
  Widget build(BuildContext context) {
    final profit = revenue - spent;
    final ratio = revenue + spent == 0 ? 0.5 : revenue / (revenue + spent);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: AppCard(
        gradient: AppColors.heroGradient,
        onTap: () => go(context, const ExpensesScreen()),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'This month',
                  style: TextStyle(fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                StatusPill(
                  profit >= 0 ? 'Profit' : 'Loss',
                  color: profit >= 0 ? AppColors.lime : const Color(0xFFFF8A80),
                  icon: profit >= 0 ? PhosphorIconsBold.trendUp : PhosphorIconsBold.trendDown,
                ),
              ],
            ),
            const SizedBox(height: 6),
            CountUp(
              value: profit,
              format: (v) => Fmt.money(v),
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Expanded(
                    flex: (ratio * 1000).round().clamp(1, 999),
                    child: Container(height: 8, color: AppColors.lime),
                  ),
                  Expanded(
                    flex: ((1 - ratio) * 1000).round().clamp(1, 999),
                    child: Container(height: 8, color: AppColors.amber),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [_legend(AppColors.lime, 'Sales', Fmt.money(revenue)), const Spacer(), _legend(AppColors.amber, 'Costs', Fmt.money(spent))]),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color c, String label, String value) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        '$label  ',
        style: TextStyle(fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
      ),
      Text(
        value,
        style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _GetStarted extends StatelessWidget {
  const _GetStarted({required this.store});
  final FarmStore store;

  @override
  Widget build(BuildContext context) {
    final farm = store.farm;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            gradient: AppColors.heroGradient,
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 190,
              child: Stack(
                children: [
                  Positioned(right: -6, bottom: 0, child: Image.asset(Assets.heroFarmer, height: 180)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 150, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Let\'s set up\nyour farm',
                          style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your animals and start recording. It takes a minute.',
                          style: TextStyle(fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).enter(0),
          const SizedBox(height: 20),
          if (farm?.keepsPigs ?? true)
            _StartStep(
              image: Assets.catPigs,
              title: 'Add your first pig',
              subtitle: 'Sows, boars, growers or piglets',
              onTap: () => go(context, const PigFormScreen()),
            ).enter(1),
          if (farm?.keepsPoultry ?? true)
            _StartStep(
              image: Assets.catLayers,
              title: 'Add a flock of birds',
              subtitle: 'Layers, broilers or kienyeji',
              onTap: () => go(context, const FlockFormScreen()),
            ).enter(2),
          _StartStep(
            image: Assets.catFeed,
            title: 'Stock your feed store',
            subtitle: 'Track feed and get low-stock alerts',
            onTap: () => go(context, const InventoryScreen()),
          ).enter(3),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => guard(() => withBusy(context, 'Setting up your sample farm…', store.loadDemoData), success: 'Sample farm loaded. Explore!'),
              icon: const Icon(PhosphorIconsBold.sparkle, size: 18),
              label: const Text('Or load a sample farm to explore'),
            ),
          ).enter(4),
        ],
      ),
    );
  }
}

class _StartStep extends StatelessWidget {
  const _StartStep({required this.image, required this.title, required this.subtitle, required this.onTap});
  final String image;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Image.asset(image, width: 56, height: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: context.text.bodySmall),
              ],
            ),
          ),
          IconTile(icon: PhosphorIconsBold.plus, color: Theme.of(context).colorScheme.primary, size: 36, radius: 12),
        ],
      ),
    ),
  );
}
