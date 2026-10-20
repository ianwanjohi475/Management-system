import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';

class HealthTile extends StatelessWidget {
  const HealthTile({super.key, required this.record, this.showTarget = true});
  final HealthRecord record;
  final bool showTarget;

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final h = record;
    final parts = [if (showTarget) store.targetName(h.targetType, h.targetId), Fmt.date(h.date), if (h.dose.isNotEmpty) h.dose];
    return RecordTile(
      icon: h.type.icon,
      color: h.type.color,
      title: h.product,
      subtitle: parts.join(' · '),
      trailing: h.cost > 0 ? Fmt.money(h.cost) : null,
      trailingSub: h.hasOpenFollowUp ? 'Next ${Fmt.relativeDay(h.nextDue!).toLowerCase()}' : null,
      onTap: () => showHealthDetails(context, h),
    );
  }
}

Future<void> showHealthDetails(BuildContext context, HealthRecord h) {
  final store = context.read<FarmStore>();
  return showFormSheet(
    context,
    title: h.product,
    subtitle: '${h.type.label} · ${store.targetName(h.targetType, h.targetId)}',
    child: Builder(
      builder: (ctx) => Column(
        children: [
          AppCard(
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                InfoRow(label: 'Date', value: Fmt.date(h.date), icon: PhosphorIconsRegular.calendarBlank),
                if (h.dose.isNotEmpty) InfoRow(label: 'Dose / method', value: h.dose, icon: PhosphorIconsRegular.drop),
                if (h.administeredBy.isNotEmpty) InfoRow(label: 'Given by', value: h.administeredBy, icon: PhosphorIconsRegular.user),
                if (h.cost > 0) InfoRow(label: 'Cost', value: Fmt.money(h.cost), icon: PhosphorIconsRegular.money),
                if (h.nextDue != null)
                  InfoRow(
                    label: 'Next due',
                    value: h.nextDoneAt != null ? '${Fmt.date(h.nextDue!)} (done)' : Fmt.date(h.nextDue!),
                    icon: PhosphorIconsRegular.bellRinging,
                    valueColor: h.hasOpenFollowUp && dateOnly(h.nextDue!).isBefore(dateOnly(DateTime.now())) ? AppColors.danger : null,
                  ),
                if (h.notes.isNotEmpty) InfoRow(label: 'Notes', value: h.notes, icon: PhosphorIconsRegular.note),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (h.hasOpenFollowUp) ...[
            PrimaryButton(
              label: 'Mark follow-up as done',
              icon: PhosphorIconsBold.checkCircle,
              onPressed: () async {
                final ok = await guard(() => store.completeFollowUp(h.id), success: 'Reminder cleared');
                if (ok && ctx.mounted) Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: () async {
              if (await confirm(
                ctx,
                title: 'Delete record?',
                message: h.cost > 0 ? 'The linked expense of ${Fmt.money(h.cost)} will also be removed.' : 'This cannot be undone.',
              )) {
                final ok = await guard(() => store.deleteHealth(h.id), success: 'Deleted');
                if (ok && ctx.mounted) Navigator.pop(ctx);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
            ),
            icon: const Icon(PhosphorIconsBold.trash, size: 18),
            label: const Text('Delete record'),
          ),
        ],
      ),
    ),
  );
}

/// Card for a reminder that's coming up or overdue.
class DueCard extends StatelessWidget {
  const DueCard({super.key, required this.record});
  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final h = record;
    final days = dateOnly(h.nextDue!).difference(dateOnly(DateTime.now())).inDays;
    final color = days < 0 ? AppColors.danger : (days <= 3 ? AppColors.warning : AppColors.info);
    return AppCard(
      onTap: () => showHealthDetails(context, h),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Text(Fmt.monthShort(h.nextDue!).toUpperCase(), style: context.text.labelSmall?.copyWith(color: color)),
                Text('${h.nextDue!.day}', style: context.text.headlineSmall?.copyWith(color: color)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.product, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${store.targetName(h.targetType, h.targetId)} · ${h.type.label}',
                  style: context.text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          StatusPill(days < 0 ? 'Overdue' : Fmt.relativeDay(h.nextDue!), color: color),
        ],
      ),
    );
  }
}
