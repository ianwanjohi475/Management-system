import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/system/not_found_screen.dart';
import 'state/auth_controller.dart';
import 'state/farm_store.dart';
import 'widgets/feedback.dart';

class ShambaApp extends StatelessWidget {
  const ShambaApp({super.key, required this.auth, required this.store});

  final AuthController auth;
  final FarmStore store;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: store),
      ],
      child: Selector<AuthController, ThemeMode>(
        selector: (_, a) => a.themeMode,
        builder: (_, mode, _) => MaterialApp(
          title: 'Shamba.',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: messengerKey,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const SplashScreen(),
          onUnknownRoute: (_) => MaterialPageRoute(builder: (_) => const NotFoundScreen()),
          builder: (context, child) {
            // Keep text readable but stop huge system fonts from breaking layouts.
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3)),
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}
