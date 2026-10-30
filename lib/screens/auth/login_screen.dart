// lib/screens/auth/login_screen.dart
import 'dart:ui';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/core/navigation.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/screens/auth/sign_up_screen.dart';
import 'package:threads/screens/auth/forgot_password_screen.dart';
import 'package:threads/widgets/auth_video_background.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    if (_busy) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      await showMessage(
        context,
        'Missing details',
        'Enter your email and password.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .logIn(email: _email.text, password: _password.text);
      // Auth state changes handled by root auth gate listener
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
        children: [
          // 1. Background Image Layer
          Positioned.fill(
            child: const AuthVideoBackground(child: SizedBox.shrink()),
          ),

          // 2. Dark Gradient Overlay for Readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    CupertinoColors.black.withOpacity(0.35),
                    CupertinoColors.black.withOpacity(0.65),
                  ],
                ),
              ),
            ),
          ),

          // 3. Foreground Login Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo / Title
                      const Text(
                        'threads',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2.5,
                          color: CupertinoColors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Log in to your account',
                        style: TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Glassmorphism Form Container
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: CupertinoColors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: CupertinoColors.transparent,
                              ),
                            ),
                            child: Column(
                              children: [
                                AdaptiveTextField(
                                  controller: _email,
                                  placeholder: 'Email',
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  cupertinoDecoration: BoxDecoration(
                                    color: context.colors.systemGrey6,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Stack(
                                  children: [
                                    AdaptiveTextField(
                                      controller: _password,
                                      placeholder: 'Password',
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _logIn(),
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        16,
                                        52,
                                        16,
                                      ),
                                      cupertinoDecoration: BoxDecoration(
                                        color: context.colors.systemGrey6,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    Positioned(
                                      right: 4,
                                      top: 0,
                                      bottom: 0,
                                      child: AppIconButton(
                                        padding: const EdgeInsets.all(12),
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                        icon: _obscurePassword
                                            ? AppIcons.eye
                                            : AppIcons.eye_slash,
                                        color: CupertinoColors.white
                                            .withOpacity(.75),
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
                      const SizedBox(height: 20),

                      // Main Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: AdaptiveButton.child(
                          style: AdaptiveButtonStyle.filled,
                          color: CupertinoColors.white,
                          padding: EdgeInsets.zero,
                          minSize: const Size(0, 52),
                          borderRadius: BorderRadius.circular(16),
                          onPressed: _busy ? null : _logIn,
                          child: _busy
                              ? const AppSpinner(color: CupertinoColors.black)
                              : const Text(
                                  'Log In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: CupertinoColors.black,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Navigation Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AdaptiveButton.child(
                            style: AdaptiveButtonStyle.plain,
                            color: CupertinoColors.white,
                            minSize: const Size(0, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            onPressed: () => openScreen<void>(
                              context,
                              const ForgotPasswordScreen(),
                            ),
                            child: Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: CupertinoColors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 14,
                            color: CupertinoColors.white.withOpacity(0.3),
                          ),
                          AdaptiveButton.child(
                            style: AdaptiveButtonStyle.plain,
                            color: CupertinoColors.white,
                            minSize: const Size(0, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            onPressed: () =>
                                openScreen<void>(context, const SignUpScreen()),
                            child: const Text(
                              'Sign up',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
