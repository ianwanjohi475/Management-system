import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../health/health_form_screen.dart';
import '../health/health_widgets.dart';
import '../sales/new_sale_screen.dart';
import '../sales/sale_detail_screen.dart';
import '../system/not_found_screen.dart';
import 'pig_form_screen.dart';
import 'pig_sheets.dart';

class PigDetailScreen extends StatelessWidget {
  const PigDetailScreen({super.key, required this.pigId});
  final String pigId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final pig = store.pig(pigId);
    if (pig == null) return const NotFoundScreen(message: 'This pig was deleted.');

    final weights = store.weightsOf(pig.id);
    final latest = weights.isEmpty ? null : weights.last;
    final gain = store.dailyGain(pig.id);
    final health = store.healthOf(TargetType.pig, pig.id);
    final isBreeder = pig.sex == Sex.female && (pig.stage == PigStage.sow || pig.stage == PigStage.gilt);
    final breedings = store.breedingsOf(pig.id);
    final mother = store.pig(pig.motherId);
    final father = store.pig(pig.fatherId);
    final offspring = store.offspringOf(pig.id);
    final saleId = pig.status == PigStatus.sold ? store.sales.where((s) => s.pigIds.contains(pig.id)).firstOrNull?.id : null;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.pinkSoft,
            leading: const Padding(padding: EdgeInsets.all(6), child: BackButtonX()),
            leadingWidth: 60,
            actions: [
              CircleIconButton(
                icon: PhosphorIconsBold.pencilSimple,
                tooltip: 'Edit',
                onTap: () => go(context, PigFormScreen(pig: pig)),
              ),
              const SizedBox(width: 8),
              _MoreMenu(pig: pig),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Hero(
                tag: 'pig-${pig.id}',
                child: PigPhoto(photo: pig.photo, size: double.infinity, radius: 0, young: pig.stage.isYoung),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0, -24, 0),
              decoration: BoxDecoration(
                color: context.palette.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(pig.displayName, style: context.text.displaySmall)),
                      StatusPill(pig.status.label, color: pig.status.color),
                    ],
                  ).enter(0),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusPill(pig.tag, color: Theme.of(context).colorScheme.primary, icon: PhosphorIconsBold.tag),
                      StatusPill(pig.sex.label, color: pig.sex == Sex.female ? AppColors.pinkDeep : AppColors.info, icon: pig.sex.icon),
                      StatusPill(pig.stage.label, color: AppColors.warning),
                      if (pig.pen.isNotEmpty) StatusPill(pig.pen, color: context.palette.inkSoft, icon: PhosphorIconsBold.squaresFour),
                    ],
                  ).enter(1),
                  if (!pig.isActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: AppCard(
                        onTap: saleId == null ? null : () => go(context, SaleDetailScreen(saleId: saleId)),
                        shadow: false,
                        color: pig.status.color.withValues(alpha: 0.08),
                        border: false,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(pig.status == PigStatus.sold ? PhosphorIconsBold.receipt : PhosphorIconsBold.warning, color: pig.status.color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${pig.status.label} on ${pig.statusDate == null ? '—' : Fmt.date(pig.statusDate!)}${pig.statusNote.isNotEmpty ? ' · ${pig.statusNote}' : ''}',
                                style: context.text.bodyMedium?.copyWith(color: pig.status.color),
                              ),
                            ),
                            if (saleId != null) Icon(PhosphorIconsBold.caretRight, size: 14, color: pig.status.color),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: 'Weight',
                          value: latest == null ? '—' : Fmt.kg(latest.kg),
                          icon: PhosphorIconsBold.scales,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Metric(
                          label: 'Age',
                          value: pig.birthDate == null ? '—' : Fmt.age(pig.birthDate!),
                          icon: PhosphorIconsBold.cake,
                          color: AppColors.pinkDeep,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Metric(
                          label: 'Daily gain',
                          value: gain == null ? '—' : '${(gain * 1000).round()} g',
                          icon: PhosphorIconsBold.trendUp,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ).enter(2),
                  if (pig.isActive) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: PhosphorIconsBold.scales,
                            label: 'Weigh',
                            onTap: () => showWeightSheet(context, pigId: pig.id),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: PhosphorIconsBold.syringe,
                            label: 'Health',
                            onTap: () => go(context, HealthFormScreen(targetType: TargetType.pig, targetId: pig.id)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: PhosphorIconsBold.receipt,
                            label: 'Sell',
                            onTap: () => go(context, NewSaleScreen(product: pig.stage.isYoung ? Product.piglet : Product.pig, pigIds: [pig.id])),
                          ),
                        ),
                      ],
                    ).enter(3),
                  ],
                  if (isBreeder) ...[
                    SectionHeader(
                      'Breeding',
                      padding: const EdgeInsets.fromLTRB(0, 24, 0, 10),
                      action: pig.isActive ? 'New service' : null,
                      onAction: () => showServiceSheet(context, sowId: pig.id),
                    ),
                    _BreedingSection(pig: pig, records: breedings),
                  ],
                  SectionHeader(
                    'Growth',
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 10),
                    action: pig.isActive ? 'Add weight' : null,
                    onAction: () => showWeightSheet(context, pigId: pig.id),
                  ),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    child: TrendChart(
                      points: [for (final w in weights) ChartPoint(Fmt.dateShort(w.date), w.kg)],
                      color: AppColors.pinkDeep,
                      format: (v) => '${v.toStringAsFixed(0)} kg',
                      showDots: true,
                    ),
                  ),
                  if (weights.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (final (i, w) in weights.reversed.take(5).indexed) ...[
                            if (i > 0) const Divider(),
                            RecordTile(
                              icon: PhosphorIconsBold.scales,
                              color: AppColors.forest,
                              title: Fmt.kg(w.kg),
                              subtitle: '${Fmt.date(w.date)}${w.notes.isNotEmpty ? ' · ${w.notes}' : ''}',
                              onLongPress: () async {
                                if (await confirm(context, title: 'Delete weight?', message: '${Fmt.kg(w.kg)} on ${Fmt.date(w.date)} will be removed.')) {
                                  await guard(() => store.deleteWeight(w.id), success: 'Deleted');
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text('Long-press a record to delete it.', style: context.text.bodySmall),
                    ),
                  ],
                  SectionHeader(
                    'Health records',
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 10),
                    action: pig.isActive ? 'Add' : null,
                    onAction: () => go(context, HealthFormScreen(targetType: TargetType.pig, targetId: pig.id)),
                  ),
                  if (health.isEmpty)
                    AppCard(child: Text('No treatments or vaccinations recorded yet.', style: context.text.bodyMedium))
                  else
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (final (i, h) in health.take(6).indexed) ...[if (i > 0) const Divider(), HealthTile(record: h, showTarget: false)],
                        ],
                      ),
                    ),
                  if (mother != null || father != null || offspring.isNotEmpty) ...[
                    const SectionHeader('Family', padding: EdgeInsets.fromLTRB(0, 24, 0, 10)),
                    SizedBox(
                      height: 112,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          if (mother != null) _FamilyChip(pig: mother, relation: 'Mother'),
                          if (father != null) _FamilyChip(pig: father, relation: 'Father'),
                          for (final o in offspring) _FamilyChip(pig: o, relation: 'Offspring'),
                        ],
                      ),
                    ),
                  ],
                  const SectionHeader('Details', padding: EdgeInsets.fromLTRB(0, 24, 0, 10)),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      children: [
                        InfoRow(label: 'Breed', value: pig.breed, icon: PhosphorIconsRegular.dna),
                        InfoRow(label: 'Born', value: pig.birthDate == null ? 'Unknown' : Fmt.date(pig.birthDate!), icon: PhosphorIconsRegular.cake),
                        InfoRow(label: pig.purchased ? 'Bought on' : 'Added on', value: Fmt.date(pig.acquiredDate), icon: PhosphorIconsRegular.calendarBlank),
                        if (pig.purchased && pig.purchasePrice != null)
                          InfoRow(label: 'Price paid', value: Fmt.money(pig.purchasePrice!), icon: PhosphorIconsRegular.money),
                        if (pig.notes.isNotEmpty) InfoRow(label: 'Notes', value: pig.notes, icon: PhosphorIconsRegular.note),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: context.text.labelSmall),
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      height: 48,
      decoration: BoxDecoration(color: context.palette.brandTint, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: context.text.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontSize: 14)),
        ],
      ),
    ),
  );
}

class _BreedingSection extends StatelessWidget {
  const _BreedingSection({required this.pig, required this.records});
  final Pig pig;
  final List<BreedingRecord> records;

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    if (records.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            const IconTile(icon: PhosphorIconsBold.heart, color: AppColors.pinkDeep),
            const SizedBox(width: 12),
            Expanded(child: Text('No services recorded. Record a service to track heat checks and farrowing.', style: context.text.bodyMedium)),
          ],
        ),
      );
    }
    final current = records.first;
    return Column(
      children: [
        BreedingCycleCard(record: current, sow: pig),
        if (records.length > 1) ...[
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final (i, b) in records.skip(1).indexed) ...[
                  if (i > 0) const Divider(),
                  RecordTile(
                    icon: PhosphorIconsBold.heart,
                    color: b.status.color,
                    title: '${b.status.label}${b.bornAlive != null ? ' · ${b.bornAlive} born alive' : ''}',
                    subtitle: 'Served ${Fmt.date(b.serviceDate)}${b.boarName.isNotEmpty ? ' · ${b.boarName}' : ''}',
                    trailing: b.weanedCount != null ? '${b.weanedCount}' : null,
                    trailingSub: b.weanedCount != null ? 'weaned' : null,
                    onLongPress: () async {
                      if (await confirm(
                        context,
                        title: 'Delete breeding record?',
                        message: 'This removes the record. Piglets already added stay in your herd.',
                      )) {
                        await guard(() => store.deleteBreeding(b.id), success: 'Deleted');
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The current cycle of a sow: gestation progress and the next action.
class BreedingCycleCard extends StatelessWidget {
  const BreedingCycleCard({super.key, required this.record, required this.sow, this.showSow = false});
  final BreedingRecord record;
  final Pig sow;
  final bool showSow;

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final b = record;
    final daysLeft = dateOnly(b.expectedFarrowing).difference(dateOnly(DateTime.now())).inDays;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showSow) ...[PigPhoto(photo: sow.photo, size: 44, radius: 12), const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(showSow ? sow.displayName : 'Current cycle', style: context.text.titleMedium),
                    Text(
                      'Served ${Fmt.date(b.serviceDate)} · ${b.method.label}${b.boarName.isNotEmpty ? ' · ${b.boarName}' : ''}',
                      style: context.text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusPill(b.status.label, color: b.status.color),
            ],
          ),
          const SizedBox(height: 16),
          if (b.status.isOpen) ...[
            Row(
              children: [
                Text('Day ${b.daysPregnant.clamp(0, 999)} of ${BreedingRecord.gestationDays}', style: context.text.labelMedium),
                const Spacer(),
                Text(
                  daysLeft > 0 ? '$daysLeft days to farrowing' : (daysLeft == 0 ? 'Due today' : 'Overdue ${-daysLeft} days'),
                  style: context.text.labelMedium?.copyWith(color: daysLeft <= 3 ? AppColors.danger : AppColors.pinkDeep),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Meter(value: b.gestationProgress, color: AppColors.pinkDeep, height: 10),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(PhosphorIconsRegular.calendarCheck, size: 14, color: context.palette.inkMuted),
                const SizedBox(width: 6),
                Text('Expected ${Fmt.dayMonth(b.expectedFarrowing)}', style: context.text.bodySmall),
              ],
            ),
            if (sow.isActive) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (b.status == BreedingStatus.served) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => guard(() => store.markReturnedToHeat(b.id), success: 'Marked as returned to heat'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        child: const Text('Not pregnant'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => guard(() => store.confirmPregnancy(b.id), success: 'Pregnancy confirmed'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        child: const Text('Pregnant'),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: PrimaryButton(
                        label: 'Record farrowing',
                        icon: PhosphorIconsBold.baby,
                        height: 48,
                        onPressed: () => showFarrowingSheet(context, b),
                      ),
                    ),
                ],
              ),
            ],
          ] else if (b.status == BreedingStatus.farrowed) ...[
            Row(
              children: [
                Expanded(
                  child: _LitterStat(value: '${b.bornAlive ?? 0}', label: 'Born alive', color: AppColors.success),
                ),
                Expanded(
                  child: _LitterStat(value: '${b.stillborn ?? 0}', label: 'Stillborn', color: AppColors.danger),
                ),
                Expanded(
                  child: _LitterStat(
                    value: b.farrowDate == null ? '—' : '${DateTime.now().difference(b.farrowDate!).inDays}d',
                    label: 'Litter age',
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Wean around ${b.expectedWeaning == null ? '—' : Fmt.dayMonth(b.expectedWeaning!)}', style: context.text.bodySmall),
            if (sow.isActive) ...[
              const SizedBox(height: 12),
              PrimaryButton(label: 'Record weaning', icon: PhosphorIconsBold.arrowsSplit, height: 48, onPressed: () => showWeaningSheet(context, b)),
            ],
          ] else ...[
            Text(
              b.status == BreedingStatus.weaned
                  ? 'Weaned ${b.weanedCount ?? 0} of ${b.bornAlive ?? 0} piglets on ${b.weanDate == null ? '—' : Fmt.date(b.weanDate!)}. Ready for the next service.'
                  : 'Returned to heat. Record a new service when she is served again.',
              style: context.text.bodyMedium,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _LitterStat extends StatelessWidget {
  const _LitterStat({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: context.text.headlineMedium?.copyWith(color: color)),
      Text(label, style: context.text.labelSmall),
    ],
  );
}

class _FamilyChip extends StatelessWidget {
  const _FamilyChip({required this.pig, required this.relation});
  final Pig pig;
  final String relation;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PigDetailScreen(pigId: pig.id))),
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            PigPhoto(photo: pig.photo, size: 48, radius: 14, young: pig.stage.isYoung),
            const SizedBox(height: 6),
            Text(
              pig.displayName,
              style: context.text.labelMedium?.copyWith(color: context.palette.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(relation, style: context.text.labelSmall),
          ],
        ),
      ),
    ),
  );
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    return CircleIconButton(
      icon: PhosphorIconsBold.dotsThreeVertical,
      tooltip: 'More',
      onTap: () async {
        final action = await showOptionsSheet<String>(
          context,
          title: pig.displayName,
          options: [
            if (pig.isActive) const PickerOption('dead', 'Record death', icon: PhosphorIconsBold.skull, color: AppColors.danger),
            if (pig.status == PigStatus.dead) const PickerOption('restore', 'Mark as alive again', icon: PhosphorIconsBold.arrowCounterClockwise),
            const PickerOption('delete', 'Delete pig', subtitle: 'Removes all its records', icon: PhosphorIconsBold.trash, color: AppColors.danger),
          ],
        );
        if (!context.mounted || action == null) return;
        switch (action) {
          case 'dead':
            await showPigDeathSheet(context, pig);
          case 'restore':
            await guard(() => store.restorePig(pig.id), success: '${pig.displayName} is active again');
          case 'delete':
            final ok = await confirm(
              context,
              title: 'Delete ${pig.displayName}?',
              message: 'Weights, breeding and health records for this pig will also be deleted. This cannot be undone.',
            );
            if (ok && context.mounted) {
              final done = await guard(() => store.deletePig(pig.id), success: 'Pig deleted');
              if (done && context.mounted) Navigator.pop(context);
            }
        }
      },
    );
  }
}
