import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../health/health_screen.dart';
import '../inventory/item_detail_screen.dart';
import '../pigs/pig_detail_screen.dart';
import '../sales/sale_detail_screen.dart';
import '../tasks/tasks_screen.dart';

/// Opens the record an alert is about.
void openAlert(BuildContext context, FarmAlert a) {
  final id = a.targetId;
  switch (a.kind) {
    case AlertKind.farrowing:
    case AlertKind.heatCheck:
    case AlertKind.weaning:
      if (id != null) go(context, PigDetailScreen(pigId: id));
    case AlertKind.healthDue:
      go(context, const HealthScreen());
    case AlertKind.lowStock:
    case AlertKind.expiry:
      if (id != null) go(context, ItemDetailScreen(itemId: id));
    case AlertKind.debt:
      if (id != null) go(context, SaleDetailScreen(saleId: id));
    case AlertKind.task:
      go(context, const TasksScreen());
  }
}

class AlertTile extends StatelessWidget {
  const AlertTile({super.key, required this.alert, this.dismissible = true});
  final FarmAlert alert;
  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    final card = AppCard(
      onTap: () => openAlert(context, alert),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconTile(icon: alert.icon, color: alert.color, size: 46),
              if (alert.severity == AlertSeverity.urgent)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.palette.card, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(alert.subtitle, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(PhosphorIconsBold.caretRight, size: 16, color: context.palette.inkMuted),
        ],
      ),
    );
    if (!dismissible) return card;
    return Dismissible(
      key: ValueKey(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: AppColors.forest.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dismiss', style: context.text.labelMedium?.copyWith(color: AppColors.forest)),
            const SizedBox(width: 6),
            const Icon(PhosphorIconsBold.checkCircle, color: AppColors.forest),
          ],
        ),
      ),
      onDismissed: (_) => guard(() => context.read<FarmStore>().dismissAlert(alert.id), success: 'Alert dismissed'),
      child: card,
    );
  }
}
