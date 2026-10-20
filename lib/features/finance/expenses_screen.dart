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
import 'expense_sheet.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  int _period = 1; // 0 = 7d, 1 = month, 2 = 90d, 3 = year
  ExpenseCategory? _cat;

  DateRange get _range => switch (_period) {
    0 => DateRange.lastDays(7),
    1 => DateRange.thisMonth(),
    2 => DateRange.lastDays(90),
    _ => DateRange.thisYear(),
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final r = _range;
    final byCat = store.expensesByCategory(r);
    final total = byCat.values.fold<double>(0, (a, b) => a + b);
    final revenue = store.revenueIn(r);
    final list = store.expensesIn(r).where((e) => _cat == null || e.category == _cat).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseSheet(context),
        icon: const Icon(PhosphorIconsBold.plus),
        label: const Text('Add expense'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: PageHeader(title: 'Expenses', subtitle: 'Where your money goes'),
            ),
            SliverToBoxAdapter(
              child: FilterChips<int>(
                value: _period,
                onChanged: (v) => setState(() => _period = v),
                items: const [(0, '7 days'), (1, 'This month'), (2, '90 days'), (3, 'This year')],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total spent', style: context.text.bodySmall),
                                CountUp(value: total, format: (v) => Fmt.money(v), style: context.text.headlineMedium),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Sales', style: context.text.bodySmall),
                              Text(Fmt.money(revenue, compact: true), style: context.text.titleMedium?.copyWith(color: AppColors.success)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DonutChart(centerLabel: 'spent', slices: [for (final e in byCat.entries) DonutSlice(e.key.label, e.value, e.key.color)]),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilterChips<ExpenseCategory?>(
                  value: _cat,
                  onChanged: (v) => setState(() => _cat = v),
                  items: [(null, 'All'), for (final c in ExpenseCategory.values.where(byCat.containsKey)) (c, c.label)],
                ),
              ),
            ),
            if (list.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(image: Assets.emptyBasket, title: 'No expenses', message: 'Nothing recorded for this period.', compact: true),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
                sliver: SliverToBoxAdapter(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, e) in list.indexed) ...[
                          if (i > 0) const Divider(),
                          RecordTile(
                            icon: e.category.icon,
                            color: e.category.color,
                            title: e.description,
                            subtitle: '${e.category.label} · ${Fmt.date(e.date)}${e.linkedId != null ? ' · auto' : ''}',
                            trailing: Fmt.money(e.amount),
                            onTap: () => showExpenseSheet(context, existing: e),
                            onLongPress: () async {
                              if (await confirm(context, title: 'Delete expense?', message: '${Fmt.money(e.amount)} · ${e.description}')) {
                                await guard(() => store.deleteExpense(e.id), success: 'Deleted');
                              }
                            },
                          ),
                        ],
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
