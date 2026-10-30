// lib/screens/auth/auth_gate.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/data/auth_repository.dart';
import 'package:threads/screens/auth/login_screen.dart';
import 'package:threads/screens/settings/change_password_screen.dart';
import 'package:threads/screens/shell/main_shell.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _recoveryPresented = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.passwordRecovery)
        _openChangePassword();
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkPendingRecovery(),
    );
  }

  Future<void> _checkPendingRecovery() async {
    if (!mounted || Supabase.instance.client.auth.currentSession == null)
      return;
    final pending = await AuthRepository.takePendingPasswordRecovery();
    if (pending) _openChangePassword();
  }

  void _openChangePassword() {
    if (!mounted || _recoveryPresented) return;
    _recoveryPresented = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true)
          .pushAndRemoveUntil(
            adaptivePageRoute<void>((_) => const ChangePasswordScreen()),
            (route) => route.isFirst,
          )
          .then((_) {
            if (mounted) _recoveryPresented = false;
          });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watching the stream rebuilds this widget on every sign-in and sign-out.
    ref.watch(authStateProvider);
    final session = Supabase.instance.client.auth.currentSession;
    return session == null ? const LoginScreen() : const MainShell();
  }
}
