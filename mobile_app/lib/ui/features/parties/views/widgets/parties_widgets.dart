/// مكونات مشتركة لواجهات الأطراف — عناوين الأقسام، صورة الطرف، رقاقة
/// حد الائتمان بدلالاته الثلاث، نص الرصيد الملوّن بعلامته غير اللونية
/// («مستحق»/«دائن»)، وشارح التاريخ، وأيقونات قيود الكشف.
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/party.dart';
import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/fin_tokens.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/numerals_scope.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/party_kind.dart';

/// عنوان قسم داخل شاشات الأطراف — أيقونة داخل حاوية مصبوغة + نص عريض.
class PartiesSectionTitle extends StatelessWidget {
  const PartiesSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

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
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// صورة الطرف — أيقونة النوع داخل دائرة مصبوغة (أو الحرف الأول للاسم).
class PartyAvatar extends StatelessWidget {
  const PartyAvatar({super.key, required this.kind, this.name, this.size = 42});

  final PartyKind kind;

  /// الاسم — إن أُعطي يُعرض أول حرفه بدل الأيقونة.
  final String? name;

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = kind == PartyKind.customer ? scheme.primary : scheme.tertiary;
    final initial = (name ?? '').trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Center(
        child: initial.isEmpty
            ? Icon(
                kind == PartyKind.customer
                    ? Icons.person_rounded
                    : Icons.local_shipping_rounded,
                size: size * 0.5,
                color: color,
              )
            : Text(
                initial.characters.first,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }
}

/// رقم الهاتف/الواتساب — LTR بأرقام جدولية أحادية.
class PartyPhoneText extends StatelessWidget {
  const PartyPhoneText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        text,
        style: (style ?? Theme.of(context).textTheme.bodySmall)?.copyWith(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// رقاقة حد الائتمان بدلالاته الثلاث الصارمة (FR-03-01):
/// `null` بلا حد (محايدة) · `0` منع الآجل (تحذيرية) · قيمة = الحد
/// (علامة تجارية مع المبلغ بأرقام جدولية).
class CreditLimitChip extends StatelessWidget {
  const CreditLimitChip({super.key, required this.creditLimit});

  /// null = بلا حد · 0 = منع الآجل · موجبة = الحد.
  final double? creditLimit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (creditLimit == null) {
      return StatusChip(
        label: l10n.partiesCreditUnlimited,
        tone: ChipTone.neutral,
        icon: Icons.all_inclusive_rounded,
        dense: true,
      );
    }
    if (creditLimit == 0) {
      return StatusChip(
        label: l10n.partiesCreditForbidden,
        tone: ChipTone.warning,
        icon: Icons.block_rounded,
        dense: true,
      );
    }
    return StatusChip(
      label: l10n.partiesCreditLimitValue(
        AmountText.formatFor(context, creditLimit!, 2),
      ),
      tone: ChipTone.brand,
      icon: Icons.speed_rounded,
      dense: true,
    );
  }
}

/// رصيد طرف بعملته — مبلغ ملوّن **مع علامة غير لونية إلزامية**
/// (شريحة «مستحق»/«دائن» — §6.1): موجب = مستحق (أحمر)، سالب = دائن
/// (أخضر)، صفر = محايد بلا شريحة.
class PartyBalanceText extends StatelessWidget {
  const PartyBalanceText({
    super.key,
    required this.balance,
    required this.decimals,
    this.showChip = true,
    this.size = AmountSize.row,
  });

  final double balance;
  final int decimals;

  /// إظهار شريحة «مستحق»/«دائن» — تُخفى في رؤوس المجموعات المكتظة.
  final bool showChip;

  final AmountSize size;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (balance == 0) {
      return AmountText(
        amount: 0,
        decimals: decimals,
        sign: FinSign.neutral,
        size: size,
        showSignMarker: false,
      );
    }
    final isDue = balance > 0;
    final color = isDue ? colors.negative : colors.positive;
    final style = switch (size) {
      AmountSize.display => FinText.amountDisplay(color),
      AmountSize.large => FinText.amountLarge(color),
      AmountSize.row => FinText.amountRow(color),
    };
    final marker = isDue ? '' : '−';
    final formatted = AmountText.formatFor(context, balance.abs(), decimals);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showChip) ...[
          StatusChip(
            label: isDue ? l10n.partiesBalanceOwed : l10n.partiesBalanceCredit,
            tone: isDue ? ChipTone.negative : ChipTone.positive,
            dense: true,
          ),
          const SizedBox(width: 8),
        ],
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text('$marker$formatted', style: style),
        ),
      ],
    );
  }
}

/// كبسولة رمز عملة — LTR بأرقام جدولية.
class CurrencyCodePill extends StatelessWidget {
  const CurrencyCodePill({super.key, required this.code, this.accent});

  final String code;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          code,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// شارة عدّاد — رقم بأرقام جدولية داخل كبسولة مصبوغة.
class PartiesCountBadge extends StatelessWidget {
  const PartiesCountBadge({
    super.key,
    required this.count,
    required this.color,
  });

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final arabicIndic = NumeralsScope.of(context);
    final text = arabicIndic ? Numerals.toArabicIndic('$count') : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// بطاقة ملاحظة معلوماتية خفيفة داخل شاشات الأطراف.
class PartiesInfoNote extends StatelessWidget {
  const PartiesInfoNote({
    super.key,
    required this.icon,
    required this.message,
    this.warning = false,
  });

  final IconData icon;
  final String message;

  /// نبرة تحذيرية بدل الذهبية.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: warning ? colors.warning : colors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// ملخص إجماليات بعملات متعددة — سلسلة كبسولات (رمز + مبلغ) LTR،
/// سطر لكل عملة **بلا أي جمع بينها** (FR-08-11).
class CurrencyTotalsRow extends StatelessWidget {
  const CurrencyTotalsRow({
    super.key,
    required this.totals,
    required this.decimalsOf,
    this.accent,
  });

  /// أزواج (رمز العملة، المبلغ) — كل واحد بعملته وحدها.
  final List<(String, double)> totals;

  /// منازل كل رمز (رمز → منازل).
  final int Function(String code) decimalsOf;

  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final color = accent ?? colors.gold;
    if (totals.isEmpty) {
      return Text(
        AppLocalizations.of(context)!.partiesDuesCount(0),
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (code, amount) in totals)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${AmountText.formatFor(context, amount, decimalsOf(code))} ',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    TextSpan(
                      text: code,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// ينسّق تاريخاً للعرض `يوم/شهر/سنة` بنظام أرقام السياق الحي.
String partyFormatDate(BuildContext context, DateTime? date) {
  if (date == null) return '';
  final plain = '${date.day}/${date.month}/${date.year}';
  return NumeralsScope.of(context) ? Numerals.toArabicIndic(plain) : plain;
}

/// أيقونة قيد كشف الحساب + لونها الدلالي (§6.1 — الوارد أخضر، الصادر
/// أحمر، الآجل/الافتتاحي ذهبي/محايد).
IconData statementEntryIcon(StatementEntryCode code) => switch (code) {
  StatementEntryCode.invoice => Icons.receipt_long_rounded,
  StatementEntryCode.receipt => Icons.payments_rounded,
  StatementEntryCode.saleReturn => Icons.undo_rounded,
  StatementEntryCode.purchase => Icons.shopping_cart_rounded,
  StatementEntryCode.payment => Icons.price_check_rounded,
  StatementEntryCode.purchaseReturn => Icons.assignment_return_rounded,
  StatementEntryCode.opening => Icons.flag_rounded,
  StatementEntryCode.carryIn => Icons.history_rounded,
};

/// تسمية نوع القيد المترجمة (كل النصوص عبر l10n).
String statementEntryLabel(AppLocalizations l10n, StatementEntryCode code) =>
    switch (code) {
      StatementEntryCode.invoice => l10n.statementKindInvoice,
      StatementEntryCode.receipt => l10n.statementKindReceipt,
      StatementEntryCode.saleReturn => l10n.statementKindSaleReturn,
      StatementEntryCode.purchase => l10n.statementKindPurchase,
      StatementEntryCode.payment => l10n.statementKindPayment,
      StatementEntryCode.purchaseReturn => l10n.statementKindPurchaseReturn,
      StatementEntryCode.opening => l10n.statementKindOpening,
      StatementEntryCode.carryIn => l10n.statementKindCarryIn,
    };
