import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_theme_extension.dart';

/// Single source of truth for the customer app's Material 3 theme.
///
/// Wire it into the app root once:
///
/// ```dart
/// MaterialApp(
///   theme: AppTheme.lightTheme,
///   darkTheme: AppTheme.darkTheme,
///   themeMode: ThemeMode.system,
/// );
/// ```
///
/// From there, every widget reads colors and text styles via `Theme.of(context)`
/// and the [AppCustomColors] extension — no hardcoded hex, no per-widget
/// brightness checks.
class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = _colorScheme(brightness);
    final textTheme = _textTheme(colorScheme);
    final customColors =
        isDark ? AppCustomColors.dark : AppCustomColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      canvasColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[customColors],

      // ---- Components ----------------------------------------------------
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: appSystemOverlay(brightness),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.terracotta,
          foregroundColor: Colors.white,
          disabledBackgroundColor: customColors.dividerSoft,
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          elevation: 0,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.terracotta,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.terracotta,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: AppColors.terracotta, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.terracotta,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: customColors.dividerSoft,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: customColors.imageBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.terracotta, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightTextPrimary,
        contentTextStyle: GoogleFonts.inter(
          color: isDark ? AppColors.darkTextPrimary : Colors.white,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      iconTheme: IconThemeData(color: colorScheme.onSurface, size: 22),
    );
  }

  // ---------------------------------------------------------------------------
  // ColorScheme — explicit construction (not `fromSeed`) so the brand stays
  // exactly on-spec instead of being interpolated by Material's tonal palette.
  // ---------------------------------------------------------------------------
  static ColorScheme _colorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ColorScheme(
      brightness: brightness,
      primary: AppColors.terracotta,
      onPrimary: Colors.white,
      primaryContainer: AppColors.terracottaDeep,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.terracotta,
      onSecondary: Colors.white,
      secondaryContainer:
          isDark ? AppColors.darkSurface : AppColors.lightImageBg,
      onSecondaryContainer:
          isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      tertiary: AppColors.terracottaDeep,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface:
          isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      surfaceContainerLowest:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      surfaceContainerLow:
          isDark ? AppColors.darkSurface : AppColors.lightSurface,
      surfaceContainer:
          isDark ? AppColors.darkSurface : AppColors.lightSurface,
      surfaceContainerHigh:
          isDark ? AppColors.darkImageBg : AppColors.lightImageBg,
      surfaceContainerHighest:
          isDark ? AppColors.darkImageBg : AppColors.lightImageBg,
      onSurfaceVariant:
          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      outline: isDark ? AppColors.darkDivider : AppColors.lightDivider,
      outlineVariant:
          isDark ? AppColors.darkDivider : AppColors.lightDivider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface:
          isDark ? AppColors.lightSurface : AppColors.darkSurface,
      onInverseSurface:
          isDark ? AppColors.lightTextPrimary : AppColors.darkTextPrimary,
      inversePrimary: AppColors.terracottaDeep,
      surfaceTint: Colors.transparent,
    );
  }

  // ---------------------------------------------------------------------------
  // Text theme — Playfair Display for headlines, Inter for body/UI.
  //
  // Color is bound to `colorScheme.onSurface` (primary) or `onSurfaceVariant`
  // (secondary) so a single text style flips correctly between light/dark.
  // ---------------------------------------------------------------------------
  static TextTheme _textTheme(ColorScheme scheme) {
    final primary = scheme.onSurface;
    final secondary = scheme.onSurfaceVariant;

    final display = GoogleFonts.playfairDisplayTextTheme();
    final body = GoogleFonts.interTextTheme();

    return TextTheme(
      // Playfair Display — editorial headlines.
      displayLarge: display.displayLarge?.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      displayMedium: display.displayMedium?.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      displaySmall: display.displaySmall?.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
      ),

      // Inter — UI titles, body, and labels.
      titleLarge: body.titleLarge?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: body.titleMedium?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: body.titleSmall?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: primary, height: 1.4),
      bodyMedium: body.bodyMedium?.copyWith(color: primary, height: 1.4),
      bodySmall: body.bodySmall?.copyWith(color: secondary, height: 1.35),
      labelLarge: body.labelLarge?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: body.labelMedium?.copyWith(color: secondary),
      labelSmall: body.labelSmall?.copyWith(color: secondary),
    );
  }
}

/// Status / system-navigation bar styling for the given theme brightness.
///
/// Dark theme → light icons (visible on dark backgrounds).
/// Light theme → dark icons (visible on the cream/white backgrounds).
///
/// Used by both the customer and seller `AppBarTheme.systemOverlayStyle` and
/// by the `AnnotatedRegion` wrapper in each `MaterialApp.builder`, so screens
/// without an `AppBar` (e.g. the profile guest screen with its custom
/// header) still get the right contrast.
SystemUiOverlayStyle appSystemOverlay(Brightness themeBrightness) {
  final isDark = themeBrightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}
