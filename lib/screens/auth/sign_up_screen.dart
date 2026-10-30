// lib/screens/auth/sign_up_screen.dart
import 'dart:ui';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/formatters.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/widgets/auth_video_background.dart';

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
  bool _obscurePassword = true;

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
        if (mounted)
          await showMessage(
            context,
            'Username taken',
            'Choose another username.',
          );
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
        await showMessage(
          context,
          'Check your email',
          'Confirm your address, then log in.',
        );
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthVideoBackground(child: SizedBox.shrink()),
          Container(color: CupertinoColors.black.withOpacity(.58)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppIconButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: AppIcons.back,
                    color: CupertinoColors.white,
                    size: 24,
                    minSize: const Size(40, 40),
                    semanticLabel: 'Back',
                  ),
                ),
                const SizedBox(height: 38),
                const Text(
                  'Create account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join the conversation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CupertinoColors.white.withOpacity(.72),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 30),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: CupertinoColors.transparent),
                      ),
                      child: Column(
                        children: [
                          AdaptiveTextField(
                            controller: _name,
                            placeholder: 'Name',
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              color: CupertinoColors.white,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            cupertinoDecoration: const BoxDecoration(
                              color: CupertinoColors.transparent,
                            ),
                          ),
                          const SizedBox(height: 5),
                          AdaptiveTextField(
                            controller: _username,
                            placeholder: 'Username',
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              color: CupertinoColors.white,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            cupertinoDecoration: const BoxDecoration(
                              color: CupertinoColors.transparent,
                            ),
                          ),
                          const SizedBox(height: 5),
                          AdaptiveTextField(
                            controller: _email,
                            placeholder: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              color: CupertinoColors.white,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            cupertinoDecoration: const BoxDecoration(
                              color: CupertinoColors.transparent,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Stack(
                            children: [
                              AdaptiveTextField(
                                controller: _password,
                                placeholder: 'Password (6 or more characters)',
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _signUp(),
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  52,
                                  14,
                                ),
                                cupertinoDecoration: const BoxDecoration(
                                  color: CupertinoColors.transparent,
                                ),
                              ),
                              Positioned(
                                right: 4,
                                top: 0,
                                bottom: 0,
                                child: AppIconButton(
                                  padding: const EdgeInsets.all(10),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: _obscurePassword
                                      ? AppIcons.eye
                                      : AppIcons.eye_slash,
                                  color: CupertinoColors.white.withOpacity(.75),
                                  size: 20,
                                  minSize: const Size(44, 44),
                                  semanticLabel: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 18),
                  child: Text(
                    '3 to 30 letters, numbers, periods or underscores.',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.white.withOpacity(.68),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: AdaptiveButton.child(
                    style: AdaptiveButtonStyle.filled,
                    color: CupertinoColors.white,
                    padding: EdgeInsets.zero,
                    minSize: const Size(0, 52),
                    borderRadius: BorderRadius.circular(16),
                    onPressed: _busy ? null : _signUp,
                    child: _busy
                        ? const AppSpinner(color: CupertinoColors.black)
                        : const Text(
                            'Create account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.black,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
