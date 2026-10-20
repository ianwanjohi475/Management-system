import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../finance/expense_sheet.dart';
import '../health/health_form_screen.dart';
import '../inventory/stock_sheets.dart';
import '../pigs/pig_form_screen.dart';
import '../pigs/pig_sheets.dart';
import '../poultry/flock_form_screen.dart';
import '../poultry/flock_sheets.dart';
import '../sales/new_sale_screen.dart';
import '../tasks/task_sheet.dart';

class _Action {
  const _Action(this.icon, this.label, this.color, this.run, {this.image});
  final IconData icon;
  final String? image;
  final String label;
  final Color color;
  final void Function(BuildContext) run;
}

/// The "+" button menu: every common record in one tap.
Future<void> showQuickAdd(BuildContext context) {
  final farm = context.read<FarmStore>().farm;
  final pigs = farm?.keepsPigs ?? true;
  final birds = farm?.keepsPoultry ?? true;
  final layers = farm?.birdTypes.any((b) => b.laysEggs) ?? true;

  final actions = <_Action>[
    _Action(PhosphorIconsBold.receipt, 'New sale', AppColors.forest, (c) => go(c, const NewSaleScreen())),
    if (layers) _Action(PhosphorIconsBold.egg, 'Collect eggs', AppColors.amber, (c) => showEggSheet(c)),
    if (pigs) _Action(PhosphorIconsBold.pawPrint, 'Add pig', AppColors.pinkDeep, (c) => go(c, const PigFormScreen()), image: Assets.pig),
    if (birds) _Action(PhosphorIconsBold.pawPrint, 'New flock', AppColors.lime, (c) => go(c, const FlockFormScreen()), image: Assets.hen),
    if (pigs) _Action(PhosphorIconsBold.scales, 'Weigh pig', AppColors.info, (c) => showWeightSheet(c)),
    if (pigs) _Action(PhosphorIconsBold.heart, 'Pig service', AppColors.pink, (c) => showServiceSheet(c)),
    if (birds) _Action(PhosphorIconsBold.skull, 'Bird deaths', AppColors.danger, (c) => showMortalitySheet(c)),
    _Action(PhosphorIconsBold.syringe, 'Health', AppColors.info, (c) => go(c, const HealthFormScreen())),
    _Action(PhosphorIconsBold.grains, 'Feed used', AppColors.warning, (c) => showStockOutSheet(c)),
    _Action(PhosphorIconsBold.package, 'Buy stock', AppColors.forest, (c) => showStockInSheet(c)),
    _Action(PhosphorIconsBold.wallet, 'Expense', AppColors.pinkDeep, (c) => showExpenseSheet(c)),
    _Action(PhosphorIconsBold.checkSquare, 'Task', AppColors.inkSoft, (c) => showTaskSheet(c)),
  ];

  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick add', style: sheet.text.headlineSmall),
          const SizedBox(height: 4),
          Text('What happened on the farm?', style: sheet.text.bodyMedium),
          const SizedBox(height: 20),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 18, crossAxisSpacing: 8, childAspectRatio: 0.82),
            itemBuilder: (_, i) {
              final a = actions[i];
              return Pressable(
                onTap: () {
                  Navigator.pop(sheet);
                  a.run(context);
                },
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: a.color.withValues(alpha: sheet.isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: a.image != null ? Padding(padding: const EdgeInsets.all(7), child: Image.asset(a.image!)) : Icon(a.icon, color: a.color, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      a.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: sheet.text.labelMedium?.copyWith(color: sheet.palette.ink, fontSize: 12),
                    ),
                  ],
                ),
              ).enter(i, dy: 0.25);
            },
          ),
        ],
      ),
    ),
  );
}
