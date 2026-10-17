// lib/app.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:threads/core/adaptive.dart';
import 'package:threads/screens/auth/auth_gate.dart';

class ThreadsApp extends StatelessWidget {
  const ThreadsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveApp(
      title: 'Threads',
      home: const AuthGate(),
      // The supplied reference is a dark-first Threads experience. Keeping the
      // mode explicit also avoids an accidental light flash when the device is
      // configured for light appearance.
      themeMode: ThemeMode.dark,
      materialLightTheme: materialAppTheme(Brightness.light),
      materialDarkTheme: materialAppTheme(Brightness.dark),
      cupertinoLightTheme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.black,
        scaffoldBackgroundColor: CupertinoColors.white,
      ),
      cupertinoDarkTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: CupertinoColors.white,
        scaffoldBackgroundColor: CupertinoColors.black,
        barBackgroundColor: CupertinoColors.black,
      ),
    );
  }
}
