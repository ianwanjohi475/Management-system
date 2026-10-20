import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/formatters.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../sales/new_sale_screen.dart';
import '../sales/sales_widgets.dart';
import '../system/not_found_screen.dart';
import 'customers_screen.dart';

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final c = store.customer(customerId);
    if (c == null) return const NotFoundScreen(message: 'This customer was deleted.');
    final sales = store.salesOf(c.id);
    final owed = store.balanceOf(c.id);
    final spent = store.spentBy(c.id);
    final farmName = store.farm?.name ?? 'your farm';
    final reminder = 'Hello ${c.name}, this is $farmName. A friendly reminder that your balance is ${Fmt.money(owed)}. Thank you!';

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: '',
                actions: [
                  CircleIconButton(
                    icon: PhosphorIconsBold.pencilSimple,
                    tooltip: 'Edit',
                    onTap: () => showCustomerSheet(context, existing: c),
                  ),
                  CircleIconButton(
                    icon: PhosphorIconsBold.trash,
                    tooltip: 'Delete',
                    color: AppColors.danger,
                    onTap: () async {
                      if (await confirm(context, title: 'Delete ${c.name}?', message: 'Their past receipts are kept.')) {
                        final ok = await guard(() => store.deleteCustomer(c.id), success: 'Customer deleted');
                        if (ok && context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Avatar(initials: c.initials, size: 84, color: owed > 0 ? AppColors.pinkDeep : AppColors.forest).enter(0),
                  const SizedBox(height: 12),
                  Text(c.name, style: context.text.displaySmall, textAlign: TextAlign.center).enter(1),
                  if (c.phone.isNotEmpty || c.location.isNotEmpty)
                    Text([c.phone, c.location].where((e) => e.isNotEmpty).join(' · '), style: context.text.bodyMedium).enter(2),
                  const SizedBox(height: 18),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: PhosphorIconsBold.shoppingBag,
                        color: AppColors.forest,
                        value: spent,
                        format: (v) => Fmt.money(v, compact: true),
                        label: 'Total bought',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        icon: PhosphorIconsBold.handCoins,
                        color: owed > 0 ? AppColors.danger : AppColors.success,
                        value: owed,
                        format: (v) => Fmt.money(v, compact: true),
                        label: 'Owes you',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(icon: PhosphorIconsBold.receipt, color: AppColors.info, value: sales.length, label: 'Receipts'),
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
                    if (c.phone.isNotEmpty) ...[
                      Expanded(
                        child: _Act(icon: PhosphorIconsBold.phone, label: 'Call', onTap: () => guard(() => callPhone(c.phone), haptic: false)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Act(
                          icon: PhosphorIconsBold.whatsappLogo,
                          label: owed > 0 ? 'Remind' : 'WhatsApp',
                          onTap: () => guard(() => sendWhatsApp(c.phone, owed > 0 ? reminder : 'Hello ${c.name}'), haptic: false),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: _Act(
                        icon: PhosphorIconsBold.plus,
                        label: 'New sale',
                        primary: true,
                        onTap: () => go(context, NewSaleScreen(customerId: c.id)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (c.notes.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: AppCard(
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsRegular.note, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(c.notes, style: context.text.bodyMedium)),
                      ],
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SectionHeader('Purchase history')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverToBoxAdapter(
                child: sales.isEmpty
                    ? AppCard(child: Text('No sales to this customer yet.', style: context.text.bodyMedium))
                    : AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        child: Column(
                          children: [
                            for (final (i, s) in sales.indexed) ...[if (i > 0) const Divider(), SaleRow(sale: s)],
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

class _Act extends StatelessWidget {
  const _Act({required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: primary ? scheme.primary : context.palette.brandTint, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: primary ? scheme.onPrimary : scheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: context.text.labelMedium?.copyWith(color: primary ? scheme.onPrimary : scheme.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
