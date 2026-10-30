import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/providers/core_providers.dart';

class PasswordResetDialog extends ConsumerStatefulWidget {
  const PasswordResetDialog({super.key});

  @override
  ConsumerState<PasswordResetDialog> createState() =>
      _PasswordResetDialogState();
}

class _PasswordResetDialogState extends ConsumerState<PasswordResetDialog> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  int _step = 0;
  String? _token;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _showError('Enter a valid email address.');
      return;
    }
    await _run(() async {
      await ref.read(authRepositoryProvider).requestPasswordCode(email);
      if (mounted) setState(() => _step = 1);
    });
  }

  Future<void> _verifyCode() async {
    if (!RegExp(r'^\d{8}$').hasMatch(_code.text.trim())) {
      _showError('Enter the 8-digit code from your email.');
      return;
    }
    await _run(() async {
      final token = await ref
          .read(authRepositoryProvider)
          .verifyPasswordCode(email: _email.text, code: _code.text);
      if (mounted)
        setState(() {
          _token = token;
          _step = 2;
        });
    });
  }

  Future<void> _updatePassword() async {
    if (_password.text.length < 8) {
      _showError('Use at least 8 characters.');
      return;
    }
    if (_password.text != _confirmation.text) {
      _showError('Passwords do not match.');
      return;
    }
    await _run(() async {
      await ref
          .read(authRepositoryProvider)
          .completePasswordReset(
            email: _email.text,
            verificationToken: _token!,
            password: _password.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showMessage(context, 'Password reset', message);
  }

  Widget _field({
    required TextEditingController controller,
    required String placeholder,
    bool obscureText = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    return AdaptiveTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscureText,
      keyboardType: keyboardType,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      suffix: suffix,
      decoration: appFilledInputDecoration(
        hintText: placeholder,
        fillColor: context.colors.systemGrey6,
        borderColor: context.colors.separator,
        focusedBorderColor: context.colors.activeBlue,
        radius: 10,
      ),
      cupertinoDecoration: BoxDecoration(
        color: context.colors.systemGrey6,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _step == 0
        ? 'Forgot password?'
        : _step == 1
        ? 'Enter your code'
        : 'Create a new password';
    final subtitle = _step == 0
        ? 'Enter your email and we’ll send an 8-digit code.'
        : _step == 1
        ? 'Check your email for the verification code.'
        : 'Use a password you do not use elsewhere.';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AdaptiveCard(
          color: context.colors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_step == 0)
                    _field(
                      controller: _email,
                      placeholder: 'Email address',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  if (_step == 1)
                    _field(
                      controller: _code,
                      placeholder: '8-digit code',
                      keyboardType: TextInputType.number,
                      suffix: const SizedBox(width: 0),
                    ),
                  if (_step == 2) ...[
                    Stack(
                      children: [
                        _field(
                          controller: _password,
                          placeholder: 'New password',
                          obscureText: _obscurePassword,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: AppIconButton(
                            padding: const EdgeInsets.all(10),
                            minSize: const Size(40, 40),
                            icon: _obscurePassword
                                ? AppIcons.eye
                                : AppIcons.eye_slash,
                            size: 19,
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            semanticLabel: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Stack(
                      children: [
                        _field(
                          controller: _confirmation,
                          placeholder: 'Confirm password',
                          obscureText: _obscureConfirmation,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: AppIconButton(
                            padding: const EdgeInsets.all(10),
                            minSize: const Size(40, 40),
                            icon: _obscureConfirmation
                                ? AppIcons.eye
                                : AppIcons.eye_slash,
                            size: 19,
                            onPressed: () => setState(
                              () =>
                                  _obscureConfirmation = !_obscureConfirmation,
                            ),
                            semanticLabel: _obscureConfirmation
                                ? 'Show password'
                                : 'Hide password',
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  AdaptiveButton.child(
                    onPressed: _busy
                        ? null
                        : (_step == 0
                              ? _requestCode
                              : _step == 1
                              ? _verifyCode
                              : _updatePassword),
                    child: _busy
                        ? const AppSpinner()
                        : Text(
                            _step == 0
                                ? 'Request code'
                                : _step == 1
                                ? 'Confirm code'
                                : 'Update password',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                  const SizedBox(height: 4),
                  AdaptiveButton.child(
                    style: AdaptiveButtonStyle.plain,
                    color: context.colors.secondaryLabel,
                    minSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: context.colors.secondaryLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
