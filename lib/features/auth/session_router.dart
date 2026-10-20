import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../onboarding/onboarding_screen.dart';
import '../shell/main_shell.dart';
import 'farm_setup_screen.dart';
import 'login_screen.dart';

/// Replaces the whole navigation stack with [page] using a soft fade.
void replaceAll(BuildContext context, Widget page) {
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 1.03, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ),
    (_) => false,
  );
}

/// Decides where a user lands: onboarding → login → farm setup → home.
Future<void> goToNextStep(BuildContext context) async {
  final auth = context.read<AuthController>();
  final store = context.read<FarmStore>();
  Widget page;
  if (!auth.onboardingSeen) {
    page = const OnboardingScreen();
  } else if (!auth.isLoggedIn) {
    page = const LoginScreen();
  } else {
    final ok = await guard(() => store.open(auth.user!.id), haptic: false);
    if (!context.mounted) return;
    if (!ok) {
      page = const LoginScreen();
    } else {
      page = store.hasFarm ? const MainShell() : const FarmSetupScreen();
    }
  }
  if (context.mounted) replaceAll(context, page);
}

Future<void> logout(BuildContext context) async {
  final auth = context.read<AuthController>();
  final store = context.read<FarmStore>();
  await auth.logout();
  store.close();
  if (context.mounted) replaceAll(context, const LoginScreen());
}
