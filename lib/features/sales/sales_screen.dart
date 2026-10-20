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
import '../customers/customers_screen.dart';
import 'new_sale_screen.dart';
import 'sales_widgets.dart';

enum _Period { today, week, month, all }

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  _Period _period = _Period.month;
  Product? _product;
  bool _unpaid = false;
  String _q = '';

  DateRange get _range => switch (_period) {
    _Period.today => DateRange.lastDays(1),
    _Period.week => DateRange.lastDays(7),
    _Period.month => DateRange.thisMonth(),
    _Period.all => DateRange.allTime(),
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final range = _range;
    final inRange = store.salesIn(range);
    final sales = inRange.where((s) {
      if (_product != null && s.product != _product) return false;
      if (_unpaid && s.balance <= 0) return false;
      if (_q.isNotEmpty) {
        final q = _q.toLowerCase();
        return s.customerName.toLowerCase().contains(q) || s.receiptLabel.toLowerCase().contains(q) || s.product.label.toLowerCase().contains(q);
      }
      return true;
    }).toList();
    final revenue = inRange.fold<double>(0, (a, s) => a + s.total);
    final collected = inRange.fold<double>(0, (a, s) => a + s.paid);

    // Group by day for section headers.
    final groups = <DateTime, List<Sale>>{};
    for (final s in sales) {
      groups.putIfAbsent(dateOnly(s.date), () => []).add(s);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

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
                    Expanded(child: Text('Sales', style: context.text.displaySmall)),
                    CircleIconButton(icon: PhosphorIconsBold.usersThree, tooltip: 'Customers', onTap: () => go(context, const CustomersScreen())),
                    const SizedBox(width: 8),
                    CircleIconButton(
                      icon: PhosphorIconsBold.plus,
                      tooltip: 'New sale',
                      background: Theme.of(context).colorScheme.primary,
                      color: Theme.of(context).colorScheme.onPrimary,
                      onTap: () => go(context, const NewSaleScreen()),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: MoneySummary(
                  title: switch (_period) {
                    _Period.today => 'Sales today',
                    _Period.week => 'Sales · last 7 days',
                    _Period.month => 'Sales in ${Fmt.monthYear(DateTime.now())}',
                    _Period.all => 'All-time sales',
                  },
                  amount: revenue,
                  badge: '${inRange.length} receipts',
                  stats: [
                    SummaryStat('Collected', Fmt.money(collected, compact: true), AppColors.lime),
                    SummaryStat('Still owed', Fmt.money(store.totalOwed, compact: true), AppColors.amber),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilterChips<_Period>(
                  value: _period,
                  onChanged: (v) => setState(() => _period = v),
                  items: const [(_Period.today, 'Today'), (_Period.week, '7 days'), (_Period.month, 'This month'), (_Period.all, 'All time')],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  children: [
                    for (final p in Product.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Pressable(
                          onTap: () => setState(() => _product = _product == p ? null : p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 80,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _product == p ? context.palette.brandTint : context.palette.card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _product == p ? Theme.of(context).colorScheme.primary : context.palette.border,
                                width: _product == p ? 1.6 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Expanded(child: Image.asset(p.image)),
                                const SizedBox(height: 4),
                                Text(
                                  p.short,
                                  style: context.text.labelSmall?.copyWith(color: context.palette.ink),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: SearchBox(hint: 'Search buyer or receipt', onChanged: (v) => setState(() => _q = v.trim())),
                    ),
                    const SizedBox(width: 10),
                    Pressable(
                      onTap: () => setState(() => _unpaid = !_unpaid),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: _unpaid ? AppColors.danger : context.palette.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _unpaid ? AppColors.danger : context.palette.border),
                        ),
                        child: Row(
                          children: [
                            Icon(PhosphorIconsBold.clock, size: 18, color: _unpaid ? Colors.white : AppColors.danger),
                            const SizedBox(width: 6),
                            Text('Unpaid', style: context.text.labelMedium?.copyWith(color: _unpaid ? Colors.white : AppColors.danger)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (sales.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  image: Assets.emptyBasket,
                  title: store.sales.isEmpty ? 'No sales yet' : 'Nothing here',
                  message: store.sales.isEmpty ? 'Record your first sale of eggs, chicken or pigs.' : 'No sales match these filters.',
                  actionLabel: store.sales.isEmpty ? 'New sale' : null,
                  onAction: () => go(context, const NewSaleScreen()),
                  compact: true,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                sliver: SliverList.builder(
                  itemCount: days.length,
                  itemBuilder: (_, i) {
                    final d = days[i];
                    final list = groups[d]!;
                    final total = list.fold<double>(0, (a, s) => a + s.total);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                          child: Row(
                            children: [
                              Text(
                                Fmt.relativeDay(d) == Fmt.dateShort(d) ? Fmt.dayMonth(d) : '${Fmt.relativeDay(d)}, ${Fmt.dateShort(d)}',
                                style: context.text.titleSmall,
                              ),
                              const Spacer(),
                              Text(Fmt.money(total), style: context.text.labelMedium),
                            ],
                          ),
                        ),
                        AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          child: Column(
                            children: [
                              for (final (j, s) in list.indexed) ...[if (j > 0) const Divider(), SaleRow(sale: s, showDate: false)],
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
