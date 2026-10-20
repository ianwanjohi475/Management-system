import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/phosphor.dart';

/// Shrinks slightly while pressed, like premium apps do.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.97});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 120), curve: Curves.easeOut, child: widget.child),
    );
  }
}

/// The big green gradient call-to-action with a built-in loading state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.loading = false, this.icon, this.height = 56, this.color, this.semanticLabel});

  final String label;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? (label.isEmpty ? null : label),
      excludeSemantics: true,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: height,
          decoration: BoxDecoration(
            gradient: color == null
                ? (enabled || loading
                      ? AppColors.buttonGradient
                      : LinearGradient(colors: [AppColors.forest.withValues(alpha: 0.35), AppColors.forest.withValues(alpha: 0.35)]))
                : null,
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled ? [BoxShadow(color: (color ?? AppColors.forest).withValues(alpha: 0.32), blurRadius: 18, offset: const Offset(0, 8))] : null,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: a, child: c),
            ),
            child: loading
                ? const SizedBox(
                    key: ValueKey('l'),
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                  )
                : Row(
                    key: const ValueKey('t'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), if (label.isNotEmpty) const SizedBox(width: 10)],
                      if (label.isNotEmpty)
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// White button with a brand logo, used for "Continue with Google".
class SocialButton extends StatelessWidget {
  const SocialButton({super.key, required this.label, required this.icon, required this.onPressed, this.iconColor});

  final String label;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: iconColor ?? p.ink),
            const SizedBox(width: 10),
            Text(label, style: context.text.labelLarge?.copyWith(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

/// Round icon button with a soft background (back, more, close…).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, this.onTap, this.size = 44, this.background, this.color, this.tooltip, this.badge = false});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? background;
  final Color? color;
  final String? tooltip;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final btn = Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background ?? p.card,
          shape: BoxShape.circle,
          border: background == null ? Border.all(color: p.border) : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: size * 0.46, color: color ?? p.ink),
            if (badge)
              Positioned(
                top: size * 0.22,
                right: size * 0.24,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: background ?? p.card, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class BackButtonX extends StatelessWidget {
  const BackButtonX({super.key, this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context) => CircleIconButton(
    icon: PhosphorIconsBold.caretLeft,
    tooltip: 'Back',
    background: light ? Colors.white.withValues(alpha: 0.22) : null,
    color: light ? Colors.white : null,
    onTap: () => Navigator.maybePop(context),
  );
}
