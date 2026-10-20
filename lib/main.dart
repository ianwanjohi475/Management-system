import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/errors/app_exception.dart';
import 'data/storage/local_db.dart';
import 'features/system/startup_error_screen.dart';
import 'state/auth_controller.dart';
import 'state/farm_store.dart';
import 'widgets/feedback.dart';

Future<void> main() async {
  // Catch everything: framework errors, async errors and errors outside Flutter.
  runZonedGuarded(_start, (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    showToast(friendlyError(error), type: ToastType.error);
  });
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) debugPrint('Flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform error: $error\n$stack');
    showToast(friendlyError(error), type: ToastType.error);
    return true;
  };
  // A broken widget shows a calm card instead of the red error screen.
  ErrorWidget.builder = (details) => SafeErrorWidget(details: details);

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]).catchError((_) {});
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));

  final auth = AuthController();
  final store = FarmStore();
  try {
    await LocalDb.init();
    await auth.init();
    if (auth.user != null) await store.open(auth.user!.id);
  } catch (e, st) {
    debugPrint('Startup failed: $e\n$st');
    runApp(StartupErrorApp(error: e, onRetry: _start));
    return;
  }
  runApp(ShambaApp(auth: auth, store: store));
}
