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
import 'item_detail_screen.dart';
import 'stock_sheets.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  ItemCategory? _cat;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final items = store.items.where((i) => _cat == null || i.category == _cat).toList();
    final low = store.lowStockItems.length;
    final feedWeek = store.feedUsedIn(DateRange.lastDays(7));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showItemSheet(context),
        icon: const Icon(PhosphorIconsBold.plus),
        label: const Text('New item'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: PageHeader(title: 'Feed & store', subtitle: 'Feed, medicine and supplies'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: PhosphorIconsBold.warning,
                        color: low > 0 ? AppColors.danger : AppColors.success,
                        value: low,
                        label: low == 1 ? 'Item running low' : 'Items running low',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        icon: PhosphorIconsBold.grains,
                        color: AppColors.amber,
                        value: feedWeek,
                        format: (v) => Fmt.kg(v.round()),
                        label: 'Feed used (7 days)',
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
                      child: OutlinedButton.icon(
                        onPressed: () => showStockInSheet(context),
                        icon: const Icon(PhosphorIconsBold.arrowDown, size: 18),
                        label: const Text('Buy stock'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showStockOutSheet(context),
                        icon: const Icon(PhosphorIconsBold.arrowUp, size: 18),
                        label: const Text('Use stock'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilterChips<ItemCategory?>(
                  value: _cat,
                  onChanged: (v) => setState(() => _cat = v),
                  items: [(null, 'All'), for (final c in ItemCategory.values) (c, c.label)],
                ),
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  image: Assets.catFeed,
                  title: 'Your store is empty',
                  message: 'Add feed and medicine to track usage and get alerts before you run out.',
                  actionLabel: 'Add item',
                  onAction: () => showItemSheet(context),
                  compact: true,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ItemCard(item: items[i]).enter(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});
  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final have = store.stockOf(item.id);
    final low = store.isLow(item);
    final left = store.daysLeft(item.id);
    final ref = item.lowStockLevel <= 0 ? (have <= 0 ? 1.0 : have) : item.lowStockLevel * 4;
    final color = have <= 0 ? AppColors.danger : (low ? AppColors.warning : AppColors.success);
    return AppCard(
      onTap: () => go(context, ItemDetailScreen(itemId: item.id)),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(icon: item.category.icon, color: item.category.color, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      [
                        item.category.label,
                        if (left != null) '~$left days left',
                        if (item.isExpired) 'Expired' else if (item.expiresSoon) 'Expires soon',
                      ].join(' · '),
                      style: context.text.bodySmall?.copyWith(color: item.isExpired ? AppColors.danger : null),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${Fmt.number(have, decimals: have % 1 == 0 ? 0 : 1)} ${item.unit}',
                    style: context.text.titleMedium?.copyWith(color: color),
                  ),
                  if (low) StatusPill(have <= 0 ? 'Out' : 'Low', color: color),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Meter(value: ref == 0 ? 0 : (have / ref).clamp(0, 1).toDouble(), color: color),
        ],
      ),
    );
  }
}
