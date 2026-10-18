/// بطاقة المنشأة وصف معلوماتها — مستخرجة من settings_screen
/// (R19-D3b: نقل حرفي بلا أي تغيير سلوكي).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/fin_tokens.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/settings_view_model.dart';
import 'settings_autolock_sheet.dart';

/// بطاقة المنشأة: الشعار (BLOB إن وُجد — UX-2a) + الاسم + العملة
/// الأساسية + المدير + مدة القفل التلقائي + بوابة التحرير الكامل.
class SettingsCompanyCard extends StatelessWidget {
  const SettingsCompanyCard({super.key, required this.state});

  final SettingsData state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final company = state.company;
    final logo = company?.logoPng;
    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (logo != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(FinRadius.control),
                  child: Image.memory(
                    logo,
                    width: 44,
                    height: 44,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary,
                        Color.lerp(scheme.primary, Colors.black, 0.25)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(FinRadius.control),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: scheme.onPrimary,
                    size: 22,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  company?.name ?? l10n.appTitle,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsInfoRow(
            icon: Icons.attach_money_rounded,
            label: l10n.settingsBaseCurrency,
            value: state.baseCurrency == null
                ? '—'
                : '${state.baseCurrency!.code} • ${state.baseCurrency!.name}',
          ),
          SettingsInfoRow(
            icon: Icons.badge_rounded,
            label: l10n.settingsAdmin,
            value: state.adminName ?? '—',
          ),
          // مدة القفل التلقائي — قابلة للضبط (FR-12-05: 1–60 دقيقة).
          const SettingsAutolockRow(),
        ],
      ),
    );
  }
}

class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
}
