// lib/screens/compose/gif_search_sheet.dart
import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/data/gif_repository.dart';
import 'package:threads/models/gif_result.dart';
import 'package:threads/providers/core_providers.dart';

/// Fast client-side GIPHY picker. The grid uses lightweight animated WebP
/// previews; the selected post still stores a compatible GIF URL.
class GifSearchSheet extends ConsumerStatefulWidget {
  const GifSearchSheet({super.key});

  @override
  ConsumerState<GifSearchSheet> createState() => _GifSearchSheetState();
}

class _GifSearchSheetState extends ConsumerState<GifSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<GifResult> _results = const [];
  bool _loading = true;
  String? _error;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String query) async {
    final text = query.trim();
    _lastQuery = text;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(gifRepositoryProvider).search(text);
      if (!mounted || _lastQuery != text) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } on GifSearchException catch (error) {
      if (!mounted || _lastQuery != text) return;
      setState(() {
        _error = error.message;
        _results = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: 'GIFs'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: AppSearchField(
                controller: _controller,
                placeholder: 'Search GIFs',
                onChanged: _onChanged,
                onSubmitted: _search,
              ),
            ),
            Expanded(child: _resultsView()),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Powered by GIPHY',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.secondaryLabel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultsView() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.secondaryLabel),
          ),
        ),
      );
    }
    if (_loading && _results.isEmpty) {
      return const Center(child: AppSpinner());
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No GIFs found',
          style: TextStyle(color: context.colors.secondaryLabel),
        ),
      );
    }

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final targetWidth = (MediaQuery.sizeOf(context).width * pixelRatio / 2)
        .round();
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final gif = _results[index];
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(gif),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              gif.previewUrl,
              fit: BoxFit.cover,
              cacheWidth: targetWidth,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, loadedSynchronously) {
                if (loadedSynchronously || frame != null) return child;
                return ColoredBox(color: context.colors.systemGrey5);
              },
              errorBuilder: (context, error, stackTrace) =>
                  ColoredBox(color: context.colors.systemGrey5),
            ),
          ),
        );
      },
    );
  }
}
