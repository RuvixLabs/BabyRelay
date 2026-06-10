import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// BabyRelay design language: warm linen and clay, not SaaS purple-blue.
/// Light mode feels like a sunlit nursery; dark mode is a dim, warm night
/// light for 2am feeds.
class RelayColors extends ThemeExtension<RelayColors> {
  const RelayColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.clay,
    required this.clayDeep,
    required this.onClay,
    required this.sage,
    required this.sageSoft,
    required this.dusk,
    required this.duskSoft,
    required this.sun,
    required this.danger,
    required this.outline,
    required this.avatarPalette,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;

  /// Primary action color — warm clay/terracotta.
  final Color clay;
  final Color clayDeep;
  final Color onClay;

  /// Awake/positive accent.
  final Color sage;
  final Color sageSoft;

  /// Sleep accent — muted warm dusk, used for asleep states.
  final Color dusk;
  final Color duskSoft;

  /// Highlights (next-up countdown, badges).
  final Color sun;
  final Color danger;
  final Color outline;
  final List<Color> avatarPalette;

  static const light = RelayColors(
    background: Color(0xFFF8F3EB),
    surface: Color(0xFFFFFDF8),
    surfaceRaised: Color(0xFFFFFFFF),
    ink: Color(0xFF33281F),
    inkSoft: Color(0xFF7A6B5C),
    inkFaint: Color(0xFFB3A593),
    clay: Color(0xFFC8744B),
    clayDeep: Color(0xFFA85A36),
    onClay: Color(0xFFFFF8F2),
    sage: Color(0xFF6E8C66),
    sageSoft: Color(0xFFE4EBDF),
    dusk: Color(0xFF5C6488),
    duskSoft: Color(0xFFE3E2EF),
    sun: Color(0xFFD99E45),
    danger: Color(0xFFB3503E),
    outline: Color(0xFFE9DfD0),
    avatarPalette: [
      Color(0xFFC8744B),
      Color(0xFF6E8C66),
      Color(0xFF5C6488),
      Color(0xFFD99E45),
      Color(0xFF9C6B8E),
      Color(0xFF4E8C8A),
    ],
  );

  static const dark = RelayColors(
    background: Color(0xFF1E1A16),
    surface: Color(0xFF28221D),
    surfaceRaised: Color(0xFF322B24),
    ink: Color(0xFFF0E7DA),
    inkSoft: Color(0xFFB5A896),
    inkFaint: Color(0xFF77685A),
    clay: Color(0xFFD78D62),
    clayDeep: Color(0xFFC8744B),
    onClay: Color(0xFF2B1B10),
    sage: Color(0xFF8FAA85),
    sageSoft: Color(0xFF31392E),
    dusk: Color(0xFF8B92B8),
    duskSoft: Color(0xFF2D2E3D),
    sun: Color(0xFFE0AC5B),
    danger: Color(0xFFD4705C),
    outline: Color(0xFF3D352C),
    avatarPalette: [
      Color(0xFFD78D62),
      Color(0xFF8FAA85),
      Color(0xFF8B92B8),
      Color(0xFFE0AC5B),
      Color(0xFFB587A8),
      Color(0xFF6FA3A1),
    ],
  );

  Color avatarColor(int index) => avatarPalette[index % avatarPalette.length];

  @override
  RelayColors copyWith() => this;

  @override
  RelayColors lerp(ThemeExtension<RelayColors>? other, double t) =>
      t < 0.5 ? this : (other as RelayColors? ?? this);
}

extension RelayColorsX on BuildContext {
  RelayColors get relay => Theme.of(this).extension<RelayColors>()!;
}

class RelayTheme {
  static ThemeData light() => _build(RelayColors.light, Brightness.light);
  static ThemeData dark() => _build(RelayColors.dark, Brightness.dark);

  static ThemeData _build(RelayColors c, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.clay,
        brightness: brightness,
        surface: c.surface,
        primary: c.clay,
        onPrimary: c.onClay,
        error: c.danger,
      ),
    );

    final textTheme = base.textTheme.copyWith(
      displayMedium: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.05,
        color: c.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.1,
        color: c.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: c.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: c.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: c.ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.4, color: c.inkSoft),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: c.ink,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: c.inkSoft,
      ),
    );

    return base.copyWith(
      extensions: [c],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        titleTextStyle: textTheme.titleLarge,
      ),
      dividerTheme: DividerThemeData(color: c.outline, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.clay.withValues(alpha: 0.16),
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.inkSoft,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? c.clayDeep
                : c.inkSoft,
            size: 26,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.clay,
          foregroundColor: c.onClay,
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.clayDeep,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.clay, width: 2),
        ),
        hintStyle: TextStyle(color: c.inkFaint),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: TextStyle(color: c.background, fontSize: 15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
