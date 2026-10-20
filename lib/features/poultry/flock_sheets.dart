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

List<PickerOption<String>> flockOptions(Iterable<Flock> flocks, FarmStore store) => [
  for (final f in flocks) PickerOption(f.id, f.name, subtitle: '${f.type.label} · ${Fmt.number(store.birdsAlive(f.id))} birds', image: f.type.image),
];

// ───────────────────────── Eggs ─────────────────────────

Future<void> showEggSheet(BuildContext context, {String? flockId, EggRecord? existing}) {
  final store = context.read<FarmStore>();
  if (!store.activeFlocks.any((f) => f.type.laysEggs) && existing == null) {
    showToast('Add a layers or kienyeji flock first.', type: ToastType.info);
    return Future.value();
  }
  return showFormSheet(
    context,
    title: existing == null ? 'Collect eggs' : 'Edit egg record',
    subtitle: 'Count good and broken eggs separately.',
    child: _EggForm(flockId: flockId ?? existing?.flockId, existing: existing),
  );
}

class _EggForm extends StatefulWidget {
  const _EggForm({this.flockId, this.existing});
  final String? flockId;
  final EggRecord? existing;

  @override
  State<_EggForm> createState() => _EggFormState();
}

class _EggFormState extends State<_EggForm> {
  final _form = GlobalKey<FormState>();
  late String? _flock = widget.flockId ?? _defaultFlock();
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late final _collected = TextEditingController(text: widget.existing?.collected.toString() ?? '');
  late final _broken = TextEditingController(text: (widget.existing?.broken ?? 0).toString());
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  bool _saving = false;

  String? _defaultFlock() {
    final layers = context.read<FarmStore>().activeFlocks.where((f) => f.type.laysEggs).toList();
    return layers.length == 1 ? layers.first.id : null;
  }

  @override
  void dispose() {
    _collected.dispose();
    _broken.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final rec = EggRecord(
      id: widget.existing?.id ?? newId(),
      flockId: _flock!,
      date: _date,
      collected: V.parse(_collected.text)!.toInt(),
      broken: V.parse(_broken.text)?.toInt() ?? 0,
      notes: _notes.text.trim(),
    );
    final ok = await guard(() => context.read<FarmStore>().saveEggs(rec), success: '${rec.good} good eggs recorded');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final layers = store.flocks.where((f) => f.type.laysEggs && (f.isActive || f.id == _flock)).toList();
    final collected = V.parse(_collected.text)?.toInt() ?? 0;
    final broken = V.parse(_broken.text)?.toInt() ?? 0;
    final good = (collected - broken).clamp(0, 100000);
    final perTray = store.eggsPerTray;
    return Form(
      key: _form,
      child: Column(
        children: [
          SelectField<String>(label: 'Flock', value: _flock, options: flockOptions(layers, store), onChanged: (v) => setState(() => _flock = v)),
          const SizedBox(height: 16),
          DateField(label: 'Date', value: _date, lastDate: DateTime.now(), onChanged: (d) => setState(() => _date = d ?? DateTime.now())),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Eggs collected',
                  controller: _collected,
                  icon: PhosphorIconsRegular.egg,
                  keyboardType: TextInputType.number,
                  inputFormatters: AppTextField.digits,
                  onChanged: (_) => setState(() {}),
                  validator: (v) => V.number(v, field: 'Eggs', integer: true, max: 100000),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Broken / bad',
                  controller: _broken,
                  icon: PhosphorIconsRegular.eggCrack,
                  keyboardType: TextInputType.number,
                  inputFormatters: AppTextField.digits,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final e = V.number(v, field: 'Broken', optional: true, allowZero: true, integer: true);
                    if (e != null) return e;
                    if ((V.parse(v) ?? 0) > collected) return "Can't be more than collected";
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: AppCard(
              key: ValueKey(good),
              shadow: false,
              border: false,
              color: AppColors.amberSoft.withValues(alpha: context.isDark ? 0.12 : 1),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const IconTile(icon: PhosphorIconsBold.egg, color: AppColors.warning, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${Fmt.number(good)} good eggs', style: context.text.titleMedium),
                        Text('= ${good ~/ perTray} trays + ${good % perTray} eggs', style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(label: 'Notes', controller: _notes, optional: true, hint: 'e.g. small eggs, soft shells'),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save eggs', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}

// ───────────────────────── Mortality ─────────────────────────

Future<void> showMortalitySheet(BuildContext context, {String? flockId}) {
  final store = context.read<FarmStore>();
  if (store.activeFlocks.isEmpty) {
    showToast('Add a flock first.', type: ToastType.info);
    return Future.value();
  }
  return showFormSheet(
    context,
    title: 'Record bird deaths',
    subtitle: 'Tracking causes helps you spot disease early.',
    child: _MortalityForm(flockId: flockId),
  );
}

class _MortalityForm extends StatefulWidget {
  const _MortalityForm({this.flockId});
  final String? flockId;

  @override
  State<_MortalityForm> createState() => _MortalityFormState();
}

class _MortalityFormState extends State<_MortalityForm> {
  final _form = GlobalKey<FormState>();
  late String? _flock = widget.flockId ?? (context.read<FarmStore>().activeFlocks.length == 1 ? context.read<FarmStore>().activeFlocks.first.id : null);
  DateTime _date = DateTime.now();
  final _count = TextEditingController(text: '1');
  final _notes = TextEditingController();
  String _cause = 'Unknown';
  bool _saving = false;

  @override
  void dispose() {
    _count.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await guard(
      () => context.read<FarmStore>().addMortality(
        MortalityRecord(id: newId(), flockId: _flock!, date: _date, count: V.parse(_count.text)!.toInt(), cause: _cause, notes: _notes.text.trim()),
      ),
      success: 'Recorded',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final alive = _flock == null ? null : store.birdsAlive(_flock!);
    return Form(
      key: _form,
      child: Column(
        children: [
          SelectField<String>(label: 'Flock', value: _flock, options: flockOptions(store.activeFlocks, store), onChanged: (v) => setState(() => _flock = v)),
          const SizedBox(height: 16),
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
                  validator: (v) => V.number(v, field: 'Number', integer: true, max: alive),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DateField(label: 'Date', value: _date, lastDate: DateTime.now(), onChanged: (d) => setState(() => _date = d ?? DateTime.now())),
              ),
            ],
          ),
          if (alive != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${Fmt.number(alive)} birds currently alive', style: context.text.bodySmall),
              ),
            ),
          const SizedBox(height: 16),
          SelectField<String>(
            label: 'Cause',
            value: _cause,
            icon: PhosphorIconsRegular.firstAid,
            options: [for (final c in mortalityCauses) PickerOption(c, c)],
            onChanged: (v) => setState(() => _cause = v),
          ),
          const SizedBox(height: 16),
          AppTextField(label: 'Notes', controller: _notes, optional: true, hint: 'Symptoms seen'),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
