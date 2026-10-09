/// شاشة العرض والمظهر (UX-2a) — مسار `/more/appearance`: توسعة قسم
/// المظهر القائم إلى شاشة كاملة: وضع الثيم (3) + نظام الأرقام (2 بمعاينة
/// حيّة) + **حجم الخط 3 مستويات** (`display.font_scale` — يطبَّق فوراً عبر
/// textScaler بالجذر) + **التباين العالي** (`ui.high_contrast` — كان
/// getter بلا استهلاك؛ الآن ثيم أسطح صافية ونصوص قصوى).
///
/// كل القيم حيّة من AppController (مراقبة فورية بلا إعادة تحميل) —
/// نفس نمط قسم المظهر القديم المدمج هنا.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fin_tokens.dart';
import '../../../core/widgets/fin_card.dart';
import '../../../../domain/services/numerals.dart';
import '../../../core/widgets/numerals_scope.dart';

/// شاشة العرض والمظهر — مسار `/more/appearance`.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.settings2AppearanceTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [
          _ThemeSection(),
          SizedBox(height: 16),
          _NumeralsSection(),
          SizedBox(height: 16),
          _FontScaleSection(),
          SizedBox(height: 16),
          _HighContrastSection(),
        ],
      ),
    );
  }
}

/// وضع الثيم (نظام/فاتح/داكن) — من AppController حياً.
class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final app = context.watch<AppController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(icon: Icons.palette_rounded, title: l10n.settingsTheme),
        const SizedBox(height: 8),
        FinCard(
          child: Column(
            children: [
              for (final (mode, icon, label) in [
                ('system', Icons.brightness_auto_rounded, l10n.themeSystem),
                ('light', Icons.light_mode_rounded, l10n.themeLight),
                ('dark', Icons.dark_mode_rounded, l10n.themeDark),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: _OptionRow(
                    icon: icon,
                    label: label,
                    selected: app.themeMode == mode,
                    onTap: () => app.setThemeMode(mode),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 4),
          child: Text(
            l10n.settingsThemeNote,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// نظام الأرقام — بطاقتان بمعاينة حيّة.
class _NumeralsSection extends StatelessWidget {
  const _NumeralsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final app = context.watch<AppController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(icon: Icons.pin_rounded, title: l10n.settingsNumerals),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SampleOption(
                title: l10n.numeralsWestern,
                sample: '1,234.50',
                selected: app.numerals == 'western',
                onTap: () => app.setNumerals('western'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SampleOption(
                title: l10n.numeralsArabicIndic,
                sample: '١٬٢٣٤٫٥٠',
                selected: app.numerals == 'arabic_indic',
                onTap: () => app.setNumerals('arabic_indic'),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 4),
          child: Text(
            l10n.settingsNumeralsNote,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// حجم الخط — 3 مستويات (`display.font_scale` — UX-2a) بمعاينة نصية
/// بالحجم الفعلي لكل مستوى (نص عيّنة يتوسع بحجمه المستهدف).
class _FontScaleSection extends StatelessWidget {
  const _FontScaleSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final app = context.watch<AppController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          icon: Icons.format_size_rounded,
          title: l10n.settings2FontScale,
        ),
        const SizedBox(height: 8),
        FinCard(
          child: Column(
            children: [
              for (final (mode, label) in [
                ('normal', l10n.settings2FontScaleNormal),
                ('large', l10n.settings2FontScaleLarge),
                ('xlarge', l10n.settings2FontScaleXlarge),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: _OptionRow(
                    icon: Icons.text_fields_rounded,
                    label: label,
                    // معاينة حيّة بالحجم الفعلي لكل مستوى.
                    sample: l10n.settings2FontScaleSample,
                    sampleScale: switch (mode) {
                      'large' => 1.15,
                      'xlarge' => 1.3,
                      _ => 1.0,
                    },
                    selected: app.fontScale == mode,
                    onTap: () => app.setFontScale(mode),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 4),
          child: Text(
            l10n.settings2FontScaleDesc,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// التباين العالي (`ui.high_contrast` — UX-2a وصله بالثيم).
class _HighContrastSection extends StatelessWidget {
  const _HighContrastSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final app = context.watch<AppController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          icon: Icons.contrast_rounded,
          title: l10n.settings2HighContrast,
        ),
        const SizedBox(height: 8),
        FinCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(FinRadius.control),
                ),
                child: Icon(
                  Icons.accessibility_new_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settings2HighContrast,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.settings2HighContrastDesc,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch(value: app.highContrast, onChanged: app.setHighContrast),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 4),
          child: Text(
            l10n.settings2HighContrastNote,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: colors.warning, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// رأس قسم مصغّر (نمط أقسام مركز الإعدادات).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(FinRadius.chip),
          ),
          child: Icon(icon, size: 16, color: scheme.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
        ),
      ],
    );
  }
}

/// صف خيار قابل للاختيار (ثيم/حجم خط) بعلامة تحديد متحركة.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.sample,
    this.sampleScale = 1.0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? sample;
  final double sampleScale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? scheme.onPrimaryContainer : null,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
            ),
            if (sample != null) ...[
              const SizedBox(width: 8),
              TextScalerDependentSample(
                text: sample!,
                scale: sampleScale,
                selected: selected,
              ),
              const SizedBox(width: 8),
            ],
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: selected ? 1 : 0,
              child: Icon(
                Icons.check_circle_rounded,
                color: scheme.primary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// معاينة نصية بحجم المستوى الفعلي — مقيّدة بأسلوب الشاشة (لا ترث تكبير
/// الجذر حتى تُظهر فرق المستويات كما سيراه المستخدم).
class TextScalerDependentSample extends StatelessWidget {
  const TextScalerDependentSample({
    super.key,
    required this.text,
    required this.scale,
    required this.selected,
  });

  final String text;
  final double scale;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final arabicIndic = NumeralsScope.of(context);
    final shown = arabicIndic ? Numerals.toArabicIndic(text) : text;
    return Text(
      shown,
      textScaler: TextScaler.linear(scale),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// بطاقة خيار بمعاينة مبلغ (نظام الأرقام).
class _SampleOption extends StatelessWidget {
  const _SampleOption({
    required this.title,
    required this.sample,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String sample;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? scheme.onPrimaryContainer : null,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 5),
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  scale: selected ? 1 : 0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: scheme.primary,
                    size: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                sample,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
