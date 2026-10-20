import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../system/not_found_screen.dart';
import 'stock_sheets.dart';

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final it = store.item(itemId);
    if (it == null) return const NotFoundScreen(message: 'This item was deleted.');
    final have = store.stockOf(it.id);
    final moves = store.movementsOf(it.id);
    final use = store.dailyUse(it.id);
    final left = store.daysLeft(it.id);
    String q(double v) => '${Fmt.number(v, decimals: v % 1 == 0 ? 0 : 1)} ${it.unit}';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: it.name,
              subtitle: it.category.label,
              actions: [
                CircleIconButton(
                  icon: PhosphorIconsBold.pencilSimple,
                  tooltip: 'Edit',
                  onTap: () => showItemSheet(context, existing: it),
                ),
                CircleIconButton(
                  icon: PhosphorIconsBold.trash,
                  color: AppColors.danger,
                  tooltip: 'Delete',
                  onTap: () async {
                    if (await confirm(
                      context,
                      title: 'Delete ${it.name}?',
                      message: 'Its stock history will be removed. Linked expenses stay in your records.',
                    )) {
                      final ok = await guard(() => store.deleteItem(it.id), success: 'Item deleted');
                      if (ok && context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  AppCard(
                    gradient: AppColors.heroGradient,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'In store',
                                style: TextStyle(fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              CountUp(
                                value: have,
                                format: (v) => q(v.toDouble()),
                                style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                left != null ? 'Lasts about $left days at ${q(use)}/day' : 'Alert below ${q(it.lowStockLevel)}',
                                style: TextStyle(fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                          child: Icon(it.category.icon, color: Colors.white, size: 30),
                        ),
                      ],
                    ),
                  ).enter(0),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Buy',
                          icon: PhosphorIconsBold.arrowDown,
                          height: 50,
                          onPressed: () => showStockInSheet(context, itemId: it.id),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Use',
                          icon: PhosphorIconsBold.arrowUp,
                          height: 50,
                          color: AppColors.warning,
                          onPressed: () => showStockOutSheet(context, itemId: it.id),
                        ),
                      ),
                    ],
                  ).enter(1),
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      children: [
                        InfoRow(label: 'Low-stock alert', value: q(it.lowStockLevel), icon: PhosphorIconsRegular.bellRinging),
                        if (it.unitCost != null)
                          InfoRow(label: 'Last cost', value: '${Fmt.money(it.unitCost!)} / ${it.unit}', icon: PhosphorIconsRegular.money),
                        if (it.supplier.isNotEmpty) InfoRow(label: 'Supplier', value: it.supplier, icon: PhosphorIconsRegular.storefront),
                        if (it.expiryDate != null)
                          InfoRow(
                            label: 'Expiry',
                            value: Fmt.date(it.expiryDate!),
                            icon: PhosphorIconsRegular.hourglass,
                            valueColor: it.isExpired ? AppColors.danger : null,
                          ),
                      ],
                    ),
                  ),
                  const SectionHeader('History', padding: EdgeInsets.fromLTRB(0, 24, 0, 10)),
                  if (moves.isEmpty)
                    AppCard(child: Text('No stock movements yet.', style: context.text.bodyMedium))
                  else
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (final (i, m) in moves.take(40).indexed) ...[
                            if (i > 0) const Divider(),
                            RecordTile(
                              icon: m.type == MovementType.stockIn ? PhosphorIconsBold.arrowDown : PhosphorIconsBold.arrowUp,
                              color: m.type == MovementType.stockIn ? AppColors.success : AppColors.warning,
                              title: m.type == MovementType.stockIn ? 'Bought ${q(m.quantity)}' : 'Used ${q(m.quantity)}',
                              subtitle: [
                                Fmt.date(m.date),
                                if (m.targetId != null && m.targetType != null) store.targetName(m.targetType!, m.targetId!),
                                if (m.notes.isNotEmpty) m.notes,
                              ].join(' · '),
                              trailing: m.totalCost != null && m.totalCost! > 0 ? Fmt.money(m.totalCost!) : null,
                              onLongPress: () async {
                                if (await confirm(
                                  context,
                                  title: 'Delete this entry?',
                                  message: m.expenseId != null ? 'The linked expense will also be removed.' : 'Stock will be adjusted.',
                                )) {
                                  await guard(() => store.deleteMovement(m.id), success: 'Deleted');
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
