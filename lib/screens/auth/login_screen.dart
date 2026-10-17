// lib/screens/auth/login_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/screens/auth/sign_up_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    if (_busy) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      await showMessage(context, 'Missing details', 'Enter your email and password.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).logIn(
            email: _email.text,
            password: _password.text,
          );
      // Nothing else to do. The auth gate sees the new session and shows the app.
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Emails a sign-in link. It opens the app through the threads:// scheme.
  Future<void> _sendLink() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (email.isEmpty) {
      await showMessage(context, 'Missing details', 'Enter your email first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendSignInLink(email);
      if (mounted) {
        await showMessage(
          context,
          'Check your email',
          'Open the link on this device to sign in.',
        );
      }
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Threads'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 24),
            AdaptiveTextField(
              controller: _email,
              placeholder: 'Email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            AdaptiveTextField(
              controller: _password,
              placeholder: 'Password',
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _logIn(),
            ),
            const SizedBox(height: 20),
            AdaptiveButton.child(
              onPressed: _logIn,
              child: _busy
                  ? const CupertinoActivityIndicator()
                  : const Text('Log in'),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: () => openScreen<void>(context, const SignUpScreen()),
              child: const Text('Create an account'),
            ),
            const SizedBox(height: 4),
            CupertinoButton(
              onPressed: _sendLink,
              child: const Text('Email me a sign-in link'),
            ),
          ],
        ),
      ),
    );
  }
}