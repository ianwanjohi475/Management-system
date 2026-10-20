import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import 'pig_detail_screen.dart';
import 'pig_sheets.dart';

class BreedingScreen extends StatefulWidget {
  const BreedingScreen({super.key});

  @override
  State<BreedingScreen> createState() => _BreedingScreenState();
}

class _BreedingScreenState extends State<BreedingScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final all = store.breedings.where((b) => store.pig(b.sowId) != null).toList();
    final list = switch (_filter) {
      0 => all.where((b) => b.status.isOpen).toList()..sort((a, b) => a.expectedFarrowing.compareTo(b.expectedFarrowing)),
      1 => all.where((b) => b.status == BreedingStatus.farrowed).toList(),
      _ => all.where((b) => !b.status.isOpen && b.status != BreedingStatus.farrowed).toList(),
    };
    final litters = all.where((b) => b.bornAlive != null).toList();
    final avgBorn = litters.isEmpty ? 0.0 : litters.fold(0, (s, b) => s + b.bornAlive!) / litters.length;
    final weaned = all.where((b) => b.weanedCount != null).toList();
    final avgWeaned = weaned.isEmpty ? 0.0 : weaned.fold(0, (s, b) => s + b.weanedCount!) / weaned.length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showServiceSheet(context),
        icon: const Icon(PhosphorIconsBold.heart),
        label: const Text('Record service'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: PageHeader(title: 'Breeding & litters', subtitle: '114-day gestation tracking'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(icon: PhosphorIconsBold.baby, color: AppColors.pinkDeep, value: litters.length, label: 'Litters'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        icon: PhosphorIconsBold.heart,
                        color: AppColors.success,
                        value: avgBorn,
                        format: (v) => v.toStringAsFixed(1),
                        label: 'Avg born',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        icon: PhosphorIconsBold.arrowsSplit,
                        color: AppColors.info,
                        value: avgWeaned,
                        format: (v) => v.toStringAsFixed(1),
                        label: 'Avg weaned',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FilterChips<int>(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
                items: [
                  (0, 'Served & pregnant (${all.where((b) => b.status.isOpen).length})'),
                  (1, 'Nursing (${all.where((b) => b.status == BreedingStatus.farrowed).length})'),
                  (2, 'History'),
                ],
              ),
            ),
            if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  image: Assets.prodPiglet,
                  title: _filter == 0 ? 'No sows in service' : (_filter == 1 ? 'No nursing litters' : 'No history yet'),
                  message: _filter == 0 ? 'Record a service to start tracking a pregnancy.' : 'Records will appear here as cycles progress.',
                  compact: true,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final b = list[i];
                    final sow = store.pig(b.sowId)!;
                    return GestureDetector(
                      onTap: () => go(context, PigDetailScreen(pigId: sow.id)),
                      child: _filter == 2
                          ? AppCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              child: RecordTile(
                                leading: PigPhoto(photo: sow.photo, size: 44, radius: 12),
                                icon: PhosphorIconsBold.heart,
                                color: b.status.color,
                                title: '${sow.displayName} · ${b.status.label}',
                                subtitle: 'Served ${Fmt.date(b.serviceDate)}${b.bornAlive != null ? ' · ${b.bornAlive} born' : ''}',
                                trailing: b.weanedCount?.toString(),
                                trailingSub: b.weanedCount != null ? 'weaned' : null,
                              ),
                            )
                          : BreedingCycleCard(record: b, sow: sow, showSow: true),
                    ).enter(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
