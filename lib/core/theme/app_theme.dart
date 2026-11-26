import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens inspired by physical rotating-aperture desk clocks:
/// architectural off-white matte surfaces in Light Mode and pure OLED matte
/// charcoal/black in Dark Mode.
class MagnColors {
  MagnColors._();

  // Light Mode Surfaces
  static const Color lightBackground = Color(0xFFECEEF1);
  static const Color lightDiskSurface = Color(0xFFF7F8FA);
  static const Color lightDiskRim = Color(0xFFE2E5EA);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightInkPrimary = Color(0xFF14161A);
  static const Color lightInkSecondary = Color(0xFF646B78);
  static const Color lightDivider = Color(0xFFE0E3E8);
  static const Color lightHand = Color(0xFFD6D9DF);
  static const Color lightHandHighlight = Color(0xFFFDFEFF);
  static const Color lightHandEdge = Color(0xFFBCC1CA);

  // Dark / OLED Pure Black Surfaces
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkDiskSurface = Color(0xFF121316);
  static const Color darkDiskRim = Color(0xFF23262D);
  static const Color darkSurfaceCard = Color(0xFF14161A);
  static const Color darkInkPrimary = Color(0xFFF3F5F8);
  static const Color darkInkSecondary = Color(0xFF8B92A0);
  static const Color darkDivider = Color(0xFF22262E);
  static const Color darkHand = Color(0xFFE3E7EF);
  static const Color darkHandHighlight = Color(0xFFFFFFFF);
  static const Color darkHandEdge = Color(0xFF9EA6B5);

  // Mode Gradient Palettes (WCAG contrast-safe & physically luminous like the reference clock)
  // Pomodoro Focus: Deep Cobalt → Royal Blue → Luminous Cyan
  static const List<Color> pomodoroFocusGradient = [
    Color(0xFF0A1D8F),
    Color(0xFF0038FF),
    Color(0xFF0077FF),
    Color(0xFF18B8F0),
    Color(0xFF0A1D8F),
  ];

  // Pomodoro Break: Warm Sunrise Amber → Coral → Bright Solar Gold (matches lower reference clock frames)
  static const List<Color> pomodoroBreakGradient = [
    Color(0xFF7B1F5C),
    Color(0xFFE84A27),
    Color(0xFFFF9500),
    Color(0xFFFFD60A),
    Color(0xFF7B1F5C),
  ];

  // Focus Session: Deep Slate → Teal → Vivid Emerald
  static const List<Color> focusSessionGradient = [
    Color(0xFF0D2830),
    Color(0xFF0F6B6E),
    Color(0xFF10B981),
    Color(0xFF34D399),
    Color(0xFF0D2830),
  ];

  // Endless Flow (before beating record): Deep Midnight Indigo → Electric Violet
  static const List<Color> endlessFlowGradient = [
    Color(0xFF1B104B),
    Color(0xFF4C1D95),
    Color(0xFF7C3AED),
    Color(0xFFA855F7),
    Color(0xFF1B104B),
  ];

  // Endless Flow (surpassed ghost record): Royal Violet → Burnished Gold
  static const List<Color> endlessRecordGradient = [
    Color(0xFF4C1D95),
    Color(0xFFC2410C),
    Color(0xFFF59E0B),
    Color(0xFFFDE047),
    Color(0xFF4C1D95),
  ];

  // Default Label Colors
  static const List<int> labelPalette = [
    0xFF2563EB, // Cobalt
    0xFF059669, // Emerald
    0xFFD97706, // Amber
    0xFF7C3AED, // Violet
    0xFFE11D48, // Rose
    0xFF0891B2, // Cyan
    0xFF475569, // Slate
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: MagnColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: MagnColors.lightInkPrimary,
        onPrimary: Colors.white,
        secondary: Color(0xFF0047FF),
        onSecondary: Colors.white,
        surface: MagnColors.lightSurfaceCard,
        onSurface: MagnColors.lightInkPrimary,
        outline: MagnColors.lightDivider,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: MagnColors.lightInkPrimary,
        displayColor: MagnColors.lightInkPrimary,
      ),
      dividerTheme: const DividerThemeData(
        color: MagnColors.lightDivider,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MagnColors.lightSurfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : MagnColors.lightInkSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? MagnColors.lightInkPrimary
              : MagnColors.lightDiskRim,
        ),
      ),
    );
  }

  static ThemeData dark({bool pureOled = true}) {
    final bg = pureOled ? MagnColors.darkBackground : const Color(0xFF0E1014);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        primary: MagnColors.darkInkPrimary,
        onPrimary: Colors.black,
        secondary: const Color(0xFF3B82F6),
        onSecondary: Colors.white,
        surface: MagnColors.darkSurfaceCard,
        onSurface: MagnColors.darkInkPrimary,
        outline: MagnColors.darkDivider,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: MagnColors.darkInkPrimary,
        displayColor: MagnColors.darkInkPrimary,
      ),
      dividerTheme: const DividerThemeData(
        color: MagnColors.darkDivider,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MagnColors.darkSurfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.black
              : MagnColors.darkInkSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? MagnColors.darkInkPrimary
              : MagnColors.darkDiskRim,
        ),
      ),
    );
  }

  static TextStyle monoStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double letterSpacing = 1.2,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
