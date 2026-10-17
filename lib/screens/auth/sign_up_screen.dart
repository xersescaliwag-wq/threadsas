// lib/screens/auth/sign_up_screen.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/formatters.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/providers/core_providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_busy) return;
    final username = _username.text.trim().toLowerCase();
    final usernameProblem = validateUsername(username);
    if (usernameProblem != null) {
      await showMessage(context, 'Check your username', usernameProblem);
      return;
    }
    if (_password.text.length < 6) {
      await showMessage(context, 'Weak password', 'Use at least 6 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      final auth = ref.read(authRepositoryProvider);
      if (!await auth.isUsernameAvailable(username)) {
        if (mounted) await showMessage(context, 'Username taken', 'Choose another username.');
        return;
      }
      final needsConfirmation = await auth.signUp(
        email: _email.text,
        password: _password.text,
        username: username,
        displayName: _name.text.trim().isEmpty ? username : _name.text,
      );
      if (!mounted) return;
      if (needsConfirmation) {
        await showMessage(context, 'Check your email', 'Confirm your address, then log in.');
      }
      // With a session, the auth gate shows the app. Either way, close this screen.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Create account'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AdaptiveTextField(
              controller: _name,
              placeholder: 'Name',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            AdaptiveTextField(
              controller: _username,
              placeholder: 'Username',
              autocorrect: false,
              textInputAction: TextInputAction.next,
            ),
            Padding(
              padding: EdgeInsets.only(top: 6, bottom: 12),
              child: Text(
                '3 to 30 letters, numbers, periods or underscores.',
                style: TextStyle(fontSize: 13, color: context.colors.secondaryLabel),
              ),
            ),
            AdaptiveTextField(
              controller: _email,
              placeholder: 'Email',
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            AdaptiveTextField(
              controller: _password,
              placeholder: 'Password (6 or more characters)',
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signUp(),
            ),
            const SizedBox(height: 20),
            AdaptiveButton.child(
              onPressed: _signUp,
              child: _busy
                  ? const AppSpinner()
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}