// lib/widgets/report_dialog.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
/// Asks why something is being reported. Returns the trimmed reason, or null
/// when the person cancels. The database accepts 3 to 500 characters.
Future<String?> askReportReason(BuildContext context, {required String title}) {
  final controller = TextEditingController();
  return showCupertinoDialog<String>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: controller,
          placeholder: 'What is wrong?',
          maxLines: 3,
          maxLength: 500,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('Send'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
