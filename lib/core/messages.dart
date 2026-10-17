// lib/core/messages.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:threads/core/errors.dart';

/// Shows a message with one OK button.
Future<void> showMessage(BuildContext context, String title, String message) {
  return AdaptiveAlertDialog.show(
    context: context,
    title: title,
    message: message,
    actions: [
      AlertAction(
        title: 'OK',
        style: AlertActionStyle.primary,
        onPressed: () {},
      ),
    ],
  );
}

/// Shows an error in plain language.
Future<void> showError(BuildContext context, Object error) {
  return showMessage(context, 'Something went wrong', friendlyError(error));
}

/// Asks a yes or no question. Returns true only when the person taps the action button.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  bool destructive = false,
}) async {
  var answer = false;
  await AdaptiveAlertDialog.show(
    context: context,
    title: title,
    message: message,
    actions: [
      AlertAction(
        title: 'Cancel',
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: actionLabel,
        style: destructive ? AlertActionStyle.destructive : AlertActionStyle.primary,
        onPressed: () {
          answer = true;
        },
      ),
    ],
  );
  return answer;
}