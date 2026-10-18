/// بطاقة «حول» — مستخرجة من settings_screen
/// (R19-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/app_version.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/numerals_scope.dart';
import '../../../../../domain/services/numerals.dart';
import '../../view_models/settings_view_model.dart';
import 'settings_action_row.dart';

/// بطاقة «حول»: الاسم والإصدار (من المصدر الوحيد `appVersion` — UX-2a
/// توحيد الإصدار: بلا تضارب بين نص القالب والإصدار الفعلي) ووثيقة
/// المتطلبات وحجم القاعدة.
class SettingsAboutCard extends StatelessWidget {
  const SettingsAboutCard({super.key, required this.state});

  /// بيانات الإعدادات (لحجم القاعدة — FR-13-07).
  final SettingsData state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return FinCard(
      child: Column(
        children: [
          // شارة الطور: وسط البطاقة — النص مرن (RTL عربي + لاتيني «v1.0.0»
          // يفيض 1.5px على 390dp بالسطر الصلب — ellipsis عند الضيق).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_rounded, color: colors.gold, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.settings2AboutPhase,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${l10n.appBrand} — ${l10n.appTitle}',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.settings2AboutVersion(appVersion),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.settingsAboutSrs,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          // حجم القاعدة (FR-13-07) — من ملف finacc.db على المنصات الأصلية.
          if (state.dbSizeBytes != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.settingsAboutDbSize(
                _formatDbSize(context, state.dbSizeBytes!),
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 14),
          Divider(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.4),
          ),
          const SizedBox(height: 10),
          // صف التراخيص المفتوحة — صفحة تراخيص Flutter الرسمية.
          SettingsActionRow(
            icon: Icons.description_rounded,
            iconColor: colors.gold,
            title: l10n.settingsLicenses,
            subtitle: l10n.settingsLicensesDesc,
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: '${l10n.appBrand} — ${l10n.appTitle}',
              applicationVersion: appVersion,
              applicationIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: colors.gold,
                  size: 40,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// حجم القاعدة مقروءاً (ك.ب/م.ب) بأرقام النظام الحي — لبند «حول».
String _formatDbSize(BuildContext context, int bytes) {
  final l10n = AppLocalizations.of(context)!;
  final arabicIndic = NumeralsScope.of(context);
  String digits(String text) =>
      arabicIndic ? Numerals.toArabicIndic(text) : text;
  final kb = bytes / 1024;
  if (kb < 1024) {
    return l10n.backupSizeKb(digits(kb.round().toString()));
  }
  return l10n.backupSizeMb(digits((kb / 1024).toStringAsFixed(1)));
}
