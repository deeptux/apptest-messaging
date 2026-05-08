import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:apptest_messaging/core/config.dart';
import 'package:apptest_messaging/core/cross_tab_auth_sync.dart';
import 'package:apptest_messaging/core/inactivity_logout.dart';
import 'package:apptest_messaging/core/sqlite_init.dart';
import 'package:apptest_messaging/features/profile/home_screen.dart';
import 'package:apptest_messaging/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show FlutterError, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _globalFatalRecoveryInstalled = false;

/// Replaces the widget tree once so the user always sees an explanation instead
/// of a blank canvas (common on Flutter web when an error bypasses [runZonedGuarded]).
void _recoverFromFatalOnce(Object error, StackTrace stack) {
  if (_globalFatalRecoveryInstalled) return;
  _globalFatalRecoveryInstalled = true;
  FlutterError.dumpErrorToConsole(
    FlutterErrorDetails(exception: error, stack: stack),
  );
  runApp(
    MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE11D48),
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Something went wrong')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'The app hit an unexpected error. Try a full page reload '
                    '(or clear this site’s data if it keeps happening).',
                  ),
                  const SizedBox(height: 16),
                  SelectionArea(
                    child: Text(
                      kDebugMode ? '$error\n\n$stack' : '$error',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PlatformDispatcher.instance.onError = (error, stack) {
    _recoverFromFatalOnce(error, stack);
    return true;
  };

  ErrorWidget.builder = (details) {
    return Material(
      color: const Color(0xFF0B0B0F),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            details.exceptionAsString(),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() async {
    await maybeApplySqliteAndroidWorkaround();

    // Fail fast if API base URL missing (except during tests).
    requireApiBaseUrl();

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    runApp(const ProviderScope(child: MessagingApp()));
  }, (e, st) {
    _recoverFromFatalOnce(e, st);
  });
}

class MessagingApp extends StatelessWidget {
  const MessagingApp({super.key});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE11D48);
    const bg = Color(0xFF0B0B0F);
    return MaterialApp(
      title: 'apptest_messaging',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: red,
          brightness: Brightness.dark,
          surface: bg,
        ),
        scaffoldBackgroundColor: bg,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F16),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF101018),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF101018),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide.none,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: red,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
      ),
      home: const CrossTabAuthSync(
        child: InactivityLogout(
          child: HomeScreen(),
        ),
      ),
    );
  }
}
