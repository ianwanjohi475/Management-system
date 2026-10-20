import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants/assets.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/phosphor.dart';
import '../core/utils/formatters.dart';
import 'buttons.dart';

/// Staggered entrance used across lists and dashboards.
extension EnterX on Widget {
  Widget enter(int index, {double dy = 0.08}) => animate()
      .fadeIn(duration: 380.ms, delay: (40 * index.clamp(0, 12)).ms, curve: Curves.easeOut)
      .slideY(begin: dy, end: 0, duration: 420.ms, delay: (40 * index.clamp(0, 12)).ms, curve: Curves.easeOutCubic);
}

/// Pushes [page] with a smooth fade + slide.
Future<T?> go<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(
  PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, a, _, child) {
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  ),
);

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = 20,
    this.border = true,
    this.shadow = true,
    this.gradient,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final bool border;
  final bool shadow;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? p.card) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border && gradient == null ? Border.all(color: p.border.withValues(alpha: context.isDark ? 1 : 0.7)) : null,
        boxShadow: shadow ? [BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 8))] : null,
      ),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, scale: 0.98, child: box);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(20, 24, 12, 12)});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(child: Text(title, style: context.text.titleLarge)),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Text(action!), const SizedBox(width: 2), const Icon(PhosphorIconsBold.caretRight, size: 13)]),
          ),
      ],
    ),
  );
}

/// Rounded square tile holding an icon in a tinted background.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.color, this.size = 44, this.radius = 14, this.iconSize});

  final IconData icon;
  final Color color;
  final double size;
  final double radius;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: context.isDark ? 0.2 : 0.13),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(icon, color: color, size: iconSize ?? size * 0.48),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, required this.color, this.icon, this.solid = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: solid ? color : color.withValues(alpha: context.isDark ? 0.22 : 0.13),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 12, color: solid ? Colors.white : color), const SizedBox(width: 4)],
        Text(
          label,
          style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: solid ? Colors.white : color, letterSpacing: 0.2),
        ),
      ],
    ),
  );
}

/// Number that counts up when it first appears or changes.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, this.style, this.format, this.duration = const Duration(milliseconds: 900)});

  final num value;
  final TextStyle? style;
  final String Function(num)? format;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: duration,
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Text(format != null ? format!(v) : Fmt.number(v.round()), style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

/// Small metric card: icon, value, label, optional trend.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.format,
    this.caption,
    this.onTap,
    this.image,
  });

  final IconData icon;
  final Color color;
  final num value;
  final String label;
  final String Function(num)? format;
  final String? caption;
  final VoidCallback? onTap;
  final String? image;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              image != null ? Image.asset(image!, width: 40, height: 40) : IconTile(icon: icon, color: color, size: 40, radius: 12),
              const Spacer(),
              if (onTap != null) Icon(PhosphorIconsBold.arrowUpRight, size: 16, color: context.palette.inkMuted),
            ],
          ),
          const SizedBox(height: 12),
          CountUp(value: value, format: format, style: context.text.headlineMedium?.copyWith(fontSize: 21)),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.text.bodySmall?.copyWith(color: context.palette.inkSoft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(
              caption!,
              style: context.text.labelSmall?.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.icon, this.valueColor, this.bold = false});

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: context.palette.inkMuted), const SizedBox(width: 10)],
        Expanded(child: Text(label, style: context.text.bodyMedium)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: (bold ? context.text.titleMedium : context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500))?.copyWith(color: valueColor),
          ),
        ),
      ],
    ),
  );
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.initials, this.size = 44, this.color = AppColors.forest});

  final String initials;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [color, Color.lerp(color, AppColors.lime, 0.5)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
      shape: BoxShape.circle,
    ),
    child: Text(
      initials,
      style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600, fontSize: size * 0.36),
    ),
  );
}

final _photoCache = <String, Uint8List>{};

/// Shows a pig's photo, or the illustrated pig when there isn't one.
class PigPhoto extends StatelessWidget {
  const PigPhoto({super.key, required this.photo, this.size = 56, this.radius = 16, this.young = false});

  final String? photo;
  final double size;
  final double radius;
  final bool young;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    if (photo != null) {
      try {
        bytes = _photoCache[photo!] ??= base64Decode(photo!);
      } catch (_) {
        bytes = null;
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: AppColors.pinkSoft.withValues(alpha: context.isDark ? 0.15 : 1),
        child: bytes != null ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => _fallback()) : _fallback(),
      ),
    );
  }

  Widget _fallback() => Padding(
    padding: EdgeInsets.all(size.isFinite ? size * 0.12 : 14),
    child: Image.asset(young ? Assets.prodPiglet : Assets.pig, fit: BoxFit.contain),
  );
}

/// Thin rounded progress bar.
class Meter extends StatelessWidget {
  const Meter({super.key, required this.value, this.color = AppColors.forest, this.height = 8});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: Stack(
      children: [
        Container(height: height, color: color.withValues(alpha: 0.14)),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => FractionallySizedBox(
            widthFactor: v,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.25)!]),
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Horizontal filter chips that scroll.
class FilterChips<T> extends StatelessWidget {
  const FilterChips({super.key, required this.items, required this.value, required this.onChanged, this.padding = const EdgeInsets.symmetric(horizontal: 20)});

  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (v, label) = items[i];
          final sel = v == value;
          return Pressable(
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? scheme.primary : p.card,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: sel ? scheme.primary : p.border),
              ),
              child: Text(label, style: context.text.labelMedium?.copyWith(color: sel ? scheme.onPrimary : p.inkSoft)),
            ),
          );
        },
      ),
    );
  }
}

/// Pinned header for detail pages and simple screens.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const [], this.showBack = true});

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        if (showBack) ...[const BackButtonX(), const SizedBox(width: 12)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: context.text.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null) Text(subtitle!, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        for (final a in actions) ...[const SizedBox(width: 8), a],
      ],
    ),
  );
}

/// Shows a bottom-sheet form that respects the keyboard.
Future<T?> showFormSheet<T>(BuildContext context, {required String title, String? subtitle, required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: ctx.text.headlineSmall),
              if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle, style: ctx.text.bodyMedium)],
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

/// Timeline-style list row with an icon, two lines and a trailing value.
class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingSub,
    this.onTap,
    this.onLongPress,
    this.leading,
    this.trailingColor,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? trailing;
  final String? trailingSub;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? leading;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            leading ?? IconTile(icon: icon, color: color, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(trailing!, style: context.text.titleMedium?.copyWith(color: trailingColor)),
                  if (trailingSub != null) Text(trailingSub!, style: context.text.bodySmall),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
