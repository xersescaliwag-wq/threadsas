// lib/main.dart
import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:threads/app.dart';
import 'package:threads/core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (_) {}

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const ProviderScope(child: ThreadsApp()));
}
