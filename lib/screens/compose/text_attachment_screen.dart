import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:threads/core/adaptive.dart';

class TextAttachmentResult {
  const TextAttachmentResult(
    this.text, {
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strikethrough,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;

  String get encoded {
    final tags = <String>[];
    if (bold) tags.add('b');
    if (italic) tags.add('i');
    if (underline) tags.add('u');
    if (strikethrough) tags.add('s');
    var value = text;
    for (final tag in tags) {
      value = '[[$tag]]$value[/$tag]';
    }
    return value;
  }
}

/// Lightweight text attachment editor. Formatting is intentionally kept local
/// until the post model supports rich-text ranges; the returned value remains
/// compatible with the existing plain-text Supabase post schema.
class TextAttachmentScreen extends StatefulWidget {
  const TextAttachmentScreen({super.key, this.initialText});

  final String? initialText;

  @override
  State<TextAttachmentScreen> createState() => _TextAttachmentScreenState();
}

class _TextAttachmentScreenState extends State<TextAttachmentScreen> {
  late final TextEditingController _controller;
  bool _bold = false;
  bool _italic = false;
  bool _underline = false;
  bool _strike = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(void Function() change) {
    setState(change);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  void _complete() {
    Navigator.of(context).pop(
      TextAttachmentResult(
        _controller.text.trim(),
        bold: _bold,
        italic: _italic,
        underline: _underline,
        strikethrough: _strike,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decoration = TextDecoration.combine([
      if (_underline) TextDecoration.underline,
      if (_strike) TextDecoration.lineThrough,
    ]);
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: 'Text',
        useNativeToolbar: false,
        leading: AdaptiveButton(
          label: 'Cancel',
          style: AdaptiveButtonStyle.plain,
          color: context.colors.systemBlue,
          minSize: const Size(0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          AdaptiveAppBarAction(
            title: 'Done',
            label: 'Done',
            onPressed: _complete,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: AdaptiveTextField(
                  controller: _controller,
                  autofocus: false,
                  autocorrect: false,
                  minLines: 1,
                  maxLines: 12,
                  placeholder: 'Write your text...',
                  padding: const EdgeInsets.all(2),
                  decoration: borderlessInputDecoration(
                    hintText: 'Write your text...',
                  ),
                  cupertinoDecoration: const BoxDecoration(),
                  style:
                      TextStyle(
                        fontSize: 24,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ).copyWith(
                        fontWeight: _bold ? FontWeight.w900 : FontWeight.w400,
                        fontStyle: _italic
                            ? FontStyle.italic
                            : FontStyle.normal,
                        decoration: decoration,
                      ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: 200,
                height: 45,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.systemGrey6,
                    border: Border.all(
                      color: context.colors.separator,
                      width: .5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _tool(
                        'B',
                        _bold,
                        () => _toggle(() => _bold = !_bold),
                        weight: FontWeight.w800,
                      ),
                      _tool(
                        'I',
                        _italic,
                        () => _toggle(() => _italic = !_italic),
                        style: FontStyle.italic,
                      ),
                      _tool(
                        'U',
                        _underline,
                        () => _toggle(() => _underline = !_underline),
                        decoration: TextDecoration.underline,
                      ),
                      _tool(
                        'S',
                        _strike,
                        () => _toggle(() => _strike = !_strike),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tool(
    String label,
    bool active,
    VoidCallback onPressed, {
    FontWeight? weight,
    FontStyle? style,
    TextDecoration? decoration,
  }) => AdaptiveButton.child(
    style: AdaptiveButtonStyle.plain,
    color: active ? context.colors.systemBlue : context.colors.label,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    minSize: const Size(34, 32),
    onPressed: onPressed,
    child: Container(
      width: 34,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? context.colors.systemBlue.withOpacity(.16) : null,
        border: Border.all(
          color: active ? context.colors.systemBlue : context.colors.separator,
          width: active ? 1.3 : .5,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? context.colors.systemBlue : context.colors.label,
          fontSize: 18,
          fontWeight: weight ?? FontWeight.w700,
          fontStyle: style,
          decoration: decoration,
        ),
      ),
    ),
  );
}
