import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import 'new_sale_screen.dart';
import 'sale_detail_screen.dart';

/// Celebration after a sale: bouncing pig, confetti and the amount.
class SaleSuccessScreen extends StatefulWidget {
  const SaleSuccessScreen({super.key, required this.saleId});
  final String saleId;

  @override
  State<SaleSuccessScreen> createState() => _SaleSuccessScreenState();
}

class _SaleSuccessScreenState extends State<SaleSuccessScreen> with SingleTickerProviderStateMixin {
  late final _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sale = context.watch<FarmStore>().sale(widget.saleId);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(child: _Confetti(controller: _confetti)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  Image.asset(Assets.successPig, height: 210)
                      .animate()
                      .scale(begin: const Offset(0.3, 0.3), duration: 900.ms, curve: Curves.elasticOut)
                      .then()
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(begin: 0, end: -10, duration: 900.ms, curve: Curves.easeInOut),
                  const SizedBox(height: 28),
                  Text('Sale recorded!', style: context.text.displaySmall).animate(delay: 250.ms).fadeIn().slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 10),
                  if (sale != null) ...[
                    CountUp(
                      value: sale.total,
                      format: (v) => Fmt.money(v),
                      style: context.text.displayMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
                    ).animate(delay: 350.ms).fadeIn(),
                    const SizedBox(height: 8),
                    Text(
                      '${sale.quantityLabel} of ${sale.product.label.toLowerCase()}${sale.customerName.isNotEmpty ? ' to ${sale.customerName}' : ''}',
                      style: context.text.bodyLarge?.copyWith(color: context.palette.inkSoft),
                      textAlign: TextAlign.center,
                    ).animate(delay: 450.ms).fadeIn(),
                    const SizedBox(height: 12),
                    StatusPill(
                      sale.balance > 0 ? '${Fmt.money(sale.balance)} still owed' : 'Fully paid · ${sale.receiptLabel}',
                      color: sale.paymentStatus.color,
                      icon: sale.balance > 0 ? PhosphorIconsBold.clock : PhosphorIconsBold.checkCircle,
                    ).animate(delay: 550.ms).fadeIn().scale(),
                  ],
                  const Spacer(),
                  if (sale != null)
                    PrimaryButton(
                      label: 'View receipt',
                      icon: PhosphorIconsBold.receipt,
                      onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: sale.id))),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const NewSaleScreen())),
                          child: const Text('Another sale'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Confetti extends StatelessWidget {
  const _Confetti({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, _) => CustomPaint(painter: _ConfettiPainter(controller.value)),
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);
  final double t;
  static final _r = Random(7);
  static final _pieces = List.generate(70, (_) => (_r.nextDouble(), _r.nextDouble(), _r.nextDouble(), _r.nextInt(5)));
  static const _colors = [AppColors.lime, AppColors.amber, AppColors.pink, AppColors.forest, AppColors.info];

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final paint = Paint();
    for (final (x, speed, spin, c) in _pieces) {
      final y = -20 + (size.height * 0.9) * t * (0.6 + speed * 0.8);
      final dx = sin((t * 6 + x * 10)) * 18;
      paint.color = _colors[c].withValues(alpha: (1 - t).clamp(0, 1));
      canvas.save();
      canvas.translate(x * size.width + dx, y);
      canvas.rotate(t * 10 * (spin - 0.5));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -7, 8, 14), const Radius.circular(2)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
