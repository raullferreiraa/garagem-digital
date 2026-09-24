import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const canvas = Color(0xFF0C0E11);
  static const surface = Color(0xFF121519);
  static const surfaceRaised = Color(0xFF191D22);
  static const surfaceStrong = Color(0xFF242A31);
  static const primary = Color(0xFFFF642E);
  static const onPrimary = Color(0xFF2A0B00);
  static const secondary = Color(0xFFADC4D1);
  static const text = Color(0xFFF6F2EA);
  static const textMuted = Color(0xFFA8B0BA);
  static const outline = Color(0xFF343A44);
}

abstract final class AppTheme {
  static ThemeData get dark {
    final colors = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.surfaceStrong,
      onPrimaryContainer: const Color(0xFFFFB69E),
      secondary: AppColors.secondary,
      secondaryContainer: AppColors.surfaceStrong,
      onSecondaryContainer: AppColors.text,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.outline,
      outlineVariant: AppColors.outline.withValues(alpha: 0.66),
      surfaceContainerLowest: AppColors.canvas,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surfaceRaised,
      surfaceContainerHigh: AppColors.surfaceStrong,
      surfaceContainerHighest: const Color(0xFF2B313A),
    );

    final base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: colors,
      scaffoldBackgroundColor: AppColors.canvas,
      useMaterial3: true,
      fontFamily: 'Manrope',
      visualDensity: VisualDensity.standard,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: const TextStyle(
          fontFamily: 'BarlowCondensed',
          fontSize: 64,
          fontWeight: FontWeight.w700,
          height: 1.02,
          letterSpacing: -0.5),
      displayMedium: const TextStyle(
          fontFamily: 'BarlowCondensed',
          fontSize: 52,
          fontWeight: FontWeight.w700,
          height: 1.05),
      displaySmall: const TextStyle(
          fontFamily: 'BarlowCondensed',
          fontSize: 44,
          fontWeight: FontWeight.w700,
          height: 1.06),
      headlineLarge: const TextStyle(
          fontFamily: 'BarlowCondensed',
          fontSize: 38,
          fontWeight: FontWeight.w600,
          height: 1.1),
      headlineMedium: const TextStyle(
          fontFamily: 'BarlowCondensed',
          fontSize: 32,
          fontWeight: FontWeight.w600,
          height: 1.1),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontFamily: 'BarlowCondensed',
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.15,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontFamily: 'BarlowCondensed',
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.15,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.5),
      bodyMedium:
          base.textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.5),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.canvas,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.canvas,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: inputBorder(colors.outlineVariant),
        enabledBorder: inputBorder(colors.outlineVariant),
        focusedBorder: inputBorder(colors.primary, 1.5),
        errorBorder: inputBorder(colors.error),
        focusedErrorBorder: inputBorder(colors.error, 1.5),
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
        errorMaxLines: 3,
        helperMaxLines: 3,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: colors.surfaceContainerLow,
        indicatorColor: colors.primary.withValues(alpha: 0.13),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.primary.withValues(alpha: 0.32)),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surfaceContainer,
        selectedColor: colors.primary,
        checkmarkColor: colors.onPrimary,
        labelStyle: textTheme.labelLarge!.copyWith(
          fontSize: 12,
          color: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? colors.onPrimary
                  : colors.onSurfaceVariant),
        ),
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: colors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: textTheme.bodyMedium,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: colors.onSurface),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: .25),
        selectionHandleColor: colors.primary,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainer,
        modalBackgroundColor: colors.surfaceContainer,
        showDragHandle: true,
        dragHandleColor: colors.onSurfaceVariant.withValues(alpha: .5),
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.surfaceContainerHighest,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: colors.onSurface),
        actionTextColor: colors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
      ),
    );
  }
}
