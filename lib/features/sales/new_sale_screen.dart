import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../poultry/flock_sheets.dart';
import 'sale_success_screen.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key, this.product, this.flockId, this.pigIds = const [], this.customerId});

  final Product? product;
  final String? flockId;
  final List<String> pigIds;
  final String? customerId;

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final _form = GlobalKey<FormState>();
  late Product _product = widget.product ?? _defaultProduct();
  EggUnit _eggUnit = EggUnit.tray;
  late String? _flockId = widget.flockId;
  late final Set<String> _pigIds = {...widget.pigIds};
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _weight = TextEditingController();
  final _buyer = TextEditingController();
  final _phone = TextEditingController();
  final _paid = TextEditingController();
  final _ref = TextEditingController();
  final _notes = TextEditingController();
  late String? _customerId = widget.customerId;
  PaymentMethod _method = PaymentMethod.cash;
  bool _paidEdited = false;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  Product _defaultProduct() {
    final farm = context.read<FarmStore>().farm;
    if (farm == null) return Product.eggs;
    if (farm.birdTypes.any((b) => b.laysEggs)) return Product.eggs;
    if (farm.keepsPoultry) return Product.liveChicken;
    return Product.pig;
  }

  @override
  void initState() {
    super.initState();
    final store = context.read<FarmStore>();
    final c = store.customer(widget.customerId);
    if (c != null) {
      _buyer.text = c.name;
      _phone.text = c.phone;
    }
    _applyDefaults();
  }

  @override
  void dispose() {
    for (final c in [_qty, _price, _weight, _buyer, _phone, _paid, _ref, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fills sensible quantity / price defaults whenever the product changes.
  void _applyDefaults() {
    final store = context.read<FarmStore>();
    final farm = store.farm;
    switch (_product) {
      case Product.eggs:
        final tray = farm?.defaultTrayPrice ?? 450;
        _price.text = _eggUnit == EggUnit.tray ? tray.toStringAsFixed(0) : (tray / store.eggsPerTray).toStringAsFixed(0);
        _qty.text = '1';
      case Product.pig:
      case Product.piglet:
        _qty.text = '${_pigIds.isEmpty ? 1 : _pigIds.length}';
        _price.text = _product == Product.pig ? '20000' : '4000';
      case Product.liveChicken:
        _price.text = '900';
        _qty.text = '1';
        _flockId ??= _onlyFlock(store, broilers: false);
      case Product.dressedChicken:
        _price.text = '650';
        _qty.text = '1';
        _flockId ??= _onlyFlock(store, broilers: true);
      case Product.manure:
        _price.text = '300';
        _qty.text = '1';
    }
    if (!_paidEdited) _syncPaid();
  }

  String? _onlyFlock(FarmStore store, {required bool broilers}) {
    final list = store.activeFlocks.toList();
    if (list.length == 1) return list.first.id;
    final pref = list.where((f) => broilers ? f.type == BirdType.broilers : f.type != BirdType.broilers).toList();
    return pref.length == 1 ? pref.first.id : null;
  }

  double get _quantity => (V.parse(_qty.text) ?? 0).toDouble();
  double get _unitPrice => (V.parse(_price.text) ?? 0).toDouble();
  double get _total => _quantity * _unitPrice;

  void _syncPaid() {
    _paid.text = _method == PaymentMethod.credit ? '0' : _total.toStringAsFixed(_total % 1 == 0 ? 0 : 2);
  }

  void _changed() => setState(() {
    if (!_paidEdited) _syncPaid();
    _error = null;
  });

  String? _stockHint(FarmStore store, Product p) {
    switch (p) {
      case Product.eggs:
        return '${(store.eggStock / store.eggsPerTray).toStringAsFixed(1)} trays';
      case Product.liveChicken:
      case Product.dressedChicken:
        return '${Fmt.number(store.totalBirds)} birds';
      case Product.pig:
        return '${store.activePigs.where((x) => !x.stage.isYoung).length} pigs';
      case Product.piglet:
        return '${store.activePigs.where((x) => x.stage.isYoung).length} piglets';
      case Product.manure:
        return null;
    }
  }

  Future<void> _pickPigs() async {
    final store = context.read<FarmStore>();
    final candidates = store.activePigs.where((p) => _product == Product.piglet ? p.stage.isYoung : !p.stage.isYoung).toList();
    if (candidates.isEmpty) {
      showToast(_product == Product.piglet ? 'No active piglets or weaners to sell.' : 'No active pigs to sell.', type: ToastType.info);
      return;
    }
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PigPicker(candidates: candidates, selected: _pigIds),
    );
    if (picked == null) return;
    setState(() {
      _pigIds
        ..clear()
        ..addAll(picked);
      _qty.text = '${_pigIds.length}';
      if (!_paidEdited) _syncPaid();
      _error = null;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) {
      showToast('Please fix the highlighted fields.', type: ToastType.error);
      return;
    }
    setState(() => _saving = true);
    final store = context.read<FarmStore>();
    try {
      final sale = await store.createSale(
        date: _date,
        product: _product,
        quantity: _quantity,
        unitPrice: _unitPrice,
        eggUnit: _eggUnit,
        flockId: _flockId,
        pigIds: _pigIds.toList(),
        weightKg: V.parse(_weight.text)?.toDouble(),
        customerName: _buyer.text,
        customerPhone: _phone.text,
        customerId: _customerId,
        amountPaid: (V.parse(_paid.text) ?? 0).toDouble(),
        method: _method,
        reference: _ref.text.trim(),
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SaleSuccessScreen(saleId: sale.id)));
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e));
        showToast(friendlyError(e), type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final flocks = store.activeFlocks.where((f) => _product == Product.dressedChicken || _product == Product.liveChicken).toList();
    final customers = store.customers;
    final balance = _total - (V.parse(_paid.text) ?? 0);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: 'New sale', subtitle: 'Record what you sold and how it was paid'),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text('What are you selling?', style: context.text.titleLarge),
                    const SizedBox(height: 12),
                    GridView.count(
                      padding: EdgeInsets.zero,
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.82,
                      children: [
                        for (final (i, p) in Product.values.indexed)
                          _ProductCard(
                            product: p,
                            stock: _stockHint(store, p),
                            selected: _product == p,
                            onTap: () => setState(() {
                              if (_product == p) return;
                              _product = p;
                              _pigIds.clear();
                              _flockId = widget.flockId;
                              _error = null;
                              _applyDefaults();
                            }),
                          ).enter(i, dy: 0.15),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _section(context, PhosphorIconsBold.package, 'Details'),
                    const SizedBox(height: 14),
                    ..._detailFields(context, store, flocks),
                    const SizedBox(height: 24),
                    _section(context, PhosphorIconsBold.user, 'Buyer'),
                    const SizedBox(height: 14),
                    if (customers.isNotEmpty) ...[
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final c in customers.take(12))
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(c.name),
                                  selected: _customerId == c.id,
                                  avatar: _customerId == c.id ? null : Avatar(initials: c.initials, size: 22),
                                  onSelected: (sel) => setState(() {
                                    _customerId = sel ? c.id : null;
                                    _buyer.text = sel ? c.name : '';
                                    _phone.text = sel ? c.phone : '';
                                  }),
                                  labelStyle: context.text.labelMedium?.copyWith(
                                    color: _customerId == c.id ? Theme.of(context).colorScheme.onPrimary : context.palette.ink,
                                  ),
                                  showCheckmark: false,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _buyer,
                            hint: 'Buyer name',
                            icon: PhosphorIconsRegular.user,
                            textCapitalization: TextCapitalization.words,
                            onChanged: (_) => setState(() => _customerId = null),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppTextField(
                            controller: _phone,
                            hint: 'Phone',
                            icon: PhosphorIconsRegular.phone,
                            keyboardType: TextInputType.phone,
                            validator: (v) => V.phone(v, optional: true),
                            onChanged: (_) => setState(() => _customerId = null),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 6),
                      child: Text('Optional for cash sales. Needed if the buyer will pay later.', style: context.text.bodySmall),
                    ),
                    const SizedBox(height: 24),
                    _section(context, PhosphorIconsBold.wallet, 'Payment'),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in PaymentMethod.values)
                          Pressable(
                            onTap: () => setState(() {
                              _method = m;
                              _paidEdited = false;
                              _syncPaid();
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: _method == m ? Theme.of(context).colorScheme.primary : context.palette.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _method == m ? Theme.of(context).colorScheme.primary : context.palette.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(m.icon, size: 17, color: _method == m ? Theme.of(context).colorScheme.onPrimary : context.palette.inkSoft),
                                  const SizedBox(width: 6),
                                  Text(
                                    m.label,
                                    style: context.text.labelMedium?.copyWith(
                                      color: _method == m ? Theme.of(context).colorScheme.onPrimary : context.palette.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Amount paid now',
                            controller: _paid,
                            prefixText: '${Fmt.currency} ',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: AppTextField.decimal,
                            onChanged: (_) => setState(() => _paidEdited = true),
                            validator: (v) {
                              final e = V.number(v, field: 'Amount', allowZero: true, optional: true);
                              if (e != null) return e;
                              if ((V.parse(v) ?? 0) > _total + 0.001) return 'More than the total';
                              return null;
                            },
                          ),
                        ),
                        if (_method == PaymentMethod.mpesa || _method == PaymentMethod.bank) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              label: _method == PaymentMethod.mpesa ? 'M-Pesa code' : 'Reference',
                              controller: _ref,
                              optional: true,
                              hint: _method == PaymentMethod.mpesa ? 'e.g. RKT4H7Q2PX' : null,
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DateField(
                            label: 'Sale date',
                            value: _date,
                            lastDate: DateTime.now(),
                            onChanged: (d) => setState(() => _date = d ?? DateTime.now()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(label: 'Notes', controller: _notes, optional: true, hint: 'e.g. delivered'),
                        ),
                      ],
                    ),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            const Icon(PhosphorIconsFill.warningCircle, color: AppColors.danger, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_error!, style: context.text.bodyMedium?.copyWith(color: AppColors.danger)),
                            ),
                          ],
                        ),
                      ).animate().shakeX(hz: 4, amount: 4, duration: 400.ms),
                  ],
                ),
              ),
            ),
            _SummaryBar(total: _total, balance: balance, saving: _saving, onSave: _save),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, IconData icon, String title) => Row(
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Text(title, style: context.text.titleLarge),
    ],
  );

  List<Widget> _detailFields(BuildContext context, FarmStore store, List<Flock> flocks) {
    final unitLabel = _product == Product.eggs ? (_eggUnit == EggUnit.tray ? 'tray' : 'egg') : _product.unit;
    final qtyField = AppTextField(
      label: 'Quantity',
      controller: _qty,
      suffixText: '${unitLabel}s',
      enabled: !_product.fromPigs,
      keyboardType: TextInputType.numberWithOptions(decimal: _product == Product.eggs && _eggUnit == EggUnit.tray),
      inputFormatters: _product == Product.eggs && _eggUnit == EggUnit.tray ? AppTextField.decimal : AppTextField.digits,
      onChanged: (_) => _changed(),
      validator: (v) => V.number(v, field: 'Quantity', max: 1000000),
    );
    final priceField = AppTextField(
      label: 'Price per $unitLabel',
      controller: _price,
      prefixText: '${Fmt.currency} ',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: AppTextField.decimal,
      onChanged: (_) => _changed(),
      validator: (v) => V.number(v, field: 'Price', allowZero: true, max: 10000000),
    );

    return [
      if (_product == Product.eggs) ...[
        ChoicePills<EggUnit>(
          value: _eggUnit,
          onChanged: (u) => setState(() {
            _eggUnit = u;
            _applyDefaults();
          }),
          options: [
            PickerOption(EggUnit.tray, 'Trays of ${store.eggsPerTray}', icon: PhosphorIconsBold.gridNine),
            const PickerOption(EggUnit.piece, 'Single eggs', icon: PhosphorIconsBold.egg),
          ],
        ),
        const SizedBox(height: 14),
      ],
      if (_product.fromFlock) ...[
        SelectField<String>(label: 'From which flock?', value: _flockId, options: flockOptions(flocks, store), onChanged: (v) => setState(() => _flockId = v)),
        const SizedBox(height: 14),
      ],
      if (_product.fromPigs) ...[
        const FieldLabel('Which pigs?'),
        PickerShell(
          icon: PhosphorIconsRegular.piggyBank,
          hint: 'Tap to select pigs',
          text: _pigIds.isEmpty ? null : _pigIds.map((id) => store.pig(id)?.tag ?? '?').join(', '),
          onTap: _pickPigs,
          trailing: StatusPill('${_pigIds.length} selected', color: AppColors.pinkDeep),
        ),
        const SizedBox(height: 14),
      ],
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: qtyField),
          const SizedBox(width: 12),
          Expanded(child: priceField),
        ],
      ),
      if (_product.fromPigs) ...[
        const SizedBox(height: 14),
        AppTextField(
          label: 'Total live weight',
          controller: _weight,
          optional: true,
          suffixText: 'kg',
          icon: PhosphorIconsRegular.scales,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: AppTextField.decimal,
          validator: (v) => V.number(v, field: 'Weight', optional: true, max: 50000),
        ),
      ],
    ];
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.stock, required this.selected, required this.onTap});
  final Product product;
  final String? stock;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final primary = Theme.of(context).colorScheme.primary;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? p.brandTint : p.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? primary : p.border, width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: primary.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 6))] : null,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: AnimatedScale(
                    scale: selected ? 1.08 : 1,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    child: Image.asset(product.image),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.short,
                  style: context.text.labelMedium?.copyWith(color: p.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stock != null) Text(stock!, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                  child: Icon(PhosphorIconsBold.check, size: 13, color: Theme.of(context).colorScheme.onPrimary),
                ).animate().scale(duration: 250.ms, curve: Curves.easeOutBack),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.total, required this.balance, required this.saving, required this.onSave});
  final double total;
  final double balance;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
    decoration: BoxDecoration(
      color: context.palette.card,
      boxShadow: [BoxShadow(color: context.palette.shadow, blurRadius: 20, offset: const Offset(0, -6))],
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total', style: context.text.bodySmall),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(Fmt.money(total), key: ValueKey(total), style: context.text.headlineMedium),
            ),
            if (balance > 0.001) Text('${Fmt.money(balance)} on credit', style: context.text.labelSmall?.copyWith(color: AppColors.danger)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: PrimaryButton(label: 'Save sale', icon: PhosphorIconsBold.check, loading: saving, onPressed: onSave),
        ),
      ],
    ),
  );
}

class _PigPicker extends StatefulWidget {
  const _PigPicker({required this.candidates, required this.selected});
  final List<Pig> candidates;
  final Set<String> selected;

  @override
  State<_PigPicker> createState() => _PigPickerState();
}

class _PigPickerState extends State<_PigPicker> {
  late final Set<String> _sel = {...widget.selected.where((id) => widget.candidates.any((c) => c.id == id))};

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(child: Text('Select pigs', style: context.text.headlineSmall)),
                TextButton(
                  onPressed: () => setState(() => _sel.length == widget.candidates.length ? _sel.clear() : _sel.addAll(widget.candidates.map((e) => e.id))),
                  child: Text(_sel.length == widget.candidates.length ? 'Clear' : 'Select all'),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.candidates.length,
              itemBuilder: (_, i) {
                final p = widget.candidates[i];
                final w = store.latestWeight(p.id);
                return CheckboxListTile(
                  value: _sel.contains(p.id),
                  onChanged: (v) => setState(() => v == true ? _sel.add(p.id) : _sel.remove(p.id)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  secondary: PigPhoto(photo: p.photo, size: 44, radius: 12, young: p.stage.isYoung),
                  title: Text(p.displayName),
                  subtitle: Text('${p.tag} · ${p.stage.label}${w != null ? ' · ${Fmt.kg(w.kg)}' : ''}'),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: PrimaryButton(label: 'Done (${_sel.length})', onPressed: () => Navigator.pop(context, _sel)),
          ),
        ],
      ),
    );
  }
}
