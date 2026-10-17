import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

/// A round profile photo. Without a photo, it shows the first letter of the name.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 36});
  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final placeholder = Container(
      width: size,
      height: size,
      color: CupertinoColors.systemGrey4,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.label,
        ),
      ),
    );
    final photo = url;
    return ClipOval(
      child: photo == null || photo.isEmpty
          ? placeholder
          : Image.network(
              photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => placeholder,
            ),
    );
  }
}