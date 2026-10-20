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

class FlockFormScreen extends StatefulWidget {
  const FlockFormScreen({super.key, this.flock});
  final Flock? flock;

  @override
  State<FlockFormScreen> createState() => _FlockFormScreenState();
}

class _FlockFormScreenState extends State<FlockFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Flock? _f = widget.flock;
  late BirdType _type = _f?.type ?? (context.read<FarmStore>().farm?.birdTypes.firstOrNull ?? BirdType.layers);
  late String? _breed = _f?.breed;
  late final _name = TextEditingController(text: _f?.name ?? _suggestName());
  late final _count = TextEditingController(text: _f?.initialCount.toString() ?? '');
  late final _age = TextEditingController(text: (_f?.ageAtStartWeeks ?? 0).toString());
  late final _house = TextEditingController(text: _f?.house ?? '');
  late final _cost = TextEditingController(text: _f?.costPerBird?.toStringAsFixed(0) ?? '');
  late final _notes = TextEditingController(text: _f?.notes ?? '');
  late DateTime _start = _f?.startDate ?? DateTime.now();
  bool _saving = false;

  bool get _editing => _f != null;

  String _suggestName() {
    final n = context.read<FarmStore>().flocks.length + 1;
    return 'Batch $n';
  }

  @override
  void dispose() {
    for (final c in [_name, _count, _age, _house, _cost, _notes]) {
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
    final flock = Flock(
      id: _f?.id ?? newId(),
      name: _name.text.trim(),
      type: _type,
      breed: _breed ?? 'Other',
      initialCount: V.parse(_count.text)!.toInt(),
      startDate: _start,
      ageAtStartWeeks: V.parse(_age.text)?.toInt() ?? 0,
      house: _house.text.trim(),
      costPerBird: V.parse(_cost.text)?.toDouble(),
      status: _f?.status ?? FlockStatus.active,
      notes: _notes.text.trim(),
      createdAt: _f?.createdAt ?? DateTime.now(),
    );
    final ok = await guard(() => context.read<FarmStore>().saveFlock(flock), success: _editing ? 'Changes saved' : '${flock.name} added');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, flock.id);
  }

  @override
  Widget build(BuildContext context) {
    final cost = V.parse(_cost.text) ?? 0;
    final count = V.parse(_count.text) ?? 0;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(title: _editing ? 'Edit flock' : 'New flock', subtitle: _editing ? _f!.name : 'A batch of birds that came in together'),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    const FieldLabel('Type of birds'),
                    Row(
                      children: [
                        for (final (i, t) in BirdType.values.indexed) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: Pressable(
                              onTap: _editing
                                  ? null
                                  : () => setState(() {
                                      _type = t;
                                      _breed = null;
                                    }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _type == t ? context.palette.brandTint : context.palette.card,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _type == t ? Theme.of(context).colorScheme.primary : context.palette.border,
                                    width: _type == t ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Image.asset(t.image, width: 54, height: 54),
                                    const SizedBox(height: 6),
                                    Text(t.label, style: context.text.titleSmall),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_editing)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text("Type can't change after records are added.", style: context.text.bodySmall),
                      ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Flock name',
                      controller: _name,
                      icon: PhosphorIconsRegular.identificationBadge,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => V.name(v, 'Flock name'),
                    ),
                    const SizedBox(height: 18),
                    SelectField<String>(
                      label: 'Breed',
                      value: _breed,
                      icon: PhosphorIconsRegular.dna,
                      options: [for (final b in birdBreeds[_type]!) PickerOption(b, b)],
                      onChanged: (v) => setState(() => _breed = v),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Number of birds',
                            controller: _count,
                            icon: PhosphorIconsRegular.bird,
                            keyboardType: TextInputType.number,
                            inputFormatters: AppTextField.digits,
                            onChanged: (_) => setState(() {}),
                            validator: (v) => V.number(v, field: 'Number of birds', integer: true, max: 100000),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Age when bought',
                            controller: _age,
                            suffixText: 'weeks',
                            keyboardType: TextInputType.number,
                            inputFormatters: AppTextField.digits,
                            validator: (v) => V.number(v, field: 'Age', optional: true, allowZero: true, integer: true, max: 150),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DateField(
                            label: 'Date in',
                            value: _start,
                            lastDate: DateTime.now(),
                            onChanged: (d) => setState(() => _start = d ?? DateTime.now()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(label: 'House', controller: _house, optional: true, hint: 'e.g. House A'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Cost per bird',
                      controller: _cost,
                      optional: true,
                      icon: PhosphorIconsRegular.money,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: AppTextField.decimal,
                      onChanged: (_) => setState(() {}),
                      validator: (v) => V.number(v, field: 'Cost', optional: true, allowZero: true, max: 100000),
                      enabled: !_editing,
                    ),
                    if (!_editing && cost > 0 && count > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text('${Fmt.money(cost * count)} will be added to your expenses.', style: context.text.bodySmall),
                      ),
                    const SizedBox(height: 18),
                    AppTextField(label: 'Notes', controller: _notes, optional: true, maxLines: 3, hint: 'Supplier, hatchery, anything useful'),
                    const SizedBox(height: 28),
                    PrimaryButton(label: _editing ? 'Save changes' : 'Add flock', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
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
