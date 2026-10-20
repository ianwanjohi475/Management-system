import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants/assets.dart';
import '../core/errors/app_exception.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/phosphor.dart';
import 'buttons.dart';

/// Lets any code show a toast without a BuildContext.
final messengerKey = GlobalKey<ScaffoldMessengerState>();

enum ToastType { success, error, info }

void showToast(String message, {ToastType type = ToastType.success, String? actionLabel, VoidCallback? onAction}) {
  final m = messengerKey.currentState;
  if (m == null) return;
  final (icon, color) = switch (type) {
    ToastType.success => (PhosphorIconsFill.checkCircle, AppColors.lime),
    ToastType.error => (PhosphorIconsFill.warningCircle, const Color(0xFFFF8A80)),
    ToastType.info => (PhosphorIconsFill.info, AppColors.amber),
  };
  if (type == ToastType.error) HapticFeedback.heavyImpact();
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: Duration(milliseconds: type == ToastType.error ? 4500 : 2600),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        content: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13.5, height: 1.35),
              ),
            ),
          ],
        ),
        action: actionLabel == null ? null : SnackBarAction(label: actionLabel, textColor: AppColors.amber, onPressed: onAction ?? () {}),
      ),
    );
}

/// Runs [action], shows a friendly toast on failure, and returns whether it succeeded.
///
/// Every button that writes data goes through this, so no error is ever silent.
Future<bool> guard(Future<void> Function() action, {String? success, bool haptic = true}) async {
  try {
    await action();
    if (haptic) HapticFeedback.lightImpact();
    if (success != null) showToast(success);
    return true;
  } catch (e, st) {
    if (e is! AppException) debugPrint('Unexpected error: $e\n$st');
    showToast(friendlyError(e), type: ToastType.error);
    return false;
  }
}

/// Runs a long job behind a branded, non-dismissable loading card.
Future<T> withBusy<T>(BuildContext context, String message, Future<T> Function() job) async {
  final nav = Navigator.of(context, rootNavigator: true);
  var open = true;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) => PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: ctx.palette.card,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  Assets.henPecking,
                  height: 96,
                ).animate(onPlay: (c) => c.repeat(reverse: true)).rotate(begin: -0.03, end: 0.05, duration: 420.ms, alignment: Alignment.bottomCenter),
                const SizedBox(height: 18),
                SizedBox(width: 160, child: LinearProgressIndicator(borderRadius: BorderRadius.circular(4), minHeight: 5)),
                const SizedBox(height: 14),
                Text(message, style: ctx.text.titleSmall, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 200.ms).scaleXY(begin: 0.92, end: 1, curve: Curves.easeOutBack),
    ),
  ).whenComplete(() => open = false);
  try {
    return await job();
  } finally {
    if (open && nav.mounted) nav.pop();
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
  IconData? icon,
}) async {
  final p = context.palette;
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: (destructive ? AppColors.danger : AppColors.forest).withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(
                icon ?? (destructive ? PhosphorIconsBold.trash : PhosphorIconsBold.question),
                color: destructive ? AppColors.danger : AppColors.forest,
                size: 28,
              ),
            ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 18),
            Text(title, style: ctx.text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: ctx.text.bodyMedium?.copyWith(color: p.inkSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: destructive ? AppColors.danger : AppColors.forest,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return res ?? false;
}

/// Friendly illustration + message for lists with nothing in them.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.image,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = PhosphorIconsBold.plus,
    this.compact = false,
  });

  final String image;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 16 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              image,
              height: compact ? 120 : 170,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: -6, duration: 1800.ms, curve: Curves.easeInOut),
            SizedBox(height: compact ? 12 : 20),
            Text(title, style: context.text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: context.text.bodyMedium, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 220,
                child: PrimaryButton(label: actionLabel!, icon: actionIcon, onPressed: onAction, height: 50),
              ),
            ],
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0),
      ),
    );
  }
}

/// Shown when something failed to load; always offers a way forward.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry, this.title = "We couldn't load this"});

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    image: Assets.offlineHen,
    title: title,
    message: message,
    actionLabel: onRetry == null ? null : 'Try again',
    onAction: onRetry,
    actionIcon: PhosphorIconsBold.arrowClockwise,
  );
}
