import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// BabyRelay design language v2 — "warm editorial nursery".
///
/// Light mode reads like a sunlit linen nursery with espresso ink and
/// terracotta accents; dark mode is a dim, warm night-light for 2am feeds.
/// Hero moments (sleep card, onboarding welcome) use deep dusk gradients so
/// the app never collapses into a single beige wash.
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
    required this.claySoft,
    required this.onClay,
    required this.sage,
    required this.sageSoft,
    required this.dusk,
    required this.duskSoft,
    required this.nightHigh,
    required this.nightLow,
    required this.onNight,
    required this.onNightSoft,
    required this.dawnHigh,
    required this.dawnLow,
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
  final Color claySoft;
  final Color onClay;

  /// Awake/positive accent.
  final Color sage;
  final Color sageSoft;

  /// Sleep accent — muted warm dusk, used for asleep states.
  final Color dusk;
  final Color duskSoft;

  /// Deep dusk gradient for sleep hero surfaces (text uses [onNight]).
  final Color nightHigh;
  final Color nightLow;
  final Color onNight;
  final Color onNightSoft;

  /// Soft dawn gradient for the awake next-up hero.
  final Color dawnHigh;
  final Color dawnLow;

  /// Highlights (next-up countdown, badges).
  final Color sun;
  final Color danger;
  final Color outline;

  /// Stable per-person and per-child accent colors.
  final List<Color> avatarPalette;

  static const light = RelayColors(
    background: Color(0xFFF7F1E6),
    surface: Color(0xFFFFFEFA),
    surfaceRaised: Color(0xFFFFFFFF),
    ink: Color(0xFF2A2018),
    inkSoft: Color(0xFF6F6052),
    inkFaint: Color(0xFFAB9B86),
    clay: Color(0xFFC26442),
    clayDeep: Color(0xFF9E4A2C),
    claySoft: Color(0xFFF6E3D7),
    onClay: Color(0xFFFFF6EF),
    sage: Color(0xFF5F7F58),
    sageSoft: Color(0xFFE3EBDA),
    dusk: Color(0xFF4D5378),
    duskSoft: Color(0xFFE3E2F0),
    nightHigh: Color(0xFF3B3659),
    nightLow: Color(0xFF232038),
    onNight: Color(0xFFF4EFE3),
    onNightSoft: Color(0xFFB6B0CE),
    dawnHigh: Color(0xFFFFF0DB),
    dawnLow: Color(0xFFFBDFBD),
    sun: Color(0xFFD6953A),
    danger: Color(0xFFB3503E),
    outline: Color(0xFFE9DECB),
    avatarPalette: [
      Color(0xFFC26442),
      Color(0xFF5F7F58),
      Color(0xFF4D5378),
      Color(0xFFD6953A),
      Color(0xFF96627E),
      Color(0xFF3F7E7B),
    ],
  );

  static const dark = RelayColors(
    background: Color(0xFF1B1713),
    surface: Color(0xFF262019),
    surfaceRaised: Color(0xFF2F2820),
    ink: Color(0xFFF2E9DA),
    inkSoft: Color(0xFFB5A896),
    inkFaint: Color(0xFF77685A),
    clay: Color(0xFFD98C61),
    clayDeep: Color(0xFFC9744A),
    claySoft: Color(0xFF3C2C21),
    onClay: Color(0xFF2B1B10),
    sage: Color(0xFF8FAA85),
    sageSoft: Color(0xFF2E3529),
    dusk: Color(0xFF9197BD),
    duskSoft: Color(0xFF2C2D3C),
    nightHigh: Color(0xFF312D4D),
    nightLow: Color(0xFF1E1B30),
    onNight: Color(0xFFF0EBDF),
    onNightSoft: Color(0xFFA9A3C2),
    dawnHigh: Color(0xFF3B2F1F),
    dawnLow: Color(0xFF2E2417),
    sun: Color(0xFFE0AC5B),
    danger: Color(0xFFD4705C),
    outline: Color(0xFF3B332A),
    avatarPalette: [
      Color(0xFFD98C61),
      Color(0xFF8FAA85),
      Color(0xFF9197BD),
      Color(0xFFE0AC5B),
      Color(0xFFBE8AA8),
      Color(0xFF6FA3A1),
    ],
  );

  Color avatarColor(int index) => avatarPalette[index % avatarPalette.length];

  LinearGradient get nightGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [nightHigh, nightLow],
  );

  LinearGradient get dawnGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [dawnHigh, dawnLow],
  );

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
      splashFactory: InkSparkle.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.clay,
        brightness: brightness,
        surface: c.surface,
        primary: c.clay,
        onPrimary: c.onClay,
        error: c.danger,
      ),
    );

    // Fraunces variable font: dial in optical size + weight per role so the
    // serif reads warm and editorial, never spindly or default-thin.
    const display = [
      FontVariation('wght', 590),
      FontVariation('opsz', 50),
      FontVariation('SOFT', 30),
    ];

    final textTheme = base.textTheme.copyWith(
      // Big editorial headline (child name, onboarding statements).
      displayMedium: TextStyle(
        fontFamily: 'Fraunces',
        fontVariations: display,
        fontSize: 38,
        letterSpacing: 0,
        height: 1.06,
        color: c.ink,
      ),
      // Hero numbers — time windows, durations.
      displaySmall: TextStyle(
        fontFamily: 'Fraunces',
        fontVariations: display,
        fontSize: 31,
        letterSpacing: 0,
        height: 1.08,
        color: c.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Fraunces',
        fontVariations: display,
        fontSize: 27,
        letterSpacing: 0,
        height: 1.14,
        color: c.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: c.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: c.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: c.ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.4, color: c.inkSoft),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: c.ink,
      ),
      labelSmall: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
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
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.clay.withValues(alpha: 0.14),
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: states.contains(WidgetState.selected)
                ? c.clayDeep
                : c.inkFaint,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? c.clayDeep
                : c.inkFaint,
            size: 25,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: c.clay,
              foregroundColor: c.onClay,
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(
                c.clayDeep.withValues(alpha: 0.25),
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
        showDragHandle: true,
        dragHandleColor: c.outline,
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
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.surface,
        dialBackgroundColor: c.background,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
