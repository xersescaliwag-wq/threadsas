import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/providers/core_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      await showMessage(
        context,
        'Enter your email',
        'Use the email address connected to your account.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (!mounted) return;
      await showMessage(
        context,
        'Check your email',
        'We sent you a password reset link.',
      );
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: 'Forgot password'),
      body: ResponsiveContent(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            children: [
              Icon(AppIcons.lock_shield, size: 42),
              const SizedBox(height: 20),
              const Text(
                'Reset your password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your email and we’ll send you a secure reset link.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: context.colors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 30),
              AdaptiveTextField(
                controller: _email,
                placeholder: 'Email',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                onSubmitted: (_) => _sendResetLink(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                cupertinoDecoration: BoxDecoration(
                  color: context.colors.systemGrey6,
                  borderRadius: BorderRadius.circular(10),
                ),
                decoration: appFilledInputDecoration(
                  hintText: 'Email',
                  fillColor: context.colors.systemGrey6,
                  borderColor: context.colors.separator,
                  focusedBorderColor: context.colors.activeBlue,
                  radius: 10,
                ),
              ),
              const SizedBox(height: 18),
              AdaptiveButton.child(
                onPressed: _busy ? null : _sendResetLink,
                child: _busy
                    ? const AppSpinner()
                    : const Text(
                        'Send reset link',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
