import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/widgets.dart';

/// Green curved header with the farmer, like the Foodie login.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, this.showBack = false, this.compact = false, this.image = Assets.heroFarmer});

  final bool showBack;
  final bool compact;
  final String image;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final h = (compact ? 200.0 : 290.0) + top;
    return SizedBox(
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: _CurveClipper(),
              child: Container(
                decoration: const BoxDecoration(gradient: AppColors.heroGradient),
                child: Stack(
                  children: [
                    // Soft decorative circles.
                    Positioned(
                      left: -60,
                      bottom: -40,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
                      ),
                    ),
                    Positioned(
                      right: 40,
                      top: top - 30,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.lime.withValues(alpha: 0.18)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -8,
            bottom: compact ? 4 : 0,
            child: Image.asset(image, height: h * (compact ? 0.78 : 0.86))
                .animate()
                .fadeIn(duration: 500.ms)
                .moveX(begin: 60, end: 0, duration: 700.ms, curve: Curves.easeOutCubic)
                .then()
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -6, duration: 2200.ms, curve: Curves.easeInOut),
          ),
          Positioned(
            left: 24,
            top: top + (showBack ? 64 : 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(text: 'Shamba'),
                      TextSpan(
                        text: '.',
                        style: TextStyle(color: AppColors.amber),
                      ),
                    ],
                  ),
                  style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: compact ? 28 : 34, fontWeight: FontWeight.w800, letterSpacing: -1),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pigs. Poultry.\nProfit, made simple.',
                  style: TextStyle(fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.82), fontSize: 13.5, height: 1.4),
                ),
              ],
            ).animate().fadeIn(duration: 500.ms, delay: 150.ms).slideX(begin: -0.1, end: 0),
          ),
          if (showBack) Positioned(left: 16, top: top + 8, child: const BackButtonX(light: true)),
        ],
      ),
    );
  }
}

class _CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(0, s.height - 40)
    ..quadraticBezierTo(s.width * 0.25, s.height, s.width * 0.55, s.height - 22)
    ..quadraticBezierTo(s.width * 0.85, s.height - 44, s.width, s.height - 12)
    ..lineTo(s.width, 0)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
