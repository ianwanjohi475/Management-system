import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../core/constants/assets.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../widgets/widgets.dart';

/// Shown if the database can't open at launch. Offers retry and, as a last resort, a reset.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    scaffoldMessengerKey: messengerKey,
    home: _StartupError(error: error, onRetry: onRetry),
  );
}

class _StartupError extends StatefulWidget {
  const _StartupError({required this.error, required this.onRetry});
  final Object error;
  final Future<void> Function() onRetry;

  @override
  State<_StartupError> createState() => _StartupErrorState();
}

class _StartupErrorState extends State<_StartupError> {
  bool _busy = false;

  Future<void> _reset() async {
    final ok = await confirm(
      context,
      title: 'Reset app storage?',
      message: 'This deletes all data saved on this phone. Only do this if retrying does not work and you have a backup.',
      confirmLabel: 'Reset',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Hive.deleteFromDisk();
    } catch (_) {}
    await widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Image.asset(Assets.offlineHen, height: 180),
              const SizedBox(height: 24),
              Text("Shamba couldn't start", style: context.text.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(friendlyError(widget.error), style: context.text.bodyMedium, textAlign: TextAlign.center),
              if (kDebugMode) ...[const SizedBox(height: 8), Text('${widget.error}', style: context.text.bodySmall, textAlign: TextAlign.center)],
              const Spacer(),
              PrimaryButton(
                label: 'Try again',
                icon: PhosphorIconsBold.arrowClockwise,
                loading: _busy,
                onPressed: () async {
                  setState(() => _busy = true);
                  await widget.onRetry();
                  if (mounted) setState(() => _busy = false);
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : _reset,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Reset app storage'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Replaces Flutter's red error box with something calm.
class SafeErrorWidget extends StatelessWidget {
  const SafeErrorWidget({super.key, required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsBold.warningCircle, color: AppColors.danger, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                kDebugMode ? details.exceptionAsString() : 'This part could not be shown.',
                style: const TextStyle(color: AppColors.danger, fontSize: 13, fontFamily: 'Inter'),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
