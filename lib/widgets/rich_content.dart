import 'package:threads/core/adaptive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Post text with tappable #hashtags, @mentions and links.
class RichContent extends StatelessWidget {
  const RichContent({
    super.key,
    required this.text,
    this.onHashtag,
    this.onMention,
    this.style,
    this.formatting = const {},
  });
  final String text;
  final ValueChanged<String>? onHashtag;
  final ValueChanged<String>? onMention;
  final TextStyle? style;
  final Map<String, dynamic> formatting;

  static final RegExp _token = RegExp(
    r'(#[A-Za-z0-9_]+)|(@[A-Za-z0-9_.]+)|(https?://[^\s]+)',
  );

  @override
  Widget build(BuildContext context) {
    final baseStyle = (style ?? TextStyle(fontSize: 16, height: 1.35, color: context.colors.label)).copyWith(
      fontWeight: formatting['bold'] == true ? FontWeight.w900 : null,
      fontStyle: formatting['italic'] == true ? FontStyle.italic : null,
      decoration: TextDecoration.combine([
        if (formatting['underline'] == true) TextDecoration.underline,
        if (formatting['strikethrough'] == true) TextDecoration.lineThrough,
      ]),
    );
    final displayText = text;
    final linkStyle = baseStyle.copyWith(color: context.colors.activeBlue);
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _token.allMatches(displayText)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: displayText.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => _handleTap(token),
            child: Text(token, style: linkStyle),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < displayText.length) {
      spans.add(TextSpan(text: displayText.substring(cursor)));
    }
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }

  void _handleTap(String token) {
    if (token.startsWith('#')) {
      onHashtag?.call(token.substring(1).toLowerCase());
    } else if (token.startsWith('@')) {
      onMention?.call(token.substring(1).toLowerCase());
    } else {
      launchUrl(Uri.parse(token), mode: LaunchMode.externalApplication);
    }
  }
}
