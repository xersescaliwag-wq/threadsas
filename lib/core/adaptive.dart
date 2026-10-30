// lib/core/adaptive.dart
//
// Platform-adaptive presentation helpers.
//
// This is the ONLY file under lib/ that imports Flutter's Material library.
// All other lib/ files must go through these helpers or through the
// adaptive_platform_ui package.
//
// Exposed APIs:
// - materialAppTheme(Brightness) — returns a Material ThemeData for Android chrome
// - AppSpinner — adaptive progress indicator
// - AppRefreshView — adaptive pull-to-refresh (wraps CustomScrollView)
// - AppColors.of(context) / context.colors (extension)
// - AppIcons.* — platform-adaptive IconData (Material on Android, Cupertino on iOS)
// - adaptivePageRoute<T>(builder, {fullscreen}) — platform-adaptive PageRoute

// ignore_for_file: non_constant_identifier_names

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;

/// Builds a Material ThemeData for the Android (Material) half of the app.
material.ThemeData materialAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final base = material.ColorScheme.fromSeed(
    seedColor: isDark ? material.Colors.white : material.Colors.black,
    brightness: brightness,
  );

  final scheme = base.copyWith(
    primary: isDark ? material.Colors.white : material.Colors.black,
    onPrimary: isDark ? material.Colors.black : material.Colors.white,
    error: isDark ? material.Colors.red.shade300 : material.Colors.red.shade700,
    surface: isDark ? material.Colors.black : material.Colors.white,
    onSurface: isDark ? material.Colors.white : material.Colors.black,
    onSurfaceVariant: isDark
        ? material.Colors.grey.shade400
        : material.Colors.grey.shade600,
    outline: isDark
        ? material.Colors.grey.shade600
        : material.Colors.grey.shade400,
    outlineVariant: isDark
        ? material.Colors.grey.shade800
        : material.Colors.grey.shade300,
    surfaceContainerHighest: isDark
        ? material.Colors.grey.shade800
        : material.Colors.grey.shade200,
    surfaceContainerHigh: isDark
        ? material.Colors.grey.shade900
        : material.Colors.grey.shade100,
  );

  return material.ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    useMaterial3: true,
    appBarTheme: material.AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: material.Colors.transparent,
      centerTitle: false,
      titleTextStyle: material.TextTheme(
        titleLarge: material.TextStyle(
          color: scheme.onSurface,
          fontSize: 28,
          fontWeight: material.FontWeight.w700,
          letterSpacing: -0.7,
        ),
      ).titleLarge,
    ),
    navigationBarTheme: material.NavigationBarThemeData(
      height: 72,
      backgroundColor: scheme.surface,
      surfaceTintColor: material.Colors.transparent,
      indicatorColor: material.Colors.transparent,
      labelBehavior: material.NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: material.WidgetStateProperty.resolveWith((states) {
        return material.IconThemeData(
          size: 29,
          color: states.contains(material.WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        );
      }),
    ),
    textTheme: material.ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      fontFamily: 'sans-serif',
    ),
    inputDecorationTheme: material.InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? const material.Color(0xFF1D1D1F)
          : material.Colors.grey.shade100,
      hintStyle: material.TextStyle(color: scheme.onSurfaceVariant),
      border: material.OutlineInputBorder(
        borderRadius: material.BorderRadius.circular(16),
        borderSide: material.BorderSide.none,
      ),
      enabledBorder: material.OutlineInputBorder(
        borderRadius: material.BorderRadius.circular(16),
        borderSide: material.BorderSide.none,
      ),
    ),
  );
}

/// Adaptive progress indicator: CupertinoActivityIndicator on iOS; CircularProgressIndicator on Android.
class AppSpinner extends StatelessWidget {
  const AppSpinner({
    super.key,
    this.radius = 10,
    this.color,
    this.animating = true,
  });

  final double radius;
  final Color? color;
  final bool animating;

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS) {
      return CupertinoActivityIndicator(
        radius: radius,
        color: color,
        animating: animating,
      );
    }
    return SizedBox(
      width: radius * 2.2,
      height: radius * 2.2,
      child: material.CircularProgressIndicator(
        strokeWidth: 2.4,
        color: color ?? material.Theme.of(context).colorScheme.primary,
        value: animating ? null : 1,
      ),
    );
  }
}

/// Adaptive pull-to-refresh: wraps a CustomScrollView. On iOS, a CupertinoSliverRefreshControl
/// is automatically inserted; on Android, it becomes a RefreshIndicator.
class AppRefreshView extends StatelessWidget {
  const AppRefreshView({
    super.key,
    required this.onRefresh,
    required this.slivers,
    this.controller,
    this.physics,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> slivers;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS) {
      return CustomScrollView(
        controller: controller,
        physics: physics,
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
          ...slivers,
        ],
      );
    }

    return material.RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: controller,
        physics: physics ?? const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }
}

/// Widest a reading column is allowed to grow. Posts, chats and lists stay at
/// this width on tablets and in landscape instead of stretching edge to edge.
const double contentMaxWidth = 600;

/// Caps [child] at [maxWidth] and centers it on wide screens. On phones, where
/// the window is already narrower than [maxWidth], the child is returned as-is,
/// so the layout is unchanged.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}

/// A grouped list section: an inset grouped list on iOS, a titled group of
/// Material list tiles on Android.
class AppListSection extends StatelessWidget {
  const AppListSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
  });

  final Widget? header;
  final Widget? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS) {
      return CupertinoListSection.insetGrouped(
        header: header,
        footer: footer,
        children: children,
      );
    }

    final theme = material.Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: DefaultTextStyle(
                style:
                    theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ) ??
                    const TextStyle(),
                child: header!,
              ),
            ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              material.Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
            children[i],
          ],
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: DefaultTextStyle(
                style:
                    theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ) ??
                    const TextStyle(),
                child: footer!,
              ),
            ),
        ],
      ),
    );
  }
}

/// The trailing disclosure chevron for a list row.
class AppListChevron extends StatelessWidget {
  const AppListChevron({super.key});

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS) return const CupertinoListTileChevron();
    return Icon(
      material.Icons.chevron_right,
      size: 20,
      color: material.Theme.of(context).colorScheme.outline,
    );
  }
}

/// A borderless Material decoration for a text field used inside a bespoke
/// layout (the stand-in for `CupertinoTextField.borderless`). On iOS the
/// adaptive text field uses its own `cupertinoDecoration` instead.
material.InputDecoration borderlessInputDecoration({
  String? hintText,
  EdgeInsetsGeometry? contentPadding,
}) => material.InputDecoration(
  hintText: hintText,
  filled: false,
  fillColor: material.Colors.transparent,
  border: const material.OutlineInputBorder(
    borderRadius: material.BorderRadius.zero,
    borderSide: material.BorderSide.none,
  ),
  contentPadding: contentPadding ?? EdgeInsets.zero,
);

/// Builds the Material half of an [AdaptiveTextField] decoration while keeping
/// the visual contract in one platform-adaptive place. iOS callers should pass
/// the matching [AdaptiveTextField.cupertinoDecoration].
material.InputDecoration appFilledInputDecoration({
  String? hintText,
  required Color fillColor,
  required Color borderColor,
  Color? focusedBorderColor,
  double radius = 10,
  EdgeInsetsGeometry? contentPadding,
}) {
  material.OutlineInputBorder border(Color color, double width) =>
      material.OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: material.BorderSide(color: color, width: width),
      );

  return material.InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: fillColor,
    border: border(borderColor, .5),
    enabledBorder: border(borderColor, .5),
    focusedBorder: border(focusedBorderColor ?? borderColor, 1),
    contentPadding: contentPadding,
  );
}

/// A compact adaptive icon button. It keeps icon-only controls platform
/// appropriate without forcing individual features to choose a Material or
/// Cupertino button themselves.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 22,
    this.padding = EdgeInsets.zero,
    this.minSize = const Size(44, 44),
    this.borderRadius,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final EdgeInsetsGeometry padding;
  final Size minSize;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    child: AdaptiveButton.child(
      onPressed: onPressed,
      style: AdaptiveButtonStyle.plain,
      color: color ?? context.colors.label,
      padding: padding,
      minSize: minSize,
      borderRadius: borderRadius,
      child: Icon(icon, size: size, color: color ?? context.colors.label),
    ),
  );
}

/// A search box: a native Cupertino search field on iOS, and a Material
/// search-styled text field on Android.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    required this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS) {
      return CupertinoSearchTextField(
        controller: controller,
        placeholder: placeholder,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
      );
    }

    final theme = material.Theme.of(context);
    return material.TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: material.InputDecoration(
        hintText: placeholder,
        prefixIcon: const Icon(material.Icons.search),
        isDense: true,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: material.OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}

/// The side panel handed to `AdaptiveScaffold.drawer`: a Material `Drawer` on
/// Android, and a full-height panel styled like iOS on iOS. The panel, scrim,
/// slide-in animation and drag gestures are the platform scaffold's own — use
/// [openAppDrawer] and [closeAppDrawer] to work them.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.child, this.widthFactor = 0.70});

  final Widget child;

  /// Fraction of the screen width the panel takes up.
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * widthFactor;
    // On iPhones in landscape the factor can push the panel past the
    // comfortable reading width; cap it at a sane drawer width.
    final panelWidth = width > 360.0 ? 360.0 : width;
    if (PlatformInfo.isIOS) {
      return Container(
        width: panelWidth,
        height: double.infinity,
        color: context.colors.systemBackground,
        // The drawer lives in the package's Material Scaffold, outside
        // CupertinoPageScaffold, so it does not inherit the iOS text colour.
        child: DefaultTextStyle.merge(
          style: TextStyle(color: context.colors.label),
          child: child,
        ),
      );
    }
    return material.Drawer(
      width: panelWidth,
      backgroundColor: context.colors.systemBackground,
      child: child,
    );
  }
}

/// Opens the nearest platform drawer (see [AppDrawer]).
void openAppDrawer(BuildContext context) =>
    material.Scaffold.of(context).openDrawer();

/// Closes the nearest platform drawer (see [AppDrawer]).
void closeAppDrawer(BuildContext context) =>
    material.Scaffold.of(context).closeDrawer();

/// One row in an adaptive action sheet (see [showAppActionSheet]).
class AppActionSheetItem<T> {
  const AppActionSheetItem({
    required this.value,
    required this.label,
    this.destructive = false,
  });

  /// The value returned when this row is chosen.
  final T value;

  /// The text shown on the row.
  final String label;

  /// Renders the row in the platform's destructive color.
  final bool destructive;
}

/// Shows a platform-appropriate list of actions and returns the chosen value,
/// or null when dismissed. iOS gets a Cupertino action sheet; Android gets a
/// Material bottom sheet.
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppActionSheetItem<T>> items,
}) {
  if (PlatformInfo.isIOS) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        message: message == null ? null : Text(message),
        actions: [
          for (final item in items)
            CupertinoActionSheetAction(
              isDestructiveAction: item.destructive,
              onPressed: () => Navigator.of(sheetContext).pop(item.value),
              child: Text(item.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  return material.showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = material.Theme.of(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            for (final item in items)
              material.ListTile(
                title: Text(
                  item.label,
                  style: item.destructive
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
                onTap: () => Navigator.of(sheetContext).pop(item.value),
              ),
          ],
        ),
      );
    },
  );
}

/// Presents custom sheet content through the platform's modal-sheet route.
/// This fills the gap for bespoke layouts (such as the message reaction bar)
/// while standard confirmations continue to use [AdaptiveAlertDialog].
Future<T?> showAppModalSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  bool isScrollControlled = true,
  Color? barrierColor,
}) {
  if (PlatformInfo.isIOS) {
    return showCupertinoModalPopup<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: barrierDismissible,
      barrierColor:
          barrierColor ?? CupertinoColors.black.withValues(alpha: .32),
      builder: builder,
    );
  }

  return material.showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isDismissible: barrierDismissible,
    isScrollControlled: isScrollControlled,
    barrierColor: barrierColor,
    backgroundColor: material.Colors.transparent,
    builder: builder,
  );
}

/// Presents custom dialog content with a platform-appropriate modal route.
/// Prefer [AdaptiveAlertDialog] for standard alert/confirmation dialogs.
Future<T?> showAppOverlayDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  Color? barrierColor,
}) {
  if (PlatformInfo.isIOS) {
    return showCupertinoDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      builder: builder,
    );
  }

  return material.showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    builder: builder,
  );
}

/// Context-aware adaptive colors. On iOS, returns the appropriate CupertinoColors value
/// (which auto-resolves with ambient brightness); on Android, returns Material theme colors.
@immutable
class AppColors {
  const AppColors(this._context);

  final BuildContext _context;

  static AppColors of(BuildContext context) => AppColors(context);

  bool get _isIOS => PlatformInfo.isIOS;
  material.ColorScheme get _scheme => material.Theme.of(_context).colorScheme;

  /// Resolves a [CupertinoDynamicColor] against the ambient light/dark theme.
  ///
  /// A bare `CupertinoColors.*` value is the *light* variant. Using one
  /// directly made iOS render white surfaces and black labels even in dark
  /// mode — i.e. white containers/buttons and invisible text.
  Color _cupertino(CupertinoDynamicColor color) =>
      CupertinoDynamicColor.resolve(color, _context);

  // Text/label colors
  Color get label =>
      _isIOS ? _cupertino(CupertinoColors.label) : _scheme.onSurface;
  Color get secondaryLabel => _isIOS
      ? _cupertino(CupertinoColors.secondaryLabel)
      : _scheme.onSurfaceVariant;
  Color get tertiaryLabel =>
      _isIOS ? _cupertino(CupertinoColors.tertiaryLabel) : _scheme.outline;

  // Dividers/surfaces
  Color get separator =>
      _isIOS ? _cupertino(CupertinoColors.separator) : _scheme.outlineVariant;
  Color get systemBackground =>
      _isIOS ? _cupertino(CupertinoColors.systemBackground) : _scheme.surface;

  // Accent/semantic colors (brand-consistent on Android)
  Color get activeBlue =>
      _isIOS ? _cupertino(CupertinoColors.activeBlue) : _scheme.primary;

  /// Text and icons that sit on [activeBlue] (outgoing message bubbles).
  Color get onActiveBlue => _isIOS ? CupertinoColors.white : _scheme.onPrimary;
  Color get systemBlue =>
      _isIOS ? _cupertino(CupertinoColors.systemBlue) : _scheme.primary;
  Color get activeGreen => _isIOS
      ? _cupertino(CupertinoColors.activeGreen)
      : (material.Theme.of(_context).brightness == material.Brightness.dark
            ? material.Colors.green.shade400
            : material.Colors.green.shade600);
  Color get systemGreen => _isIOS
      ? _cupertino(CupertinoColors.systemGreen)
      : (material.Theme.of(_context).brightness == material.Brightness.dark
            ? material.Colors.green.shade400
            : material.Colors.green.shade600);
  Color get systemRed =>
      _isIOS ? _cupertino(CupertinoColors.systemRed) : _scheme.error;
  Color get systemOrange => _isIOS
      ? _cupertino(CupertinoColors.systemOrange)
      : (material.Theme.of(_context).brightness == material.Brightness.dark
            ? material.Colors.orange.shade300
            : material.Colors.orange.shade700);
  Color get systemPurple => _isIOS
      ? _cupertino(CupertinoColors.systemPurple)
      : (material.Theme.of(_context).brightness == material.Brightness.dark
            ? material.Colors.purple.shade300
            : material.Colors.purple.shade400);
  Color get systemIndigo => _isIOS
      ? _cupertino(CupertinoColors.systemIndigo)
      : (material.Theme.of(_context).brightness == material.Brightness.dark
            ? material.Colors.indigo.shade300
            : material.Colors.indigo.shade400);

  // Greys
  Color get systemGrey =>
      _isIOS ? _cupertino(CupertinoColors.systemGrey) : _scheme.outline;
  Color get systemGrey4 => _isIOS
      ? _cupertino(CupertinoColors.systemGrey4)
      : _scheme.surfaceContainerHighest;
  Color get systemGrey5 => _isIOS
      ? _cupertino(CupertinoColors.systemGrey5)
      : _scheme.surfaceContainerHighest;
  Color get systemGrey6 => _isIOS
      ? _cupertino(CupertinoColors.systemGrey6)
      : _scheme.surfaceContainerHigh;

  // Fixed
  Color get black => CupertinoColors.black;
  Color get white => CupertinoColors.white;
}

extension AppColorsX on BuildContext {
  AppColors get colors => AppColors.of(this);
}

/// Platform-adaptive icons.
abstract final class AppIcons {
  static IconData get back => PlatformInfo.isIOS
      ? CupertinoIcons.chevron_back
      : material.Icons.arrow_back;
  static IconData get add =>
      PlatformInfo.isIOS ? CupertinoIcons.add : material.Icons.add;
  static IconData get add_circled => PlatformInfo.isIOS
      ? CupertinoIcons.add_circled
      : material.Icons.add_circle_outline;
  static IconData get bookmark => PlatformInfo.isIOS
      ? CupertinoIcons.bookmark
      : material.Icons.bookmark_border;
  static IconData get arrow_2_squarepath => PlatformInfo.isIOS
      ? CupertinoIcons.arrow_2_squarepath
      : material.Icons.repeat;
  static IconData get arrow_up_circle_fill => PlatformInfo.isIOS
      ? CupertinoIcons.arrow_up_circle_fill
      : material.Icons.arrow_circle_up;
  static IconData get at =>
      PlatformInfo.isIOS ? CupertinoIcons.at : material.Icons.alternate_email;
  static IconData get chat_bubble => PlatformInfo.isIOS
      ? CupertinoIcons.chat_bubble
      : material.Icons.chat_bubble_outline;
  static IconData get chat_bubble_fill => PlatformInfo.isIOS
      ? CupertinoIcons.chat_bubble_fill
      : material.Icons.chat_bubble;
  static IconData get checkmark =>
      PlatformInfo.isIOS ? CupertinoIcons.checkmark : material.Icons.check;
  static IconData get checkmark_seal_fill => PlatformInfo.isIOS
      ? CupertinoIcons.checkmark_seal_fill
      : material.Icons.verified;
  static IconData get chevron_forward => PlatformInfo.isIOS
      ? CupertinoIcons.chevron_forward
      : material.Icons.chevron_right;
  static IconData get chevron_right => PlatformInfo.isIOS
      ? CupertinoIcons.chevron_right
      : material.Icons.chevron_right;
  static IconData get clock =>
      PlatformInfo.isIOS ? CupertinoIcons.clock : material.Icons.schedule;
  static IconData get ellipsis =>
      PlatformInfo.isIOS ? CupertinoIcons.ellipsis : material.Icons.more_horiz;
  static IconData get exclamationmark_triangle => PlatformInfo.isIOS
      ? CupertinoIcons.exclamationmark_triangle
      : material.Icons.warning_amber_rounded;
  static IconData get eye => PlatformInfo.isIOS
      ? CupertinoIcons.eye
      : material.Icons.visibility_outlined;
  static IconData get eye_slash => PlatformInfo.isIOS
      ? CupertinoIcons.eye_slash
      : material.Icons.visibility_off_outlined;
  static IconData get hand_raised => PlatformInfo.isIOS
      ? CupertinoIcons.hand_raised
      : material.Icons.pan_tool_outlined;
  static IconData get heart => PlatformInfo.isIOS
      ? CupertinoIcons.heart
      : material.Icons.favorite_border;
  static IconData get heart_fill =>
      PlatformInfo.isIOS ? CupertinoIcons.heart_fill : material.Icons.favorite;
  static IconData get house_fill => PlatformInfo.isIOS
      ? CupertinoIcons.house_fill
      : material.Icons.home_filled;
  static IconData get link =>
      PlatformInfo.isIOS ? CupertinoIcons.link : material.Icons.link;
  static IconData get line_horizontal_3 => PlatformInfo.isIOS
      ? CupertinoIcons.line_horizontal_3
      : material.Icons.menu;
  static IconData get lock_fill =>
      PlatformInfo.isIOS ? CupertinoIcons.lock_fill : material.Icons.lock;
  static IconData get lock_shield => PlatformInfo.isIOS
      ? CupertinoIcons.lock_shield
      : material.Icons.shield_outlined;
  static IconData get music_note => PlatformInfo.isIOS
      ? CupertinoIcons.music_note_2
      : material.Icons.music_note;
  static IconData get pause_fill =>
      PlatformInfo.isIOS ? CupertinoIcons.pause_fill : material.Icons.pause;
  static IconData get paperplane =>
      PlatformInfo.isIOS ? CupertinoIcons.paperplane : material.Icons.send;
  static IconData get pencil =>
      PlatformInfo.isIOS ? CupertinoIcons.pencil : material.Icons.edit;
  static IconData get person_2 => PlatformInfo.isIOS
      ? CupertinoIcons.person_2
      : material.Icons.people_outline;
  static IconData get person_2_fill =>
      PlatformInfo.isIOS ? CupertinoIcons.person_2_fill : material.Icons.people;
  static IconData get person_badge_plus => PlatformInfo.isIOS
      ? CupertinoIcons.person_badge_plus
      : material.Icons.person_add_alt;
  static IconData get person_badge_plus_fill => PlatformInfo.isIOS
      ? CupertinoIcons.person_badge_plus_fill
      : material.Icons.person_add_alt_1;
  static IconData get person_fill =>
      PlatformInfo.isIOS ? CupertinoIcons.person_fill : material.Icons.person;
  static IconData get photo_on_rectangle => PlatformInfo.isIOS
      ? CupertinoIcons.photo_on_rectangle
      : material.Icons.image_outlined;
  static IconData get pin_fill =>
      PlatformInfo.isIOS ? CupertinoIcons.pin_fill : material.Icons.push_pin;
  static IconData get play_circle_fill => PlatformInfo.isIOS
      ? CupertinoIcons.play_circle_fill
      : material.Icons.play_circle_fill;
  static IconData get play_fill =>
      PlatformInfo.isIOS ? CupertinoIcons.play_fill : material.Icons.play_arrow;
  static IconData get quote_bubble_fill => PlatformInfo.isIOS
      ? CupertinoIcons.quote_bubble_fill
      : material.Icons.format_quote;
  static IconData get reply => PlatformInfo.isIOS
      ? CupertinoIcons.arrowshape_turn_up_left
      : material.Icons.reply;
  static IconData get undo => PlatformInfo.isIOS
      ? CupertinoIcons.arrow_uturn_left_circle
      : material.Icons.undo;
  static IconData get error_bubble => PlatformInfo.isIOS
      ? CupertinoIcons.exclamationmark_bubble
      : material.Icons.error_outline;
  static IconData get search =>
      PlatformInfo.isIOS ? CupertinoIcons.search : material.Icons.search;
  static IconData get settings =>
      PlatformInfo.isIOS ? CupertinoIcons.settings : material.Icons.settings;
  static IconData get slider_horizontal_3 => PlatformInfo.isIOS
      ? CupertinoIcons.slider_horizontal_3
      : material.Icons.tune;
  static IconData get smiley => PlatformInfo.isIOS
      ? CupertinoIcons.smiley
      : material.Icons.emoji_emotions_outlined;
  static IconData get speaker_slash => PlatformInfo.isIOS
      ? CupertinoIcons.speaker_slash
      : material.Icons.volume_off;
  static IconData get square_pencil => PlatformInfo.isIOS
      ? CupertinoIcons.square_pencil
      : material.Icons.edit_square;
  static IconData get xmark_circle_fill => PlatformInfo.isIOS
      ? CupertinoIcons.xmark_circle_fill
      : material.Icons.cancel;
  static IconData get xmark =>
      PlatformInfo.isIOS ? CupertinoIcons.xmark : material.Icons.close;
}

/// Platform-adaptive page route (for consistency with navigation helpers).
Route<T> adaptivePageRoute<T>(
  WidgetBuilder builder, {
  bool fullscreen = false,
}) {
  if (PlatformInfo.isIOS) {
    return CupertinoPageRoute<T>(
      builder: builder,
      fullscreenDialog: fullscreen,
    );
  }
  return material.MaterialPageRoute<T>(
    builder: builder,
    fullscreenDialog: fullscreen,
  );
}
