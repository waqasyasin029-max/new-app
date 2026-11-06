import 'package:flutter/material.dart' hide Text;

import 'i18n.dart';

class AppColors {
  /// True while the dark theme is active. Set by the app before building.
  static bool dark = false;

  // Brand colours: identical in both themes.
  static const primary = Color(0xFF0E9F78);
  static const gold = Color(0xFFF5B301);
  static const danger = Color(0xFFE5484D);

  // Everything below changes with the theme.
  static Color get ink =>
      dark ? const Color(0xFFF2F5F9) : const Color(0xFF111827);
  static Color get muted =>
      dark ? const Color(0xFF9AA7B8) : const Color(0xFF6B7280);
  static Color get line =>
      dark ? const Color(0xFF283445) : const Color(0xFFE6ECEE);
  static Color get surface => dark ? const Color(0xFF18212D) : Colors.white;
  static Color get bgTop =>
      dark ? const Color(0xFF0C131C) : const Color(0xFFEAF3F4);
  static Color get bgBottom =>
      dark ? const Color(0xFF160F1B) : const Color(0xFFFCEBEC);
  static Color get mint =>
      dark ? const Color(0xFF1F4D3E) : const Color(0xFFCDEFD8);
  static Color get sky =>
      dark ? const Color(0xFF1F4759) : const Color(0xFFC5E8F2);
  static Color get peach =>
      dark ? const Color(0xFF5B4222) : const Color(0xFFFFD9A0);
  static Color get lavender =>
      dark ? const Color(0xFF3E3772) : const Color(0xFFD3C8FF);
  static Color get rose =>
      dark ? const Color(0xFF5B2E4F) : const Color(0xFFF9CDEF);
  static Color get navy =>
      dark ? const Color(0xFF2C3B57) : const Color(0xFF0B1220);

  /// Translucent white chip on top of a coloured card.
  static Color get softWhite =>
      dark ? const Color(0x2EFFFFFF) : const Color(0x8AFFFFFF);
  static Color get noteBg =>
      dark ? const Color(0xFF3A3217) : const Color(0xFFFFF6DC);
  static Color get fieldFill =>
      dark ? const Color(0xFF1F2937) : const Color(0xFFEFF4F5);
  static Color get disabledBg =>
      dark ? const Color(0xFF202A38) : const Color(0xFFF1F4F5);
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
    fontFamily: 'Inter',
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
        fontFamily: 'Inter',
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
          fontFamily: 'Inter',
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
          fontFamily: 'Inter',
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
