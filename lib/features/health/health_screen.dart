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
import 'health_form_screen.dart';
import 'health_widgets.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  TargetType? _filter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final all = store.healthRecords.where((h) => _filter == null || h.targetType == _filter).toList();
    final due = all.where((h) => h.hasOpenFollowUp).toList()..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));
    final spent = store.expensesByCategory(DateRange.thisMonth())[ExpenseCategory.vet] ?? 0;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => go(context, const HealthFormScreen()),
        icon: const Icon(PhosphorIconsBold.plus),
        label: const Text('Add record'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: PageHeader(title: 'Health', subtitle: 'Vaccinations, treatments and reminders'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: AppCard(
                  color: AppColors.infoSoft.withValues(alpha: context.isDark ? 0.1 : 1),
                  border: false,
                  shadow: false,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Image.asset(Assets.catHealth, width: 64),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${due.length} upcoming ${due.length == 1 ? 'dose' : 'doses'}', style: context.text.titleLarge),
                            const SizedBox(height: 2),
                            Text(
                              '${due.where((h) => dateOnly(h.nextDue!).isBefore(dateOnly(DateTime.now()))).length} overdue · ${Fmt.money(spent)} spent this month',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilterChips<TargetType?>(
                  value: _filter,
                  onChanged: (v) => setState(() => _filter = v),
                  items: const [(null, 'All'), (TargetType.flock, 'Poultry'), (TargetType.pig, 'Pigs')],
                ),
              ),
            ),
            if (due.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader('Coming up')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: due.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => DueCard(record: due[i]).enter(i),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SectionHeader('History')),
            if (all.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  image: Assets.catHealth,
                  title: 'No health records',
                  message: 'Record vaccinations and treatments to get reminders for the next dose.',
                  compact: true,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverToBoxAdapter(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, h) in all.indexed) ...[if (i > 0) const Divider(), HealthTile(record: h)],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
