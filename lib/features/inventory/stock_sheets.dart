import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../poultry/flock_sheets.dart';

List<PickerOption<String>> _itemOptions(FarmStore store, {ItemCategory? only}) => [
  for (final i in store.items.where((i) => only == null || i.category == only))
    PickerOption(i.id, i.name, subtitle: '${Fmt.number(store.stockOf(i.id), decimals: 1)} ${i.unit} in store', icon: i.category.icon, color: i.category.color),
];

// ───────────────────────── Item ─────────────────────────

Future<void> showItemSheet(BuildContext context, {InventoryItem? existing}) => showFormSheet(
  context,
  title: existing == null ? 'New store item' : 'Edit item',
  child: _ItemForm(existing: existing),
);

class _ItemForm extends StatefulWidget {
  const _ItemForm({this.existing});
  final InventoryItem? existing;

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  final _form = GlobalKey<FormState>();
  late final InventoryItem? _e = widget.existing;
  late ItemCategory _cat = _e?.category ?? ItemCategory.feed;
  late String _unit = _e?.unit ?? 'kg';
  late final _name = TextEditingController(text: _e?.name ?? '');
  late final _low = TextEditingController(text: _e == null ? '' : Fmt.number(_e.lowStockLevel, decimals: _e.lowStockLevel % 1 == 0 ? 0 : 1));
  final _opening = TextEditingController();
  late final _supplier = TextEditingController(text: _e?.supplier ?? '');
  late DateTime? _expiry = _e?.expiryDate;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _low, _opening, _supplier]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final item = InventoryItem(
      id: _e?.id ?? newId(),
      name: _name.text.trim(),
      category: _cat,
      unit: _unit,
      lowStockLevel: V.parse(_low.text)?.toDouble() ?? 0,
      unitCost: _e?.unitCost,
      expiryDate: _expiry,
      supplier: _supplier.text.trim(),
      createdAt: _e?.createdAt ?? DateTime.now(),
    );
    final ok = await guard(
      () => context.read<FarmStore>().saveItem(item, openingStock: V.parse(_opening.text)?.toDouble() ?? 0),
      success: '${item.name} saved',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      children: [
        ChoicePills<ItemCategory>(
          value: _cat,
          expand: false,
          onChanged: (c) => setState(() => _cat = c),
          options: [for (final c in ItemCategory.values) PickerOption(c, c.label, icon: c.icon, color: c.color)],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Item name',
          controller: _name,
          hint: 'e.g. Layers Mash',
          icon: PhosphorIconsRegular.package,
          textCapitalization: TextCapitalization.words,
          validator: (v) => V.name(v, 'Item name'),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SelectField<String>(
                label: 'Unit',
                value: _unit,
                icon: PhosphorIconsRegular.ruler,
                options: [for (final u in stockUnits) PickerOption(u, u)],
                onChanged: (u) => setState(() => _unit = u),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'Alert below',
                controller: _low,
                suffixText: _unit,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: AppTextField.decimal,
                validator: (v) => V.number(v, field: 'Level', optional: true, allowZero: true),
              ),
            ),
          ],
        ),
        if (_e == null) ...[
          const SizedBox(height: 16),
          AppTextField(
            label: 'Stock you have now',
            controller: _opening,
            optional: true,
            suffixText: _unit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: AppTextField.decimal,
            validator: (v) => V.number(v, field: 'Stock', optional: true, allowZero: true),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(label: 'Supplier', controller: _supplier, optional: true, textCapitalization: TextCapitalization.words),
            ),
            if (_cat != ItemCategory.feed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: DateField(label: 'Expiry', value: _expiry, optional: true, hint: 'None', onChanged: (d) => setState(() => _expiry = d)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Save item', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
      ],
    ),
  );
}

// ───────────────────────── Stock in (purchase) ─────────────────────────

Future<void> showStockInSheet(BuildContext context, {String? itemId}) {
  if (context.read<FarmStore>().items.isEmpty) {
    return showItemSheet(context).then((_) => showToast('Item added. Use "Buy stock" next time to restock.', type: ToastType.info));
  }
  return showFormSheet(
    context,
    title: 'Buy stock',
    subtitle: 'Adds to your store and records the expense.',
    child: _StockInForm(itemId: itemId),
  );
}

class _StockInForm extends StatefulWidget {
  const _StockInForm({this.itemId});
  final String? itemId;

  @override
  State<_StockInForm> createState() => _StockInFormState();
}

class _StockInFormState extends State<_StockInForm> {
  final _form = GlobalKey<FormState>();
  late String? _item = widget.itemId;
  final _qty = TextEditingController();
  final _cost = TextEditingController();
  DateTime _date = DateTime.now();
  bool _expense = true;
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await guard(
      () => context.read<FarmStore>().stockIn(_item!, _date, V.parse(_qty.text)!.toDouble(), V.parse(_cost.text)?.toDouble(), recordExpense: _expense),
      success: 'Stock added',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final it = store.item(_item);
    return Form(
      key: _form,
      child: Column(
        children: [
          SelectField<String>(
            label: 'Item',
            value: _item,
            icon: PhosphorIconsRegular.package,
            options: _itemOptions(store),
            onChanged: (v) => setState(() => _item = v),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Quantity',
                  controller: _qty,
                  suffixText: it?.unit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: AppTextField.decimal,
                  validator: (v) => V.number(v, field: 'Quantity', max: 1000000),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Total cost',
                  controller: _cost,
                  optional: true,
                  prefixText: '${Fmt.currency} ',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: AppTextField.decimal,
                  validator: (v) => V.number(v, field: 'Cost', optional: true, allowZero: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DateField(label: 'Date', value: _date, lastDate: DateTime.now(), onChanged: (d) => setState(() => _date = d ?? DateTime.now())),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _expense,
            onChanged: (v) => setState(() => _expense = v),
            title: Text('Add cost to expenses', style: context.text.titleSmall),
          ),
          const SizedBox(height: 12),
          PrimaryButton(label: 'Add to store', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}

// ───────────────────────── Stock out (usage) ─────────────────────────

Future<void> showStockOutSheet(BuildContext context, {String? itemId}) {
  if (context.read<FarmStore>().items.isEmpty) {
    showToast('Add feed to your store first.', type: ToastType.info);
    return showItemSheet(context);
  }
  return showFormSheet(
    context,
    title: 'Record usage',
    subtitle: 'Feed or medicine taken from the store.',
    child: _StockOutForm(itemId: itemId),
  );
}

class _StockOutForm extends StatefulWidget {
  const _StockOutForm({this.itemId});
  final String? itemId;

  @override
  State<_StockOutForm> createState() => _StockOutFormState();
}

class _StockOutFormState extends State<_StockOutForm> {
  final _form = GlobalKey<FormState>();
  late String? _item = widget.itemId ?? _firstFeed();
  final _qty = TextEditingController();
  DateTime _date = DateTime.now();
  TargetType? _targetType;
  String? _target;
  bool _saving = false;

  String? _firstFeed() {
    final feeds = context.read<FarmStore>().items.where((i) => i.category == ItemCategory.feed).toList();
    return feeds.length == 1 ? feeds.first.id : null;
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await guard(
      () => context.read<FarmStore>().stockOut(
        _item!,
        _date,
        V.parse(_qty.text)!.toDouble(),
        targetType: _target == null ? null : _targetType,
        targetId: _target,
      ),
      success: 'Usage recorded',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final it = store.item(_item);
    final have = it == null ? null : store.stockOf(it.id);
    return Form(
      key: _form,
      child: Column(
        children: [
          SelectField<String>(
            label: 'Item',
            value: _item,
            icon: PhosphorIconsRegular.grains,
            options: _itemOptions(store),
            onChanged: (v) => setState(() => _item = v),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Quantity used',
                  controller: _qty,
                  suffixText: it?.unit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: AppTextField.decimal,
                  validator: (v) => V.number(v, field: 'Quantity', max: have),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DateField(label: 'Date', value: _date, lastDate: DateTime.now(), onChanged: (d) => setState(() => _date = d ?? DateTime.now())),
              ),
            ],
          ),
          if (have != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${Fmt.number(have, decimals: have % 1 == 0 ? 0 : 1)} ${it!.unit} in store', style: context.text.bodySmall),
              ),
            ),
          const SizedBox(height: 16),
          ChoicePills<TargetType?>(
            label: 'Used for',
            value: _targetType,
            onChanged: (v) => setState(() {
              _targetType = v;
              _target = null;
            }),
            options: const [
              PickerOption(null, 'General'),
              PickerOption(TargetType.flock, 'A flock', icon: PhosphorIconsBold.bird),
              PickerOption(TargetType.pig, 'Pigs', icon: PhosphorIconsBold.piggyBank),
            ],
          ),
          if (_targetType == TargetType.flock) ...[
            const SizedBox(height: 16),
            SelectField<String>(
              label: 'Flock',
              value: _target,
              optional: true,
              options: flockOptions(store.activeFlocks, store),
              onChanged: (v) => setState(() => _target = v),
            ),
          ],
          if (_targetType == TargetType.pig) ...[
            const SizedBox(height: 16),
            SelectField<String>(
              label: 'Pig / pen',
              value: _target,
              optional: true,
              icon: PhosphorIconsRegular.piggyBank,
              options: [for (final p in store.activePigs) PickerOption(p.id, p.displayName, subtitle: '${p.tag} · ${p.pen}')],
              onChanged: (v) => setState(() => _target = v),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save usage', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
