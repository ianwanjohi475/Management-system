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

List<PickerOption<String>> _pigOptions(Iterable<Pig> pigs) => [
  for (final p in pigs)
    PickerOption(
      p.id,
      p.displayName,
      subtitle: '${p.tag} · ${p.stage.label}',
      icon: p.sex.icon,
      color: p.sex == Sex.female ? AppColors.pinkDeep : AppColors.info,
    ),
];

// ───────────────────────── Weight ─────────────────────────

Future<void> showWeightSheet(BuildContext context, {String? pigId}) {
  final store = context.read<FarmStore>();
  if (store.activePigs.isEmpty) {
    showToast('Add a pig first.', type: ToastType.info);
    return Future.value();
  }
  return showFormSheet(
    context,
    title: 'Record weight',
    subtitle: 'Regular weighing shows how well pigs grow.',
    child: _WeightForm(pigId: pigId),
  );
}

class _WeightForm extends StatefulWidget {
  const _WeightForm({this.pigId});
  final String? pigId;

  @override
  State<_WeightForm> createState() => _WeightFormState();
}

class _WeightFormState extends State<_WeightForm> {
  final _form = GlobalKey<FormState>();
  late String? _pig = widget.pigId;
  DateTime _date = DateTime.now();
  final _kg = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _kg.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await guard(
      () => context.read<FarmStore>().addWeight(_pig!, _date, V.parse(_kg.text)!.toDouble(), _notes.text.trim()),
      success: 'Weight recorded',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final last = _pig == null ? null : store.latestWeight(_pig!);
    return Form(
      key: _form,
      child: Column(
        children: [
          if (widget.pigId == null) ...[
            SelectField<String>(
              label: 'Pig',
              value: _pig,
              icon: PhosphorIconsRegular.tag,
              options: _pigOptions(store.activePigs),
              onChanged: (v) => setState(() => _pig = v),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Weight',
                  controller: _kg,
                  suffixText: 'kg',
                  autofocus: widget.pigId != null,
                  icon: PhosphorIconsRegular.scales,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: AppTextField.decimal,
                  validator: (v) => V.number(v, field: 'Weight', max: 450),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DateField(label: 'Date', value: _date, lastDate: DateTime.now(), onChanged: (d) => setState(() => _date = d ?? DateTime.now())),
              ),
            ],
          ),
          if (last != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Row(
                children: [
                  Icon(PhosphorIconsRegular.clockCounterClockwise, size: 14, color: context.palette.inkMuted),
                  const SizedBox(width: 6),
                  Text('Last: ${Fmt.kg(last.kg)} on ${Fmt.dateShort(last.date)}', style: context.text.bodySmall),
                ],
              ),
            ),
          const SizedBox(height: 16),
          AppTextField(label: 'Notes', controller: _notes, optional: true, hint: 'e.g. weighed with tape'),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save weight', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}

// ───────────────────────── Service (mating) ─────────────────────────

Future<void> showServiceSheet(BuildContext context, {String? sowId}) {
  final store = context.read<FarmStore>();
  final sows = store.activePigs.where((p) => p.sex == Sex.female && (p.stage == PigStage.sow || p.stage == PigStage.gilt)).toList();
  if (sows.isEmpty) {
    showToast('Add a sow or gilt first.', type: ToastType.info);
    return Future.value();
  }
  return showFormSheet(
    context,
    title: 'Record service',
    subtitle: 'We\'ll work out the heat check (21 days) and farrowing date (114 days).',
    child: _ServiceForm(sowId: sowId),
  );
}

class _ServiceForm extends StatefulWidget {
  const _ServiceForm({this.sowId});
  final String? sowId;

  @override
  State<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<_ServiceForm> {
  final _form = GlobalKey<FormState>();
  late String? _sow = widget.sowId;
  String? _boar;
  final _boarName = TextEditingController();
  final _notes = TextEditingController();
  ServiceMethod _method = ServiceMethod.natural;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _boarName.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final store = context.read<FarmStore>();
    final boar = store.pig(_boar);
    final ok = await guard(
      () => store.addBreeding(
        BreedingRecord(
          id: newId(),
          sowId: _sow!,
          boarId: _method == ServiceMethod.natural ? _boar : null,
          boarName: _method == ServiceMethod.natural ? (boar?.displayName ?? _boarName.text.trim()) : _boarName.text.trim(),
          serviceDate: _date,
          method: _method,
          notes: _notes.text.trim(),
        ),
      ),
      success: 'Service recorded. Farrowing due ${Fmt.date(_date.add(const Duration(days: BreedingRecord.gestationDays)))}',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final sows = store.activePigs.where((p) => p.sex == Sex.female && (p.stage == PigStage.sow || p.stage == PigStage.gilt)).toList();
    final due = _date.add(const Duration(days: BreedingRecord.gestationDays));
    return Form(
      key: _form,
      child: Column(
        children: [
          SelectField<String>(
            label: 'Sow / gilt',
            value: _sow,
            icon: PhosphorIconsRegular.genderFemale,
            options: _pigOptions(sows),
            onChanged: (v) => setState(() => _sow = v),
          ),
          const SizedBox(height: 16),
          ChoicePills<ServiceMethod>(
            label: 'Method',
            value: _method,
            onChanged: (v) => setState(() => _method = v),
            options: const [
              PickerOption(ServiceMethod.natural, 'Natural (boar)', icon: PhosphorIconsBold.genderMale),
              PickerOption(ServiceMethod.ai, 'A.I.', icon: PhosphorIconsBold.syringe),
            ],
          ),
          const SizedBox(height: 16),
          if (_method == ServiceMethod.natural && store.boars.isNotEmpty)
            SelectField<String>(
              label: 'Boar',
              value: _boar,
              optional: true,
              icon: PhosphorIconsRegular.genderMale,
              options: _pigOptions(store.boars),
              onChanged: (v) => setState(() => _boar = v),
            )
          else
            AppTextField(
              label: _method == ServiceMethod.ai ? 'Semen source' : 'Boar name',
              controller: _boarName,
              optional: true,
              hint: _method == ServiceMethod.ai ? 'e.g. KALRO Naivasha' : 'Neighbour\'s boar',
            ),
          const SizedBox(height: 16),
          DateField(label: 'Service date', value: _date, lastDate: DateTime.now(), onChanged: (d) => setState(() => _date = d ?? DateTime.now())),
          const SizedBox(height: 16),
          AppCard(
            shadow: false,
            color: AppColors.pinkSoft.withValues(alpha: context.isDark ? 0.12 : 1),
            border: false,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const IconTile(icon: PhosphorIconsBold.baby, color: AppColors.pinkDeep, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expected farrowing', style: context.text.bodySmall),
                      Text(Fmt.dayMonth(due), style: context.text.titleMedium),
                      Text('Heat check on ${Fmt.dateShort(_date.add(const Duration(days: 21)))}', style: context.text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(label: 'Notes', controller: _notes, optional: true),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save service', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}

// ───────────────────────── Farrowing ─────────────────────────

Future<void> showFarrowingSheet(BuildContext context, BreedingRecord b) => showFormSheet(
  context,
  title: 'Record farrowing',
  subtitle: 'Congratulations! How did it go?',
  child: _FarrowingForm(record: b),
);

class _FarrowingForm extends StatefulWidget {
  const _FarrowingForm({required this.record});
  final BreedingRecord record;

  @override
  State<_FarrowingForm> createState() => _FarrowingFormState();
}

class _FarrowingFormState extends State<_FarrowingForm> {
  DateTime _date = DateTime.now();
  int _alive = 10;
  int _still = 0;
  bool _add = true;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    var added = 0;
    final ok = await guard(() async {
      added = await context.read<FarmStore>().recordFarrowing(widget.record.id, date: _date, bornAlive: _alive, stillborn: _still, addPiglets: _add);
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
      showToast(added > 0 ? 'Farrowing saved. $added piglets added to your herd.' : 'Farrowing saved.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DateField(
          label: 'Farrowing date',
          value: _date,
          firstDate: widget.record.serviceDate,
          lastDate: DateTime.now(),
          onChanged: (d) => setState(() => _date = d ?? DateTime.now()),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Stepper2(label: 'Born alive', value: _alive, max: 30, onChanged: (v) => setState(() => _alive = v)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Stepper2(label: 'Stillborn', value: _still, max: 30, onChanged: (v) => setState(() => _still = v)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _add,
          onChanged: (v) => setState(() => _add = v),
          title: const Text('Add piglets to my herd'),
          subtitle: const Text('Creates a record for each live piglet with its own tag.'),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Save farrowing', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
      ],
    );
  }
}

// ───────────────────────── Weaning ─────────────────────────

Future<void> showWeaningSheet(BuildContext context, BreedingRecord b) => showFormSheet(
  context,
  title: 'Record weaning',
  subtitle: 'Piglets from this litter will move to the weaner stage.',
  child: _WeaningForm(record: b),
);

class _WeaningForm extends StatefulWidget {
  const _WeaningForm({required this.record});
  final BreedingRecord record;

  @override
  State<_WeaningForm> createState() => _WeaningFormState();
}

class _WeaningFormState extends State<_WeaningForm> {
  DateTime _date = DateTime.now();
  late int _count = widget.record.bornAlive ?? 0;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await guard(() => context.read<FarmStore>().recordWeaning(widget.record.id, _date, _count), success: 'Litter weaned');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      DateField(
        label: 'Weaning date',
        value: _date,
        firstDate: widget.record.farrowDate,
        lastDate: DateTime.now(),
        onChanged: (d) => setState(() => _date = d ?? DateTime.now()),
      ),
      const SizedBox(height: 16),
      Stepper2(label: 'Piglets weaned', value: _count, max: widget.record.bornAlive ?? 30, onChanged: (v) => setState(() => _count = v)),
      const SizedBox(height: 24),
      PrimaryButton(label: 'Save weaning', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
    ],
  );
}

// ───────────────────────── Death ─────────────────────────

Future<void> showPigDeathSheet(BuildContext context, Pig pig) => showFormSheet(
  context,
  title: 'Record death',
  subtitle: 'Sorry for the loss. This keeps your records accurate.',
  child: _DeathForm(pig: pig),
);

class _DeathForm extends StatefulWidget {
  const _DeathForm({required this.pig});
  final Pig pig;

  @override
  State<_DeathForm> createState() => _DeathFormState();
}

class _DeathFormState extends State<_DeathForm> {
  DateTime _date = DateTime.now();
  String _cause = 'Disease';
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await guard(() => context.read<FarmStore>().markPigDead(widget.pig.id, _date, _cause), success: 'Recorded');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      DateField(label: 'Date', value: _date, lastDate: DateTime.now(), onChanged: (d) => setState(() => _date = d ?? DateTime.now())),
      const SizedBox(height: 16),
      SelectField<String>(
        label: 'Cause',
        value: _cause,
        icon: PhosphorIconsRegular.firstAid,
        options: [for (final c in mortalityCauses.where((c) => c != 'Culled')) PickerOption(c, c)],
        onChanged: (v) => setState(() => _cause = v),
      ),
      const SizedBox(height: 24),
      PrimaryButton(label: 'Save', color: AppColors.danger, loading: _saving, onPressed: _save),
    ],
  );
}
