// lib/app.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show DefaultMaterialLocalizations, ThemeMode;
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
      // mode pinned avoids the washed-out, white-on-white UI the system light
      // theme produced on iOS (and the accidental light flash at launch).
      themeMode: ThemeMode.dark,
      // `AdaptiveScaffold` wraps its iOS page in a transparent Material
      // Scaffold so it can host a drawer, and Material's DrawerController
      // needs MaterialLocalizations. CupertinoApp only installs the Cupertino
      // delegate, so without this the drawer throws when it is built/open.
      localizationsDelegates: const [DefaultMaterialLocalizations.delegate],
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
