// lib/screens/auth/auth_gate.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/screens/auth/login_screen.dart';
import 'package:threads/screens/shell/main_shell.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the stream rebuilds this widget on every sign-in and sign-out.
    ref.watch(authStateProvider);
    final session = Supabase.instance.client.auth.currentSession;
    return session == null ? const LoginScreen() : const MainShell();
  }
}
