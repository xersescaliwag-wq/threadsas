// lib/widgets/report_dialog.dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/widgets.dart';

/// Asks why something is being reported. Returns the trimmed reason, or null
/// when the person cancels. The database accepts 3 to 500 characters.
Future<String?> askReportReason(BuildContext context, {required String title}) {
  return AdaptiveAlertDialog.inputShow(
    context: context,
    title: title,
    actions: [
      AlertAction(
        title: 'Cancel',
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: 'Send',
        style: AlertActionStyle.primary,
        onPressed: () {},
      ),
    ],
    input: const AdaptiveAlertDialogInput(
      placeholder: 'What is wrong?',
      maxLength: 500,
    ),
  );
}
