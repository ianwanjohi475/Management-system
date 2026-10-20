import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../auth/session_router.dart';

/// Animated intro: the logo pops, a hen walks in pecking, the pig bounces up,
/// an egg drops, then the wordmark and tagline slide in.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _pecking = false;
  Timer? _peck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final a in Assets.all) {
        precacheImage(AssetImage(a), context).catchError((_) {});
      }
    });
    _peck = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (mounted) setState(() => _pecking = !_pecking);
    });
    _timer = Timer(const Duration(milliseconds: 3400), () {
      if (mounted) goToNextStep(context);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _peck?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width.clamp(280.0, 480.0);
    return Scaffold(
      backgroundColor: context.palette.background,
      body: Stack(
        children: [
          // Soft green glow behind everything.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 0.9,
                  colors: [
                    AppColors.lime.withValues(alpha: context.isDark ? 0.18 : 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 900.ms),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                // Logo
                Image.asset(Assets.logoMark, width: w * 0.32)
                    .animate()
                    .scale(begin: const Offset(0, 0), end: const Offset(1, 1), duration: 800.ms, curve: Curves.elasticOut)
                    .then(delay: 200.ms)
                    .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(height: 22),
                // Wordmark
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Shamba',
                        style: TextStyle(color: context.isDark ? Colors.white : AppColors.forestDark),
                      ),
                      const TextSpan(
                        text: '.',
                        style: TextStyle(color: AppColors.amber),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1),
                ).animate(delay: 500.ms).fadeIn(duration: 500.ms).slideY(begin: 0.4, end: 0, curve: Curves.easeOutBack),
                const SizedBox(height: 10),
                Text(
                  'Your farm, in your pocket.',
                  style: context.text.bodyLarge?.copyWith(color: context.palette.inkSoft),
                ).animate(delay: 800.ms).fadeIn(duration: 500.ms),
                const Spacer(flex: 2),
                // Farm scene
                SizedBox(
                  height: w * 0.62,
                  width: w,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned(
                        bottom: 0,
                        left: w * 0.05,
                        right: w * 0.05,
                        child: Image.asset(Assets.grass, height: w * 0.2, fit: BoxFit.fill)
                            .animate(delay: 300.ms)
                            .fadeIn(duration: 400.ms)
                            .scaleY(begin: 0, end: 1, alignment: Alignment.bottomCenter, curve: Curves.easeOutBack),
                      ),
                      // Pig pops up on the right
                      Positioned(
                        bottom: w * 0.05,
                        right: w * 0.06,
                        child: Image.asset(Assets.pig, width: w * 0.42)
                            .animate(delay: 900.ms)
                            .fadeIn(duration: 200.ms)
                            .moveY(begin: 60, end: 0, duration: 650.ms, curve: Curves.elasticOut)
                            .then()
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .moveY(begin: 0, end: -6, duration: 700.ms, curve: Curves.easeInOut),
                      ),
                      // Hen walks in from the left and pecks
                      Positioned(
                        bottom: w * 0.05,
                        left: w * 0.08,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 120),
                          child: Image.asset(_pecking ? Assets.henPecking : Assets.hen, key: ValueKey(_pecking), width: w * 0.3),
                        ).animate(delay: 600.ms).fadeIn(duration: 200.ms).moveX(begin: -w * 0.6, end: 0, duration: 1100.ms, curve: Curves.easeOutCubic),
                      ),
                      // Egg drops into the middle
                      Positioned(
                        bottom: w * 0.06,
                        left: w * 0.43,
                        child: Image.asset(Assets.egg, width: w * 0.1)
                            .animate(delay: 1500.ms)
                            .fadeIn(duration: 100.ms)
                            .moveY(begin: -w * 0.5, end: 0, duration: 700.ms, curve: Curves.bounceOut)
                            .then()
                            .shake(hz: 3, rotation: 0.06, duration: 400.ms),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _LoadingDots().animate(delay: 1200.ms).fadeIn(),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      3,
      (i) =>
          Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(color: AppColors.forest, shape: BoxShape.circle),
              )
              .animate(onPlay: (c) => c.repeat())
              .scaleXY(begin: 0.6, end: 1.2, delay: (i * 160).ms, duration: 480.ms, curve: Curves.easeInOut)
              .then()
              .scaleXY(begin: 1.2, end: 0.6, duration: 480.ms),
    ),
  );
}
