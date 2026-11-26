import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// Minimal Editorial & Clean Webtoon Panel color tokens:
/// calm, sharp, and calculatively precise across Warm Silk Cream light mode
/// and Deepest Ink / Ink Oak dark mode.
class MagnColors {
  MagnColors._();

  // Brand & Core Editorial Tokens
  static const Color deepMineralPine = Color(0xFF144542);
  static const Color inkOak = Color(0xFF202A30);
  static const Color warmSilkCream = Color(0xFFF5EDE0);
  static const Color softParchment = Color(0xFFEAE0D0);
  static const Color deepestInk = Color(0xFF161D22);
  static const Color cinnabarRed = Color(0xFFC31D2E);

  // Light Mode Surfaces & Ink
  static const Color lightBackground = warmSilkCream;
  static const Color lightDiskSurface = softParchment;
  static const Color lightDiskRim = Color(0x33202A30); // #202A30 @ 20%
  static const Color lightSurfaceCard = softParchment;
  static const Color lightInkPrimary = inkOak;
  static const Color lightInkSecondary = Color(0xFF4A555C);
  static const Color lightDivider = Color(0x33202A30); // #202A30 @ 20%
  static const Color lightHand = inkOak;
  static const Color lightHandHighlight = Color(0xFF2E3C45);
  static const Color lightHandEdge = Color(0xFF161D22);

  // Dark Mode Surfaces & Ink
  static const Color darkBackground = deepestInk;
  static const Color darkDiskSurface = inkOak;
  static const Color darkDiskRim = Color(0x26F5EDE0); // #F5EDE0 @ 15%
  static const Color darkSurfaceCard = inkOak;
  static const Color darkInkPrimary = warmSilkCream;
  static const Color darkInkSecondary = Color(0xFFB5ADA0);
  static const Color darkDivider = Color(0x26F5EDE0); // #F5EDE0 @ 15%
  static const Color darkHand = warmSilkCream;
  static const Color darkHandHighlight = Color(0xFFFFFBF4);
  static const Color darkHandEdge = Color(0xFFD9CFC0);

  // Editorial Under-Disk Palettes (harmonized with Deep Mineral Pine & Ink Oak)
  static const List<Color> pomodoroFocusGradient = [
    Color(0xFF0E322F),
    deepMineralPine,
    Color(0xFF1C5B57),
    Color(0xFF24706B),
    Color(0xFF0E322F),
  ];

  static const List<Color> pomodoroBreakGradient = [
    inkOak,
    Color(0xFF2E4348),
    Color(0xFF3E5B5D),
    Color(0xFF2E4348),
    inkOak,
  ];

  static const List<Color> focusSessionGradient = [
    deepestInk,
    inkOak,
    deepMineralPine,
    Color(0xFF1D5B56),
    deepestInk,
  ];

  static const List<Color> endlessFlowGradient = [
    deepestInk,
    Color(0xFF183836),
    deepMineralPine,
    Color(0xFF266560),
    deepestInk,
  ];

  static const List<Color> endlessRecordGradient = [
    deepMineralPine,
    inkOak,
    cinnabarRed,
    Color(0xFF8C1623),
    deepMineralPine,
  ];

  // Editorial Label Swatches
  static const List<int> labelPalette = [
    0xFF144542, // Deep Mineral Pine
    0xFF202A30, // Ink Oak
    0xFFC31D2E, // Cinnabar Red
    0xFF8C6239, // Raw Umber
    0xFF3A5A78, // Prussian Slate
    0xFF4F6D5A, // Moss Sage
    0xFF6B4E62, // Muted Plum
  ];

  static Color borderColor(BuildContext context, {bool active = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (active) {
      return isDark ? warmSilkCream.withValues(alpha: 0.72) : deepMineralPine;
    }
    return isDark ? darkDivider : lightDivider;
  }
}

class AppTheme {
  AppTheme._();

  static const double panelRadius = 10.0;
  static const double tightRadius = 8.0;
  static const double sheetRadius = 12.0;

  /// Crisp Webtoon Panel decoration with flat contrast, 8-12px corners, and
  /// 1px solid borders (1.5px for active panels) — zero blurry shadows.
  static BoxDecoration panelDecoration(
    BuildContext context, {
    bool active = false,
    double radius = panelRadius,
    Color? color,
    Color? borderColor,
  }) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? MagnColors.borderColor(context, active: active),
        width: active ? 1.5 : 1.0,
      ),
    );
  }

  /// Headings in Plus Jakarta Sans (SemiBold/Bold, -0.02em tracking).
  static TextStyle headingStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: fontSize * -0.02,
    );
  }

  /// Numbers, clocks, and timers in JetBrains Mono with tabular-nums enabled.
  static TextStyle monoStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double letterSpacing = 0.6,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextTheme _buildEditorialTextTheme(
    TextTheme base, {
    required Color primaryInk,
    required Color secondaryInk,
  }) {
    final body = GoogleFonts.interTextTheme(base).apply(
      bodyColor: primaryInk,
      displayColor: primaryInk,
    );

    TextStyle? heading(TextStyle? style, double fallbackSize, FontWeight weight) {
      final size = style?.fontSize ?? fallbackSize;
      return GoogleFonts.plusJakartaSans(
        textStyle: style,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: size * -0.02,
        color: primaryInk,
      );
    }

    return body.copyWith(
      displayLarge: heading(body.displayLarge, 57, FontWeight.w700),
      displayMedium: heading(body.displayMedium, 45, FontWeight.w700),
      displaySmall: heading(body.displaySmall, 36, FontWeight.w700),
      headlineLarge: heading(body.headlineLarge, 32, FontWeight.w700),
      headlineMedium: heading(body.headlineMedium, 28, FontWeight.w700),
      headlineSmall: heading(body.headlineSmall, 24, FontWeight.w600),
      titleLarge: heading(body.titleLarge, 20, FontWeight.w700),
      titleMedium: heading(body.titleMedium, 16, FontWeight.w600),
      titleSmall: heading(body.titleSmall, 14, FontWeight.w600),
      bodyLarge: body.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        color: primaryInk,
      ),
      bodyMedium: body.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        color: primaryInk,
      ),
      bodySmall: body.bodySmall?.copyWith(
        fontWeight: FontWeight.w400,
        color: secondaryInk,
      ),
      labelLarge: body.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        color: primaryInk,
      ),
      labelMedium: body.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: secondaryInk,
      ),
      labelSmall: body.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: secondaryInk,
      ),
    );
  }

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: MagnColors.deepMineralPine,
      onPrimary: MagnColors.warmSilkCream,
      secondary: MagnColors.inkOak,
      onSecondary: MagnColors.warmSilkCream,
      surface: MagnColors.softParchment,
      onSurface: MagnColors.inkOak,
      onSurfaceVariant: MagnColors.lightInkSecondary,
      error: MagnColors.cinnabarRed,
      onError: MagnColors.warmSilkCream,
      outline: MagnColors.lightDivider,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: MagnColors.warmSilkCream,
      colorScheme: colorScheme,
    );

    return _applySharedEditorialTheme(
      base,
      colorScheme: colorScheme,
      primaryInk: MagnColors.inkOak,
      secondaryInk: MagnColors.lightInkSecondary,
      borderColor: MagnColors.lightDivider,
      sheetBg: MagnColors.warmSilkCream,
      switchInactiveThumb: MagnColors.lightInkSecondary,
      switchInactiveTrack: MagnColors.softParchment,
    );
  }

  static ThemeData dark({bool pureOled = true}) {
    const colorScheme = ColorScheme.dark(
      primary: MagnColors.deepMineralPine,
      onPrimary: MagnColors.warmSilkCream,
      secondary: MagnColors.warmSilkCream,
      onSecondary: MagnColors.deepestInk,
      surface: MagnColors.inkOak,
      onSurface: MagnColors.warmSilkCream,
      onSurfaceVariant: MagnColors.darkInkSecondary,
      error: MagnColors.cinnabarRed,
      onError: MagnColors.warmSilkCream,
      outline: MagnColors.darkDivider,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: MagnColors.deepestInk,
      colorScheme: colorScheme,
    );

    return _applySharedEditorialTheme(
      base,
      colorScheme: colorScheme,
      primaryInk: MagnColors.warmSilkCream,
      secondaryInk: MagnColors.darkInkSecondary,
      borderColor: MagnColors.darkDivider,
      sheetBg: MagnColors.deepestInk,
      switchInactiveThumb: MagnColors.darkInkSecondary,
      switchInactiveTrack: MagnColors.inkOak,
    );
  }

  static ThemeData _applySharedEditorialTheme(
    ThemeData base, {
    required ColorScheme colorScheme,
    required Color primaryInk,
    required Color secondaryInk,
    required Color borderColor,
    required Color sheetBg,
    required Color switchInactiveThumb,
    required Color switchInactiveTrack,
  }) {
    final textTheme = _buildEditorialTextTheme(
      base.textTheme,
      primaryInk: primaryInk,
      secondaryInk: secondaryInk,
    );

    final panelShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(panelRadius),
      side: BorderSide(color: borderColor, width: 1),
    );

    return base.copyWith(
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheetBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(sheetRadius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: sheetBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(sheetRadius),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MagnColors.inkOak,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: MagnColors.warmSilkCream,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(panelRadius),
          side: BorderSide(
            color: MagnColors.warmSilkCream.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MagnColors.deepMineralPine,
          foregroundColor: MagnColors.warmSilkCream,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(panelRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.brightness == Brightness.dark
              ? MagnColors.warmSilkCream
              : MagnColors.deepMineralPine,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tightRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 13.5,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: MagnColors.deepMineralPine,
        labelStyle: textTheme.labelMedium?.copyWith(color: primaryInk),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: MagnColors.warmSilkCream,
        ),
        checkmarkColor: MagnColors.warmSilkCream,
        side: BorderSide(color: borderColor, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tightRadius),
        ),
        elevation: 0,
        pressElevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? MagnColors.warmSilkCream
              : switchInactiveThumb,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? MagnColors.deepMineralPine
              : switchInactiveTrack,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? MagnColors.deepMineralPine
              : borderColor,
        ),
        trackOutlineWidth: WidgetStateProperty.all(1.0),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: MagnColors.deepMineralPine,
        inactiveTrackColor: borderColor,
        thumbColor: MagnColors.deepMineralPine,
        overlayColor: MagnColors.deepMineralPine.withValues(alpha: 0.12),
        trackHeight: 3.0,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: panelShape,
      ),
    );
  }
}
