import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../widgets/widgets.dart';
import 'sale_detail_screen.dart';

/// One sale in a list: product image, buyer, amount and payment status.
class SaleRow extends StatelessWidget {
  const SaleRow({super.key, required this.sale, this.showDate = true});
  final Sale sale;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final s = sale;
    return Pressable(
      onTap: () => go(context, SaleDetailScreen(saleId: s.id)),
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: s.product.color.withValues(alpha: context.isDark ? 0.18 : 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Image.asset(s.product.image),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.quantityLabel} · ${s.product.label}', style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    [if (s.customerName.isNotEmpty) s.customerName else 'Walk-in buyer', if (showDate) Fmt.relativeDay(s.date)].join(' · '),
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.money(s.total), style: context.text.titleSmall),
                const SizedBox(height: 4),
                StatusPill(s.paymentStatus.label, color: s.paymentStatus.color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
