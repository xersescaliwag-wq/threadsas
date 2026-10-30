import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/core/messages.dart';
import 'package:threads/providers/core_providers.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _password.text;
    if (password.length < 8) {
      await showMessage(
        context,
        'Password too short',
        'Use at least 8 characters.',
      );
      return;
    }
    if (password != _confirmation.text) {
      await showMessage(
        context,
        'Passwords do not match',
        'Enter the same password in both fields.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(password);
      if (mounted) {
        await showMessage(
          context,
          'Password updated',
          'Your password has been changed securely.',
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) await showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _strength {
    final value = _password.text;
    if (value.isEmpty) return 'Use at least 8 characters';
    if (value.length < 8) return 'Too short';
    if (value.length >= 12 &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value))
      return 'Strong password';
    return 'Good password';
  }

  @override
  Widget build(BuildContext context) => AdaptiveScaffold(
    appBar: AdaptiveAppBar(title: 'Change password'),
    body: ResponsiveContent(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
          children: [
            Text(
              'Create a new password',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -.4,
                color: context.colors.label,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Use a password you do not use on another account.',
              style: TextStyle(
                fontSize: 14,
                color: context.colors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'New password',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.colors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 7),
            Stack(
              children: [
                AdaptiveTextField(
                  controller: _password,
                  placeholder: 'Enter a new password',
                  obscureText: _obscurePassword,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 3,
                  ),
                  cupertinoDecoration: BoxDecoration(
                    color: context.colors.systemGrey6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  decoration: appFilledInputDecoration(
                    hintText: 'Enter a new password',
                    fillColor: context.colors.systemGrey6,
                    borderColor: context.colors.separator,
                    focusedBorderColor: context.colors.activeBlue,
                    radius: 10,
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                Positioned(
                  right: 2,
                  top: 0,
                  bottom: 0,
                  child: AppIconButton(
                    padding: EdgeInsets.zero,
                    minSize: const Size(42, 42),
                    icon: _obscurePassword ? AppIcons.eye_slash : AppIcons.eye,
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    semanticLabel: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                _strength,
                style: TextStyle(
                  fontSize: 12,
                  color: _password.text.length < 8
                      ? context.colors.secondaryLabel
                      : context.colors.activeBlue,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Confirm password',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.colors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 7),
            Stack(
              children: [
                AdaptiveTextField(
                  controller: _confirmation,
                  placeholder: 'Re-enter your new password',
                  obscureText: _obscureConfirmation,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 3,
                  ),
                  cupertinoDecoration: BoxDecoration(
                    color: context.colors.systemGrey6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  decoration: appFilledInputDecoration(
                    hintText: 'Re-enter your new password',
                    fillColor: context.colors.systemGrey6,
                    borderColor: context.colors.separator,
                    focusedBorderColor: context.colors.activeBlue,
                    radius: 10,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
                Positioned(
                  right: 2,
                  top: 0,
                  bottom: 0,
                  child: AppIconButton(
                    padding: EdgeInsets.zero,
                    minSize: const Size(42, 42),
                    icon: _obscureConfirmation
                        ? AppIcons.eye_slash
                        : AppIcons.eye,
                    onPressed: () => setState(
                      () => _obscureConfirmation = !_obscureConfirmation,
                    ),
                    semanticLabel: _obscureConfirmation
                        ? 'Show password'
                        : 'Hide password',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            AdaptiveButton.child(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const AppSpinner()
                  : const Text(
                      'Update password',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
