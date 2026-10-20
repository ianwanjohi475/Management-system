import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';

Future<void> showExpenseSheet(BuildContext context, {Expense? existing}) => showFormSheet(
  context,
  title: existing == null ? 'Add expense' : 'Edit expense',
  subtitle: 'Feed and vet costs from stock and health records are added automatically.',
  child: _ExpenseForm(existing: existing),
);

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({this.existing});
  final Expense? existing;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _form = GlobalKey<FormState>();
  late ExpenseCategory _cat = widget.existing?.category ?? ExpenseCategory.feed;
  late final _amount = TextEditingController(text: widget.existing?.amount.toStringAsFixed(0) ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late PaymentMethod _method = widget.existing?.method ?? PaymentMethod.cash;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final e = Expense(
      id: widget.existing?.id ?? newId(),
      date: _date,
      category: _cat,
      amount: V.parse(_amount.text)!.toDouble(),
      description: _desc.text.trim(),
      method: _method,
      linkedId: widget.existing?.linkedId,
    );
    final ok = await guard(() => context.read<FarmStore>().saveExpense(e), success: '${Fmt.money(e.amount)} expense saved');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Category'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in ExpenseCategory.values)
              Pressable(
                onTap: () => setState(() => _cat = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: _cat == c ? c.color : c.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c.icon, size: 15, color: _cat == c ? Colors.white : c.color),
                      const SizedBox(width: 6),
                      Text(c.label, style: context.text.labelMedium?.copyWith(color: _cat == c ? Colors.white : c.color)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Amount',
                controller: _amount,
                prefixText: '${Fmt.currency} ',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: AppTextField.decimal,
                validator: (v) => V.number(v, field: 'Amount', max: 100000000),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DateField(label: 'Date', value: _date, lastDate: DateTime.now(), onChanged: (d) => setState(() => _date = d ?? DateTime.now())),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(label: 'What was it for?', controller: _desc, hint: 'e.g. 2 bags of layers mash', validator: (v) => V.required(v, 'Description')),
        const SizedBox(height: 16),
        ChoicePills<PaymentMethod>(
          label: 'Paid with',
          value: _method,
          onChanged: (m) => setState(() => _method = m),
          options: [for (final m in PaymentMethod.values.where((m) => m != PaymentMethod.credit)) PickerOption(m, m.label, icon: m.icon)],
        ),
        if (widget.existing?.linkedId != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.link, size: 14, color: AppColors.info),
                const SizedBox(width: 6),
                Expanded(child: Text('Linked to a stock or health record.', style: context.text.bodySmall)),
              ],
            ),
          ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Save expense', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
      ],
    ),
  );
}
