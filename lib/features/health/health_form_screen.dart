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
import '../poultry/flock_sheets.dart';

const _poultryProducts = [
  'Newcastle (Lasota)',
  'Gumboro (IBD)',
  "Marek's",
  'Fowl pox',
  'Fowl typhoid',
  'Infectious bronchitis',
  'Coccidiostat',
  'Dewormer',
  'Vitamins & electrolytes',
];
const _pigProducts = ['Iron injection', 'Ivermectin', 'Erysipelas', 'Foot & mouth (FMD)', 'Antibiotic (Oxytetracycline)', 'Albendazole', 'Vitamins'];

class HealthFormScreen extends StatefulWidget {
  const HealthFormScreen({super.key, this.targetType, this.targetId});
  final TargetType? targetType;
  final String? targetId;

  @override
  State<HealthFormScreen> createState() => _HealthFormScreenState();
}

class _HealthFormScreenState extends State<HealthFormScreen> {
  final _form = GlobalKey<FormState>();
  late TargetType _targetType = widget.targetType ?? (context.read<FarmStore>().activeFlocks.isNotEmpty ? TargetType.flock : TargetType.pig);
  late String? _target = widget.targetId;
  HealthType _type = HealthType.vaccination;
  final _product = TextEditingController();
  final _dose = TextEditingController();
  final _cost = TextEditingController();
  final _by = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  DateTime? _next;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_product, _dose, _cost, _by, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) {
      showToast('Please fix the highlighted fields.', type: ToastType.error);
      return;
    }
    setState(() => _saving = true);
    final ok = await guard(
      () => context.read<FarmStore>().addHealth(
        HealthRecord(
          id: newId(),
          targetType: _targetType,
          targetId: _target!,
          date: _date,
          type: _type,
          product: _product.text.trim(),
          dose: _dose.text.trim(),
          cost: V.parse(_cost.text)?.toDouble() ?? 0,
          administeredBy: _by.text.trim(),
          nextDue: _next,
          notes: _notes.text.trim(),
        ),
      ),
      success: _next != null ? 'Saved. We\'ll remind you on ${Fmt.dateShort(_next!)}' : 'Health record saved',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final suggestions = _targetType == TargetType.flock ? _poultryProducts : _pigProducts;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: 'Health record', subtitle: 'Vaccinations, treatments and check-ups'),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    if (widget.targetId == null) ...[
                      ChoicePills<TargetType>(
                        label: 'For',
                        value: _targetType,
                        onChanged: (v) => setState(() {
                          _targetType = v;
                          _target = null;
                        }),
                        options: const [
                          PickerOption(TargetType.flock, 'A flock', icon: PhosphorIconsBold.bird),
                          PickerOption(TargetType.pig, 'A pig', icon: PhosphorIconsBold.piggyBank),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_targetType == TargetType.flock)
                        SelectField<String>(
                          label: 'Flock',
                          value: _target,
                          options: flockOptions(store.activeFlocks, store),
                          onChanged: (v) => setState(() => _target = v),
                        )
                      else
                        SelectField<String>(
                          label: 'Pig',
                          value: _target,
                          icon: PhosphorIconsRegular.piggyBank,
                          options: [for (final p in store.activePigs) PickerOption(p.id, p.displayName, subtitle: '${p.tag} · ${p.stage.label}')],
                          onChanged: (v) => setState(() => _target = v),
                        ),
                      const SizedBox(height: 18),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: AppCard(
                          shadow: false,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              IconTile(
                                icon: _targetType == TargetType.pig ? PhosphorIconsBold.piggyBank : PhosphorIconsBold.bird,
                                color: AppColors.forest,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Text(store.targetName(_targetType, _target!), style: context.text.titleMedium),
                            ],
                          ),
                        ),
                      ),
                    const FieldLabel('Type'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in HealthType.values)
                          Pressable(
                            onTap: () => setState(() => _type = t),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(color: _type == t ? t.color : t.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(t.icon, size: 16, color: _type == t ? Colors.white : t.color),
                                  const SizedBox(width: 6),
                                  Text(t.label, style: context.text.labelMedium?.copyWith(color: _type == t ? Colors.white : t.color)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Medicine / vaccine',
                      controller: _product,
                      icon: PhosphorIconsRegular.flask,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => V.required(v, 'Product name'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in suggestions)
                          ActionChip(
                            label: Text(s),
                            labelStyle: context.text.labelSmall?.copyWith(color: context.palette.inkSoft),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _product.text = s),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(label: 'Dose / method', controller: _dose, optional: true, hint: 'e.g. drinking water'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DateField(
                            label: 'Date given',
                            value: _date,
                            lastDate: DateTime.now(),
                            onChanged: (d) => setState(() => _date = d ?? DateTime.now()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    DateField(
                      label: 'Next dose / booster',
                      value: _next,
                      optional: true,
                      firstDate: _date.add(const Duration(days: 1)),
                      hint: 'No follow-up',
                      helper: 'You will get a reminder before this date.',
                      onChanged: (d) => setState(() => _next = d),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final (label, days) in [('+7 days', 7), ('+14 days', 14), ('+21 days', 21), ('+1 month', 30), ('+3 months', 90)])
                          ActionChip(
                            label: Text(label),
                            labelStyle: context.text.labelSmall?.copyWith(color: context.palette.inkSoft),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _next = _date.add(Duration(days: days))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Cost',
                            controller: _cost,
                            optional: true,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: AppTextField.decimal,
                            validator: (v) => V.number(v, field: 'Cost', optional: true, allowZero: true, max: 10000000),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Given by',
                            controller: _by,
                            optional: true,
                            hint: 'e.g. Dr. Mwangi',
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AppTextField(label: 'Notes', controller: _notes, optional: true, maxLines: 3, hint: 'Symptoms, reactions…'),
                    const SizedBox(height: 28),
                    PrimaryButton(label: 'Save record', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
