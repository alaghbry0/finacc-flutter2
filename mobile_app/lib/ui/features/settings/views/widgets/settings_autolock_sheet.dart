/// لوحة اختيار مدة القفل التلقائي وصفها — مستخرجة من settings_screen
/// (R19-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/session/app_controller.dart';

/// صف مدة القفل التلقائي — قابل للنقر يفتح لوحة الخيارات.
///
/// يقرأ القيمة من AppController مباشرة (مراقبة حية) — التغيير من
/// اللوحة ينعكس فوراً دون إعادة تحميل الشاشة كاملة.
class SettingsAutolockRow extends StatelessWidget {
  const SettingsAutolockRow({super.key});

  @override
  Widget build(BuildContext context) {
    final minutes = context.watch<AppController>().autolockMinutes;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _openAutolockSheet(context),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.settingsAutolock,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ),
                Text(
                  l10n.settingsAutolackValue(minutes),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAutolockSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      // لوحة كاملة العرض بحواف علوية مستديرة ومقبض.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SettingsAutolockSheet(
        current: context.read<AppController>().autolockMinutes,
      ),
    );
  }
}

/// لوحة اختيار مدة القفل التلقائي (FR-12-05 — 1–60 دقيقة).
class SettingsAutolockSheet extends StatelessWidget {
  const SettingsAutolockSheet({super.key, required this.current});

  final int current;

  /// الخيارات المعروضة (خيارات مشتركة ضمن النطاق الملزم 1–60).
  static const options = [1, 5, 10, 15, 30, 60];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        // تمرير آمن للشاشات القصيرة (لا تجاوز أبداً).
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // مقبض اللوحة.
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary,
                          Color.lerp(scheme.primary, Colors.black, 0.25)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.timer_outlined,
                      color: scheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsAutolockSheetTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          l10n.settingsAutolockSheetSubtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final option in options)
                SettingsAutolockOption(
                  minutes: option,
                  selected: option == current,
                  onTap: () {
                    unawaited(
                      context.read<AppController>().setAutolockMinutes(option),
                    );
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// خيار مدة واحد داخل اللوحة — علامة تحديد متحركة عند الاختيار.
class SettingsAutolockOption extends StatelessWidget {
  const SettingsAutolockOption({
    super.key,
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.settingsAutolackValue(minutes),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: selected ? scheme.onPrimaryContainer : null,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: selected ? 1 : 0,
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
