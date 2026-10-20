import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/constants/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../state/auth_controller.dart';
import '../../widgets/widgets.dart';
import '../auth/session_router.dart';

class _Slide {
  const _Slide(this.image, this.kicker, this.title, this.body, this.color);
  final String image;
  final String kicker;
  final String title;
  final String body;
  final Color color;
}

const _slides = [
  _Slide(
    Assets.onboardTrack,
    'RECORDS',
    'Track every pig\nand every bird',
    'Tags, weights, breeding, litters and flocks, all in one place. No more notebooks.',
    AppColors.lime,
  ),
  _Slide(
    Assets.onboardVaccine,
    'REMINDERS',
    'Never miss a\nvaccine again',
    'Farrowing dates, heat checks, vaccinations and low feed: Shamba reminds you before it is too late.',
    AppColors.amber,
  ),
  _Slide(
    Assets.onboardProfit,
    'MONEY',
    'Sell more,\nknow your profit',
    'Record sales of eggs, chicken and pigs, track who owes you, and see exactly what your farm earns.',
    AppColors.pink,
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await guard(() => context.read<AuthController>().setOnboardingSeen(), haptic: false);
    if (mounted) goToNextStep(context);
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Image.asset(Assets.logoWordmark, height: 34),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: last ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(onPressed: last ? null : _finish, child: const Text('Skip')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i], active: i == _page),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _slides.length,
                    effect: ExpandingDotsEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3.5,
                      spacing: 6,
                      activeDotColor: Theme.of(context).colorScheme.primary,
                      dotColor: context.palette.border,
                    ),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: last ? 180 : 64,
                    child: PrimaryButton(
                      label: last ? 'Get started' : '',
                      semanticLabel: last ? null : 'Next',
                      icon: last ? null : PhosphorIconsBold.arrowRight,
                      height: 60,
                      onPressed: () {
                        if (last) {
                          _finish();
                        } else {
                          _controller.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.active});
  final _Slide slide;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final imgH = (size.height * 0.4).clamp(220.0, 400.0);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: imgH + 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: imgH * 0.95,
                height: imgH * 0.95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: slide.color.withValues(alpha: context.isDark ? 0.14 : 0.2),
                ),
              ).animate(target: active ? 1 : 0).scaleXY(begin: 0.85, end: 1, duration: 600.ms, curve: Curves.easeOutBack),
              Image.asset(slide.image, height: imgH)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -8, duration: 2200.ms, curve: Curves.easeInOut)
                  .animate(target: active ? 1 : 0)
                  .fadeIn(duration: 400.ms)
                  .moveY(begin: 24, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(slide.kicker, style: context.text.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, letterSpacing: 2.2, fontSize: 12)),
        const SizedBox(height: 10),
        Text(slide.title, style: context.text.displayMedium),
        const SizedBox(height: 14),
        Text(slide.body, style: context.text.bodyLarge?.copyWith(color: context.palette.inkSoft)),
      ],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: active ? content.animate().fadeIn(duration: 350.ms) : content,
    );
  }
}
