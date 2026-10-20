import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/phosphor.dart';
import '../core/utils/formatters.dart';
import 'buttons.dart';
import 'cards.dart';

/// One figure in the stat row of a [MoneySummary].
class SummaryStat {
  const SummaryStat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
}

/// The money hero card: title, big amount, optional sales-vs-costs bar and a divided stat row.
class MoneySummary extends StatelessWidget {
  const MoneySummary({super.key, required this.title, required this.amount, required this.stats, this.badge, this.signed = false, this.split, this.onTap});

  final String title;
  final double amount;
  final List<SummaryStat> stats;

  /// Small note on the right, e.g. "56% margin".
  final String? badge;

  /// Profit/loss mode: colours the amount and badge by sign.
  final bool signed;

  /// Sales and costs, drawn as one split bar.
  final (double, double)? split;
  final VoidCallback? onTap;

  static const _good = Color(0xFFB9CDA6);
  static const _bad = Color(0xFFF2967C);

  @override
  Widget build(BuildContext context) {
    final negative = signed && amount < 0;
    final tone = !signed ? Colors.white : (negative ? _bad : _good);
    final card = Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.forestDeep,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.forestDeep.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.65), fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              if (badge != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (signed) Icon(negative ? PhosphorIconsBold.trendDown : PhosphorIconsBold.trendUp, size: 14, color: tone),
                    if (signed) const SizedBox(width: 4),
                    Text(
                      badge!,
                      style: TextStyle(fontFamily: 'Inter', color: signed ? tone : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          CountUp(
            value: amount.abs(),
            format: (v) => '${negative ? '−' : ''}${Fmt.money(v)}',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: signed ? tone : Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ),
          if (split != null) ...[const SizedBox(height: 16), _SplitBar(a: split!.$1, b: split!.$2)],
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) VerticalDivider(width: 24, thickness: 1, color: Colors.white.withValues(alpha: 0.12)),
                  Expanded(child: _Stat(stat: stats[i])),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: 0.98, child: card);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.stat});
  final SummaryStat stat;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: stat.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              stat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.6), fontSize: 11.5),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          stat.value,
          style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.a, required this.b});
  final double a;
  final double b;

  @override
  Widget build(BuildContext context) {
    final total = a + b;
    final ratio = total <= 0 ? 0.5 : a / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            Expanded(
              flex: (ratio * 1000).round().clamp(1, 999),
              child: Container(color: AppColors.lime),
            ),
            const SizedBox(width: 3),
            Expanded(
              flex: ((1 - ratio) * 1000).round().clamp(1, 999),
              child: Container(color: AppColors.terracottaLight),
            ),
          ],
        ),
      ),
    );
  }
}
