/// ثيم FinAcc — Material 3 من البذرة المالية `0xFF00695C` (SRS §0.3).
///
/// - وضعان فاتح/داكن يتبعان نظام التشغيل (FR-13-05).
/// - زوايا ملزمة: بطاقات 16dp وأزرار 12dp (§0.3).
/// - أهداف لمس ≥ 48dp عبر الحد الأدنى للأزرار (DS-29).
/// - الافتراضي التوصيفي (§6.1): ثيم داكن مريح لعين تعمل ساعات طويلة.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// مُنشئ الثيمات الكاملة.
class FinTheme {
  const FinTheme._();

  /// البذرة اللونية الرسمية المعتمدة في SRS v1.5.
  static const Color seed = Color(0xFF00695C);

  /// الثيم الفاتح.
  ///
  /// [highContrast] (UX-2a — `ui.high_contrast`): أسطح صافية (أبيض/أسود
  /// خالص) ونصوص بأقصى تباين وحدود أقوى — إتاحة FR-13-05 لضعاف البصر.
  static ThemeData light({bool highContrast = false}) =>
      _build(Brightness.light, highContrast: highContrast);

  /// الثيم الداكن (المريح لجلسات العمل الطويلة — §6.1).
  static ThemeData dark({bool highContrast = false}) =>
      _build(Brightness.dark, highContrast: highContrast);

  static ThemeData _build(Brightness brightness, {bool highContrast = false}) {
    var scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness)
        .copyWith(
          // أسطح فاخرة: ورقة بلمسة نعناعية في الفاتح، وأخضر عميق في الداكن.
          surface: brightness == Brightness.light
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF101C18),
          surfaceContainerLowest: brightness == Brightness.light
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF0C1512),
          surfaceContainerLow: brightness == Brightness.light
              ? const Color(0xFFEFF5F2)
              : const Color(0xFF142220),
          surfaceContainer: brightness == Brightness.light
              ? const Color(0xFFE9F0EC)
              : const Color(0xFF182622),
          surfaceContainerHigh: brightness == Brightness.light
              ? const Color(0xFFE2EBE6)
              : const Color(0xFF1D2C27),
          surfaceContainerHighest: brightness == Brightness.light
              ? const Color(0xFFDCE6E0)
              : const Color(0xFF213129),
          surfaceDim: brightness == Brightness.light
              ? const Color(0xFFD7E2DC)
              : const Color(0xFF0A1310),
          surfaceBright: brightness == Brightness.light
              ? const Color(0xFFFBFDFC)
              : const Color(0xFF3A4A44),
          // الخلفية العامة.
        );

    // التباين العالي (UX-2a): نصوص قصوى على أسطح صافية وحدود مؤكدة —
    // بلا تغيير للألوان الدلالية (FinColors تبقى موفّرة ≥4.5:1 أصلاً).
    if (highContrast) {
      final ink = brightness == Brightness.light
          ? const Color(0xFF000000)
          : const Color(0xFFFFFFFF);
      final pureSurface = brightness == Brightness.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF000000);
      scheme = scheme.copyWith(
        surface: pureSurface,
        surfaceContainerLowest: pureSurface,
        surfaceContainerLow: pureSurface,
        surfaceContainer: pureSurface,
        surfaceContainerHigh: pureSurface,
        surfaceContainerHighest: pureSurface,
        surfaceDim: pureSurface,
        surfaceBright: pureSurface,
        onSurface: ink,
        onSurfaceVariant: ink,
        outline: ink,
        outlineVariant: ink,
      );
    }

    final isDark = brightness == Brightness.dark;
    final text = FinText.build(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: highContrast
          ? (isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF))
          : isDark
          ? const Color(0xFF0A1310)
          : const Color(0xFFF4F8F6),
      fontFamily: FinText.fontFamily,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,

      // شريط التطبيق: شفاف فوق السقالة (الرؤوس مخصصة داخل الشاشات).
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // بطاقات 16dp (§0.3) بظل ناعم متعدد الطبقات — وفي التباين العالي
      // حدّ مؤكد (حبر خالص) بدل الحد الملطّف.
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: highContrast
                ? scheme.outlineVariant
                : isDark
                ? FinColors.dark.cardBorder
                : FinColors.light.cardBorder,
            width: highContrast ? 1.6 : 1,
          ),
        ),
      ),

      // أزرار 12dp بأهداف لمس ≥ 48dp (DS-29).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outlineVariant, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(48, 48),
          iconSize: 24,
        ),
      ),

      // حقول الإدخال: تعبئة ناعمة وحواف 12dp — والتباين العالي أسطح
      // صافية بحدّ مؤكد وتركيز أثخن.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: highContrast
            ? scheme.surface
            : isDark
            ? const Color(0xFF142220)
            : const Color(0xFFEFF5F2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(
              alpha: highContrast ? 1 : 0.6,
            ),
            width: highContrast ? 1.6 : 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(
              alpha: highContrast ? 1 : 0.6,
            ),
            width: highContrast ? 1.6 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: seed, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),

      // شرائح الحالة (StatusChip — DS-26): دائماً بنص لا لون فقط.
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? const Color(0xFF1D2C27)
            : const Color(0xFFE9F0EC),
        selectedColor: scheme.primaryContainer,
        labelStyle: text.labelMedium,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF1D2C27)
            : const Color(0xFF172521),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? FinColors.dark.divider : FinColors.light.divider,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}
