import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Colors that change with light/dark mode but aren't part of [ColorScheme].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.card,
    required this.cardAlt,
    required this.border,
    required this.ink,
    required this.inkSoft,
    required this.inkMuted,
    required this.brandTint,
    required this.shadow,
  });

  final Color background;
  final Color card;
  final Color cardAlt;
  final Color border;
  final Color ink;
  final Color inkSoft;
  final Color inkMuted;
  final Color brandTint;
  final Color shadow;

  static const light = AppPalette(
    background: AppColors.cream,
    card: AppColors.surface,
    cardAlt: AppColors.surfaceAlt,
    border: AppColors.outline,
    ink: AppColors.ink,
    inkSoft: AppColors.inkSoft,
    inkMuted: AppColors.inkMuted,
    brandTint: AppColors.limeSoft,
    shadow: Color(0x143B2A20),
  );

  static const dark = AppPalette(
    background: AppColors.night,
    card: AppColors.nightSurface,
    cardAlt: AppColors.nightSurfaceAlt,
    border: AppColors.nightOutline,
    ink: AppColors.nightInk,
    inkSoft: AppColors.nightInkSoft,
    inkMuted: Color(0xFF7D8A73),
    brandTint: Color(0xFF3A241C),
    shadow: Color(0x40000000),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardAlt: Color.lerp(cardAlt, other.cardAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      brandTint: Color.lerp(brandTint, other.brandTint, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension ThemeX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

abstract final class AppTheme {
  static const _display = 'Poppins';
  static const _body = 'Inter';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final p = isDark ? AppPalette.dark : AppPalette.light;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.terracottaLight : AppColors.forest,
      onPrimary: isDark ? AppColors.forestDeep : Colors.white,
      primaryContainer: p.brandTint,
      onPrimaryContainer: isDark ? AppColors.terracottaLight : AppColors.forestDark,
      secondary: AppColors.amber,
      onSecondary: AppColors.ink,
      secondaryContainer: isDark ? const Color(0xFF3A2F0A) : AppColors.amberSoft,
      onSecondaryContainer: isDark ? AppColors.amber : const Color(0xFF6B4F00),
      tertiary: AppColors.pinkDeep,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: p.card,
      onSurface: p.ink,
      onSurfaceVariant: p.inkSoft,
      outline: p.border,
      outlineVariant: p.border,
      surfaceContainerHighest: p.cardAlt,
      surfaceContainerHigh: p.cardAlt,
      surfaceContainer: p.card,
      surfaceContainerLow: p.card,
      surfaceContainerLowest: p.background,
      shadow: p.shadow,
    );

    final text = TextTheme(
      displayLarge: TextStyle(fontFamily: _display, fontSize: 40, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -1, color: p.ink),
      displayMedium: TextStyle(fontFamily: _display, fontSize: 32, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.6, color: p.ink),
      displaySmall: TextStyle(fontFamily: _display, fontSize: 26, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.4, color: p.ink),
      headlineMedium: TextStyle(fontFamily: _display, fontSize: 22, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.2, color: p.ink),
      headlineSmall: TextStyle(fontFamily: _display, fontSize: 19, fontWeight: FontWeight.w600, height: 1.3, color: p.ink),
      titleLarge: TextStyle(fontFamily: _display, fontSize: 17, fontWeight: FontWeight.w600, height: 1.3, color: p.ink),
      titleMedium: TextStyle(fontFamily: _body, fontSize: 15, fontWeight: FontWeight.w600, height: 1.35, color: p.ink),
      titleSmall: TextStyle(fontFamily: _body, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35, color: p.ink),
      bodyLarge: TextStyle(fontFamily: _body, fontSize: 15, fontWeight: FontWeight.w400, height: 1.5, color: p.ink),
      bodyMedium: TextStyle(fontFamily: _body, fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.45, color: p.inkSoft),
      bodySmall: TextStyle(fontFamily: _body, fontSize: 12, fontWeight: FontWeight.w400, height: 1.4, color: p.inkMuted),
      labelLarge: TextStyle(fontFamily: _body, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: p.ink),
      labelMedium: TextStyle(fontFamily: _body, fontSize: 12.5, fontWeight: FontWeight.w600, color: p.inkSoft),
      labelSmall: TextStyle(fontFamily: _body, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: p.inkMuted),
    );

    final radius = BorderRadius.circular(16);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      fontFamily: _body,
      textTheme: text,
      extensions: [p],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()},
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: p.ink,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? p.cardAlt : const Color(0xFFF5EFE8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: text.bodyMedium?.copyWith(color: p.inkMuted),
        labelStyle: text.bodyMedium,
        floatingLabelStyle: text.labelMedium?.copyWith(color: scheme.primary),
        prefixIconColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.error)
              ? AppColors.danger
              : s.contains(WidgetState.focused)
              ? scheme.primary
              : p.inkMuted,
        ),
        suffixIconColor: p.inkMuted,
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        errorStyle: text.bodySmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w500),
        errorMaxLines: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: p.ink,
          side: BorderSide(color: p.border, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary, textStyle: text.labelLarge?.copyWith(fontSize: 14)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.card,
        selectedColor: scheme.primary,
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        labelStyle: text.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.border,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.nightSurfaceAlt : AppColors.forestDeep,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: p.inkMuted, width: 1.5),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : p.inkMuted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.primary : p.cardAlt),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? AppColors.forestDeep : Colors.white,
        unselectedLabelColor: p.inkSoft,
        labelStyle: text.labelLarge?.copyWith(fontSize: 14),
        unselectedLabelStyle: text.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(14)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.forest,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: p.cardAlt),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.forest, foregroundColor: Colors.white, elevation: 4),
      listTileTheme: ListTileThemeData(
        iconColor: p.inkSoft,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
