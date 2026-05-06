import 'package:apptest_messaging/core/config.dart';
import 'package:apptest_messaging/core/sqlite_init.dart';
import 'package:apptest_messaging/features/profile/home_screen.dart';
import 'package:apptest_messaging/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await maybeApplySqliteAndroidWorkaround();

  // Fail fast if API base URL missing (except during tests).
  requireApiBaseUrl();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: MessagingApp()));
}

class MessagingApp extends StatelessWidget {
  const MessagingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'apptest_messaging',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
