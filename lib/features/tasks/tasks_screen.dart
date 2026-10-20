import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import 'task_sheet.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _view = 0; // 0 today, 1 upcoming, 2 done

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final today = DateTime.now();
    final day = dateOnly(today);
    final todayList = store.tasks
        .where((t) => t.repeatDaily || (!t.done && !dateOnly(t.dueDate).isAfter(day)) || (t.done && t.dueDate.isSameDay(today)))
        .toList();
    final upcoming = store.tasks.where((t) => !t.repeatDaily && !t.done && dateOnly(t.dueDate).isAfter(day)).toList();
    final done = store.tasks.where((t) => !t.repeatDaily && t.done).toList()..sort((a, b) => (b.doneAt ?? b.dueDate).compareTo(a.doneAt ?? a.dueDate));
    final list = [todayList, upcoming, done][_view];
    final doneToday = todayList.where((t) => t.doneOn(today)).length;
    final progress = todayList.isEmpty ? 1.0 : doneToday / todayList.length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskSheet(context),
        icon: const Icon(PhosphorIconsBold.plus),
        label: const Text('New task'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: PageHeader(title: 'Tasks', subtitle: 'Daily chores and to-dos'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: AppCard(
                  gradient: AppColors.heroGradient,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: v,
                                strokeWidth: 7,
                                color: AppColors.lime,
                                backgroundColor: Colors.white.withValues(alpha: 0.18),
                                strokeCap: StrokeCap.round,
                              ),
                              Text(
                                '${(v * 100).round()}%',
                                style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              progress >= 1 ? 'All done for today!' : '$doneToday of ${todayList.length} done',
                              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              Fmt.dayMonth(today),
                              style: TextStyle(fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilterChips<int>(
                  value: _view,
                  onChanged: (v) => setState(() => _view = v),
                  items: [(0, 'Today (${todayList.length})'), (1, 'Upcoming (${upcoming.length})'), (2, 'Done')],
                ),
              ),
            ),
            if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  image: Assets.tasksDone,
                  title: _view == 2 ? 'Nothing completed yet' : 'Nothing to do',
                  message: _view == 0 ? 'Add daily chores so your team never forgets.' : 'Tasks you add will show here.',
                  compact: true,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
                sliver: SliverToBoxAdapter(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Column(
                      children: [for (final t in list) TaskCheckRow(task: t, day: today, showDate: _view != 0)],
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

/// Checkbox row that animates when ticked. Swipe to delete.
class TaskCheckRow extends StatelessWidget {
  const TaskCheckRow({super.key, required this.task, required this.day, this.showDate = false});
  final FarmTask task;
  final DateTime day;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final done = task.doneOn(day);
    final overdue = !task.repeatDaily && !done && dateOnly(task.dueDate).isBefore(dateOnly(DateTime.now()));
    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirm(context, title: 'Delete task?', message: task.title),
      onDismissed: (_) => guard(() => store.deleteTask(task.id), success: 'Task deleted'),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(PhosphorIconsBold.trash, color: AppColors.danger),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => guard(() => store.toggleTask(task.id)),
        onLongPress: () => showTaskSheet(context, existing: task),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: done ? AppColors.forest : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: done ? AppColors.forest : (overdue ? AppColors.danger : context.palette.inkMuted), width: 2),
                ),
                child: AnimatedScale(
                  scale: done ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: const Icon(PhosphorIconsBold.check, size: 15, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: context.text.titleSmall!.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? context.palette.inkMuted : context.palette.ink,
                      ),
                      child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (task.repeatDaily || showDate || overdue || task.notes.isNotEmpty)
                      Text(
                        [
                          if (task.repeatDaily) 'Every day',
                          if (!task.repeatDaily && (showDate || overdue)) (overdue ? 'Overdue · ' : '') + Fmt.relativeDay(task.dueDate),
                          if (task.notes.isNotEmpty) task.notes,
                        ].join(' · '),
                        style: context.text.bodySmall?.copyWith(color: overdue ? AppColors.danger : null),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (task.priority == TaskPriority.high) const Icon(PhosphorIconsFill.flag, size: 16, color: AppColors.danger),
              if (task.repeatDaily) Icon(PhosphorIconsRegular.repeat, size: 16, color: context.palette.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
