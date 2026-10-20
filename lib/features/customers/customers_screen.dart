import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _q = '';
  bool _owing = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final list = store.customers.where((c) {
      if (_owing && store.balanceOf(c.id) <= 0) return false;
      if (_q.isEmpty) return true;
      final q = _q.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.phone.contains(q) || c.location.toLowerCase().contains(q);
    }).toList()..sort((a, b) => store.balanceOf(b.id).compareTo(store.balanceOf(a.id)));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCustomerSheet(context),
        icon: const Icon(PhosphorIconsBold.userPlus),
        label: const Text('Add customer'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(title: 'Customers', subtitle: '${store.customers.length} buyers · ${Fmt.money(store.totalOwed)} owed'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: SearchBox(hint: 'Search name, phone or place', onChanged: (v) => setState(() => _q = v.trim())),
              ),
            ),
            SliverToBoxAdapter(
              child: FilterChips<bool>(
                value: _owing,
                onChanged: (v) => setState(() => _owing = v),
                items: [(false, 'All'), (true, 'Owe money (${store.customers.where((c) => store.balanceOf(c.id) > 0).length})')],
              ),
            ),
            if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  image: Assets.tasksDone,
                  title: _owing ? 'Nobody owes you' : 'No customers yet',
                  message: _owing ? 'All sales are fully paid. Great!' : 'Customers are added automatically when you record a sale with a buyer name.',
                  compact: true,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final bal = store.balanceOf(c.id);
                    return AppCard(
                      onTap: () => go(context, CustomerDetailScreen(customerId: c.id)),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Avatar(initials: c.initials, size: 46, color: bal > 0 ? AppColors.pinkDeep : AppColors.forest),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(
                                  [if (c.phone.isNotEmpty) c.phone, if (c.location.isNotEmpty) c.location, '${store.salesOf(c.id).length} sales'].join(' · '),
                                  style: context.text.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                bal > 0 ? Fmt.money(bal) : Fmt.money(store.spentBy(c.id), compact: true),
                                style: context.text.titleSmall?.copyWith(color: bal > 0 ? AppColors.danger : null),
                              ),
                              Text(bal > 0 ? 'owes' : 'total bought', style: context.text.labelSmall),
                            ],
                          ),
                        ],
                      ),
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

Future<void> showCustomerSheet(BuildContext context, {Customer? existing}) => showFormSheet(
  context,
  title: existing == null ? 'Add customer' : 'Edit customer',
  child: _CustomerForm(existing: existing),
);

class _CustomerForm extends StatefulWidget {
  const _CustomerForm({this.existing});
  final Customer? existing;

  @override
  State<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<_CustomerForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _loc = TextEditingController(text: widget.existing?.location ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _loc, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final c =
        widget.existing?.copyWith(name: _name.text.trim(), phone: _phone.text.trim(), location: _loc.text.trim(), notes: _notes.text.trim()) ??
        Customer(
          id: newId(),
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          location: _loc.text.trim(),
          notes: _notes.text.trim(),
          createdAt: DateTime.now(),
        );
    final ok = await guard(() => context.read<FarmStore>().saveCustomer(c), success: 'Customer saved');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      children: [
        AppTextField(
          label: 'Name',
          controller: _name,
          icon: PhosphorIconsRegular.user,
          textCapitalization: TextCapitalization.words,
          validator: (v) => V.name(v, 'Name'),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Phone',
          controller: _phone,
          optional: true,
          icon: PhosphorIconsRegular.phone,
          keyboardType: TextInputType.phone,
          validator: (v) => V.phone(v, optional: true),
        ),
        const SizedBox(height: 16),
        AppTextField(label: 'Location', controller: _loc, optional: true, icon: PhosphorIconsRegular.mapPin, textCapitalization: TextCapitalization.words),
        const SizedBox(height: 16),
        AppTextField(label: 'Notes', controller: _notes, optional: true, hint: 'e.g. buys every Friday'),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Save customer', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
      ],
    ),
  );
}
