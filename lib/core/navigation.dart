// lib/core/navigation.dart
import 'package:flutter/widgets.dart';
import 'package:threads/core/adaptive.dart';

/// Opens a screen with the standard iOS slide transition on iOS and a
/// Material page transition on Android.
Future<T?> openScreen<T>(
  BuildContext context,
  Widget screen, {
  bool fullscreen = false,
}) {
  return Navigator.of(context).push<T>(
    adaptivePageRoute<T>(
      (_) => screen,
      fullscreen: fullscreen,
    ),
  );
}