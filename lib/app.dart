// lib/app.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:threads/screens/auth/auth_gate.dart';

class ThreadsApp extends StatelessWidget {
  const ThreadsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveApp(
      title: 'Threads',
      home: const AuthGate(),
      cupertinoLightTheme: const CupertinoThemeData(
        primaryColor: CupertinoColors.black,
      ),
      cupertinoDarkTheme: const CupertinoThemeData(
        primaryColor: CupertinoColors.white,
      ),
    );
  }
}
