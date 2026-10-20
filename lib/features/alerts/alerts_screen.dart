import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../core/theme/app_theme.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../home/alert_tile.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<FarmStore>().alerts;
    final urgent = alerts.where((a) => a.severity == AlertSeverity.urgent).toList();
    final rest = alerts.where((a) => a.severity != AlertSeverity.urgent).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(title: 'Alerts', subtitle: alerts.isEmpty ? 'You are all caught up' : '${alerts.length} things need your attention'),
            Expanded(
              child: alerts.isEmpty
                  ? const EmptyState(
                      image: Assets.tasksDone,
                      title: 'All caught up!',
                      message: 'Farrowing, vaccinations, low feed and debts will show here when they need you.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      children: [
                        if (urgent.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                            child: Text('Urgent', style: context.text.titleMedium),
                          ),
                          for (final (i, a) in urgent.indexed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AlertTile(alert: a).enter(i),
                            ),
                        ],
                        if (rest.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
                            child: Text('Coming up', style: context.text.titleMedium),
                          ),
                          for (final (i, a) in rest.indexed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AlertTile(alert: a).enter(i + urgent.length),
                            ),
                        ],
                        const SizedBox(height: 8),
                        Center(child: Text('Swipe left on an alert to dismiss it.', style: context.text.bodySmall)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
