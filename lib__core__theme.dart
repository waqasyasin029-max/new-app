import 'package:flutter/material.dart' hide Text;

import 'i18n.dart';

class AppColors {
  /// True while the dark theme is active. Set by the app before building.
  static bool dark = false;

  // Brand colours: identical in both themes.
  static const primary = Color(0xFFEE6F2B);
  static const primaryDeep = Color(0xFFE8602C);
  static const primarySoft = Color(0xFFF5A032);
  static const gold = Color(0xFFF5B301);
  static const danger = Color(0xFFE5484D);

  /// Money coming in / everything is fine.
  static const positive = Color(0xFF16A34A);

  /// Orange gradient used for the main card, the mic button and highlights.
  static const gradient = LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: [primaryDeep, primarySoft],
  );

  // Everything below changes with the theme.
  static Color get ink =>
      dark ? const Color(0xFFF4F4F6) : const Color(0xFF16161A);
  static Color get muted =>
      dark ? const Color(0xFF9A9AA6) : const Color(0xFF8B8B95);
  static Color get line =>
      dark ? const Color(0xFF2C2D34) : const Color(0xFFE9E9ED);
  static Color get surface => dark ? const Color(0xFF1A1B20) : Colors.white;
  static Color get bgTop =>
      dark ? const Color(0xFF0E0F12) : const Color(0xFFF8F8FA);
  static Color get bgBottom =>
      dark ? const Color(0xFF131418) : const Color(0xFFEFEFF3);

  /// Small tiles and account cards: clean white (light) or a lifted grey (dark).
  static Color get tile => dark ? const Color(0xFF1F2026) : Colors.white;
  static Color get mint => tile;
  static Color get sky => tile;
  static Color get peach => tile;
  static Color get lavender => tile;
  static Color get rose => tile;
  static Color get navy =>
      dark ? const Color(0xFF2B2C34) : const Color(0xFF17181D);

  /// Translucent white chip on top of the orange card.
  static Color get softWhite => const Color(0x38FFFFFF);
  static Color get noteBg =>
      dark ? const Color(0xFF3A2E1C) : const Color(0xFFFFF4E5);
  static Color get fieldFill =>
      dark ? const Color(0xFF22232A) : const Color(0xFFF0F0F4);
  static Color get disabledBg =>
      dark ? const Color(0xFF23242B) : const Color(0xFFF3F3F6);
}

/// Soft gradient behind every screen (pastel in light, deep navy in dark).
class AppBackground extends StatelessWidget {
  final Widget? child;
  const AppBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.bgTop, AppColors.bgBottom],
      ),
    ),
    child: child,
  );
}

OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(16),
  borderSide: BorderSide(color: c, width: w),
);

/// Rounded pill border for search boxes.
OutlineInputBorder pillBorder() => OutlineInputBorder(
  borderRadius: BorderRadius.circular(30),
  borderSide: BorderSide.none,
);

/// Builds the theme for the current [AppColors.dark] value.
ThemeData buildAppTheme() {
  final dark = AppColors.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: AppColors.primary,
        error: AppColors.danger,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.muted,
        outline: AppColors.line,
        outlineVariant: AppColors.line,
        surfaceContainerLowest: AppColors.surface,
        surfaceContainerLow: AppColors.surface,
        surfaceContainer: AppColors.surface,
        surfaceContainerHigh: AppColors.surface,
        surfaceContainerHighest: AppColors.fieldFill,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Manrope',
    fontFamilyFallback: L10n.fallbackFonts,
  );
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontFamilyFallback: L10n.fallbackFonts,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      iconTheme: IconThemeData(color: AppColors.ink),
    ),
    iconTheme: IconThemeData(color: AppColors.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _border(AppColors.line),
      enabledBorder: _border(AppColors.line),
      focusedBorder: _border(AppColors.primary, 1.6),
      errorBorder: _border(AppColors.danger),
      focusedErrorBorder: _border(AppColors.danger, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: TextStyle(
          fontFamily: 'Manrope',
          fontFamilyFallback: L10n.fallbackFonts,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: TextStyle(
          fontFamily: 'Manrope',
          fontFamilyFallback: L10n.fallbackFonts,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: AppColors.primary.withOpacity(0.14),
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.line,
      space: 1,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      actionTextColor: AppColors.gold,
      contentTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontFamilyFallback: L10n.fallbackFonts,
        fontSize: 14,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    // Popups, pickers and menus use the same surface, radius and colours as
    // the screens, so nothing looks like stock Android.
    canvasColor: AppColors.surface,
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: AppColors.line),
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontFamilyFallback: L10n.fallbackFonts,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      contentTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontFamilyFallback: L10n.fallbackFonts,
        fontSize: 14.5,
        height: 1.4,
        color: AppColors.muted,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.line),
      ),
      textStyle: TextStyle(
        fontFamily: 'Manrope',
        fontFamilyFallback: L10n.fallbackFonts,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.primary,
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: AppColors.surface,
      dialBackgroundColor: AppColors.fieldFill,
      hourMinuteColor: AppColors.fieldFill,
      hourMinuteTextColor: AppColors.ink,
      dialTextColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.line,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.line,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.transparent,
      ),
      checkColor: WidgetStateProperty.all<Color?>(Colors.white),
      side: BorderSide(color: AppColors.muted, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
        side: BorderSide(color: AppColors.line),
        textStyle: TextStyle(
          fontFamily: 'Manrope',
          fontFamilyFallback: L10n.fallbackFonts,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary.withOpacity(0.18),
      side: BorderSide(color: AppColors.line),
      shape: const StadiumBorder(),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontFamily: 'Manrope',
        fontFamilyFallback: L10n.fallbackFonts,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.line,
      circularTrackColor: AppColors.line,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12.5),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionHandleColor: AppColors.primary,
      selectionColor: AppColors.primary.withOpacity(0.25),
    ),
  );
}

/// White rounded card with a hairline border (replaces Material Card).
class AppCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.padding,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? AppColors.surface,
        elevation: AppColors.dark ? 0 : 1.5,
        shadowColor: const Color(0x26000000),
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: borderColor ?? AppColors.line,
            width: borderColor == null ? 1 : 1.6,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

/// Several rows inside one card, separated by thin dividers.
class TileGroup extends StatelessWidget {
  final List<Widget> children;
  const TileGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
      ],
    ),
  );
}

class ProgressRing extends StatelessWidget {
  final double value;
  final String label;
  final String caption;
  final Color color;
  final double size;
  const ProgressRing({
    super.key,
    required this.value,
    required this.label,
    required this.caption,
    this.color = AppColors.primary,
    this.size = 92,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 8,
            strokeCap: StrokeCap.round,
            backgroundColor: color.withOpacity(0.15),
            color: color,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              caption,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ],
    ),
  );
}
