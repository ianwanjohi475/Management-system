import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';

Future<void> showTaskSheet(BuildContext context, {FarmTask? existing}) => showFormSheet(
  context,
  title: existing == null ? 'New task' : 'Edit task',
  child: _TaskForm(existing: existing),
);

class _TaskForm extends StatefulWidget {
  const _TaskForm({this.existing});
  final FarmTask? existing;

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime _due = widget.existing?.dueDate ?? DateTime.now();
  late TaskPriority _priority = widget.existing?.priority ?? TaskPriority.normal;
  late bool _daily = widget.existing?.repeatDaily ?? false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final e = widget.existing;
    final t =
        e?.copyWith(title: _title.text.trim(), notes: _notes.text.trim(), dueDate: _due, priority: _priority, repeatDaily: _daily) ??
        FarmTask(
          id: newId(),
          title: _title.text.trim(),
          notes: _notes.text.trim(),
          dueDate: _due,
          priority: _priority,
          repeatDaily: _daily,
          createdAt: DateTime.now(),
        );
    final ok = await guard(() => context.read<FarmStore>().saveTask(t), success: 'Task saved');
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
          label: 'Task',
          controller: _title,
          hint: 'e.g. Clean the chicken house',
          icon: PhosphorIconsRegular.checkSquare,
          validator: (v) => V.required(v, 'Task'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in ['Feed & water birds', 'Collect eggs', 'Clean pig pens', 'Check water drinkers', 'Buy feed', 'Spray for mites'])
              ActionChip(label: Text(s), visualDensity: VisualDensity.compact, onPressed: () => setState(() => _title.text = s)),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _daily,
          onChanged: (v) => setState(() => _daily = v),
          title: const Text('Repeat every day'),
          subtitle: const Text('For daily chores like feeding'),
        ),
        if (!_daily) ...[
          const SizedBox(height: 8),
          DateField(
            label: 'Due date',
            value: _due,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            onChanged: (d) => setState(() => _due = d ?? DateTime.now()),
          ),
        ],
        const SizedBox(height: 16),
        ChoicePills<TaskPriority>(
          label: 'Priority',
          value: _priority,
          onChanged: (p) => setState(() => _priority = p),
          options: [
            for (final p in TaskPriority.values)
              PickerOption(p, p.label, icon: p == TaskPriority.high ? PhosphorIconsBold.flag : null, color: p == TaskPriority.high ? AppColors.danger : null),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(label: 'Notes', controller: _notes, optional: true, maxLines: 2),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Save task', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
      ],
    ),
  );
}
