/// سطر عميل بتقرير أعمار الديون (R19-D3a — مستخرج حرفياً من
/// `aging_report_screen.dart` بلا أي تغيير دلالة؛ كان `_CustomerCard`
/// و`_CustomerAvatar` و`_BucketBar` و`_WhatsappButton`).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../data/repositories/debt_aging_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import 'aging_currency_pill.dart';
import 'aging_format.dart';
import 'aging_invoice_details.dart';

/// سطر عميل — الصورة الرمزية والاسم وعدد الفواتير وشريط الدلاء المصغّر
/// والإجمالي وزر واتساب؛ النقر يوسّع تفاصيل الفواتير المفتوحة.
class AgingCustomerCard extends StatelessWidget {
  const AgingCustomerCard({
    super.key,
    required this.row,
    required this.currencyCode,
    required this.decimals,
    required this.expanded,
    required this.onToggle,
    required this.onRemind,
  });

  final AgingCustomerRow row;
  final String currencyCode;
  final int decimals;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return FinCard(
      onTap: onToggle,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AgingCustomerAvatar(name: row.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.agingInvoicesCount(row.details.length),
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    AgingBucketBar(row: row),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(amount: row.total, decimals: decimals),
                  const SizedBox(height: 3),
                  AgingCurrencyPill(code: currencyCode, accent: colors.gold),
                ],
              ),
              const SizedBox(width: 6),
              AgingWhatsappButton(onTap: onRemind),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: AgingInvoiceDetails(
              details: row.details,
              decimals: decimals,
            ),
          ),
        ],
      ),
    );
  }
}

/// زر تذكير واتساب — دائرة خضراء بروح واتساب (رموز FinColors الإيجابية
/// تتطابق مع ألوانه في الوضعين).
class AgingWhatsappButton extends StatelessWidget {
  const AgingWhatsappButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Tooltip(
      message: l10n.agingRemindTooltip,
      child: Material(
        color: colors.positiveContainer,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              Icons.chat_rounded,
              size: 18,
              color: colors.onPositiveContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// الصورة الرمزية للعميل — دائرة بالاسمين الأولين.
class AgingCustomerAvatar extends StatelessWidget {
  const AgingCustomerAvatar({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .take(2)
        .map((word) => word.isEmpty ? '' : word.characters.first)
        .join();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// شريط الدلاء المصغّر — أربع مقاطع بعرضٍ متناسب مع كل دلو (٠–٣٠ يميناً
/// في RTL ثم أعمق فأعمق حتى +٩٠ أقصى اليسار).
class AgingBucketBar extends StatelessWidget {
  const AgingBucketBar({super.key, required this.row});

  final AgingCustomerRow row;

  @override
  Widget build(BuildContext context) {
    final total = row.total;
    if (total <= 0) return const SizedBox.shrink();
    final segments = <double>[
      row.bucket0to30,
      row.bucket31to60,
      row.bucket61to90,
      row.bucket90Plus,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          // stretch يمدّد المقاطع عديمة الطفل لكامل الارتفاع — وإلا
          // انهارت أبعادها إلى صفر فاختفى الشريط.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < segments.length; i++)
              if (segments[i] > 0)
                Expanded(
                  flex: math.max(1, (segments[i] / total * 1000).round()),
                  child: ColoredBox(
                    color: agingBucketColor(context, i).withValues(alpha: 0.85),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
