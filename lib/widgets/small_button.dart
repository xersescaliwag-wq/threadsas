// lib/widgets/small_button.dart
import 'package:threads/core/adaptive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
class SmallButton extends StatelessWidget {
  const SmallButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: filled ? context.colors.activeBlue : context.colors.systemGrey5,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: filled ? context.colors.white : context.colors.label,
            ),
          ),
        ),
      ),
    );
  }
}
