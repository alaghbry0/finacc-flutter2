/// عناصر النقدية المشتركة (الشريحة 6) — مستخدمة عبر شاشات الوحدة:
/// بلاطة وصول سريع، بطاقة صندوق برصيد حي، صف حركة موقّع ملون،
/// منتقي صندوق، حقل مبلغ، بطاقة خطأ، وبوابة سعر الصرف (FR-08-09 —
/// مرآة بوابة المشتريات لكن فوق عقد حفظ عام لا فوق عربة شراء).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../domain/models/cash.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/fin_card.dart';

/// ─────────────────────────────────────────────────────────────────────
/// دلالات الأنواع (ملحق و — إشارات الأرصدة الحرفية)
/// ─────────────────────────────────────────────────────────────────────

/// هل الحركة واردة (+) على صندوق المصدر `cashbox_id`؟
/// (receipt/capital_in/opening فقط — كل ذات الساقين صادرة من مصدرها
/// والهدف يستقبل ساقه المحوّلة باسمه.)
bool cashTxInflowOnMainBox(CashTxType? type) =>
    type == CashTxType.receipt ||
    type == CashTxType.capitalIn ||
    type == CashTxType.opening;

/// أيقونة تمثيلية لنوع الحركة.
IconData cashTxIcon(CashTxType? type) => switch (type) {
  CashTxType.receipt => Icons.south_west_rounded,
  CashTxType.payment => Icons.north_east_rounded,
  CashTxType.expense => Icons.receipt_long_rounded,
  CashTxType.ownerDraw => Icons.person_remove_rounded,
  CashTxType.capitalIn => Icons.person_add_rounded,
  CashTxType.boxTransfer => Icons.swap_horiz_rounded,
  CashTxType.bankDeposit => Icons.account_balance_rounded,
  CashTxType.bankWithdraw => Icons.local_atm_rounded,
  CashTxType.opening => Icons.flag_rounded,
  null => Icons.help_outline_rounded,
};

/// تسمية النوع بالعربية (مفاتيح cashType*).
String cashTxLabel(AppLocalizations l10n, CashTxType? type) => switch (type) {
  CashTxType.receipt => l10n.cashTypeReceipt,
  CashTxType.payment => l10n.cashTypePayment,
  CashTxType.expense => l10n.cashTypeExpense,
  CashTxType.ownerDraw => l10n.cashTypeOwnerDraw,
  CashTxType.capitalIn => l10n.cashTypeCapitalIn,
  CashTxType.boxTransfer => l10n.cashTypeBoxTransfer,
  CashTxType.bankDeposit => l10n.cashTypeBankDeposit,
  CashTxType.bankWithdraw => l10n.cashTypeBankWithdraw,
  CashTxType.opening => l10n.cashTypeOpening,
  null => '—',
};

/// لون دلالي لنوع الحركة (للأفاتار والبلاطات).
Color cashTxTone(ColorScheme scheme, FinColors colors, CashTxType? type) {
  if (cashTxInflowOnMainBox(type)) return colors.positive;
  return switch (type) {
    CashTxType.payment => colors.negative,
    CashTxType.expense => colors.warning,
    CashTxType.ownerDraw => scheme.tertiary,
    _ => colors.negative,
  };
}

/// تاريخ `يوم/شهر/سنة` بأرقام بسيطة (نمط باقي الوحدات).
String cashFormatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

/// تاريخ `سنة-شهر-يوم` (صيغة القاعدة).
String cashFormatIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// ─────────────────────────────────────────────────────────────────────
/// عناصر العرض
/// ─────────────────────────────────────────────────────────────────────

/// مقبض سحب نوافذ BottomSheet — القالب الموحد.
class CashSheetDragHandle extends StatelessWidget {
  const CashSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: scheme.outlineVariant,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

/// بلاطة وصول سريع (شبكة محور النقدية) — أيقونة ملونة + تسمية قصيرة.
class CashQuickTile extends StatelessWidget {
  const CashQuickTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FinColors.of(context).cardBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 21, color: color),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w800, fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة صندوق واحدة (المحور + إدارة الصناديق): الاسم/العملة/الرصيد
/// الحي — **سالب = أحمر مع أيقونة تحذير** (FR-04-06/09) — ودلاء العملات
/// الأخرى إن وصلت للصندوق من حركات مخالفة العملة (فصل العملات 5.4-7).
class CashBoxCard extends StatelessWidget {
  const CashBoxCard({
    super.key,
    required this.box,
    required this.onTap,
    this.trailing,
    this.subtitle,
  });

  final CashboxWithBalance box;

  final VoidCallback onTap;

  /// عنصر ذيل (رقاقة افتراضي/أزرار إدارة).
  final Widget? trailing;

  /// سطر إضافي تحت الرصيد (استخدام إدارة الصناديق).
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final negative = box.isNegative;
    final sign = negative ? FinSign.outgoing : FinSign.neutral;
    return FinCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (negative ? colors.negative : scheme.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 22,
                  color: negative ? colors.negative : scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      box.box.name,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      box.box.currencyCode,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.gold,
                        fontWeight: FontWeight.w800,
                        fontFeatures: FinText.tabularNums,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      AmountText(
                        amount: box.nativeBalance,
                        size: AmountSize.row,
                        decimals: 2,
                        sign: sign,
                      ),
                    ],
                  ),
                  if (negative) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 13,
                          color: colors.negative,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.cashNegativeBalance,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.negative,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ] else
                    ?subtitle,
                ],
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          // دلاء عملات أخرى داخل الصندوق — سطر لكل عملة بعملتها.
          for (final bucket in box.foreignBuckets)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 54),
              child: Row(
                children: [
                  Icon(
                    Icons.currency_exchange_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      bucket.currencyCode,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(fontFeatures: FinText.tabularNums),
                    ),
                  ),
                  AmountText(
                    amount: bucket.amount,
                    decimals: 2,
                    sign: bucket.amount < 0
                        ? FinSign.outgoing
                        : FinSign.neutral,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// صف حركة صندوق (المحتوى بلا إطار — يُستخدم داخل بطاقة أو قائمة):
/// أيقونة نوع ملونة + تسمية/رقم السند + التاريخ والصندوقين + مبلغ موقّع
/// ملون (وارد أخضر/صادر أحمر — §6.1) + رقائق الملغاة/الإبطال.
class CashMovementTile extends StatelessWidget {
  const CashMovementTile({
    super.key,
    required this.movement,
    this.dimmed = false,
  });

  final CashMovementRow movement;

  /// تخفيت بصري (حركة ملغاة).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final type = movement.type;
    final inflow = cashTxInflowOnMainBox(type);
    final tone = cashTxTone(scheme, colors, type);
    final sign = inflow ? FinSign.incoming : FinSign.outgoing;

    final title = cashTxLabel(l10n, type);
    final subtitle = StringBuffer(cashFormatDate(movement.txDate))
      ..write(' · ')
      ..write(movement.cashboxName);
    if (movement.toCashboxName != null) {
      subtitle
        ..write(' · ')
        ..write(l10n.cashMovementFieldTo)
        ..write(' ')
        ..write(movement.toCashboxName);
    }
    final context2 =
        movement.customerName ??
        movement.supplierName ??
        movement.expenseCategoryName ??
        movement.description;

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(cashTxIcon(type), size: 20, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (movement.voucherNo != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        movement.voucherNo!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontFeatures: FinText.tabularNums,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (movement.isVoided) ...[
                      const SizedBox(width: 6),
                      StatusChipLite(
                        label: l10n.cashMovementsVoidedChip,
                        color: colors.negative,
                      ),
                    ] else if (movement.isReversal) ...[
                      const SizedBox(width: 6),
                      StatusChipLite(
                        label: l10n.cashMovementsReversalChip,
                        color: colors.neutral,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle.toString(),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontFeatures: FinText.tabularNums),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (context2 != null && context2.trim().isNotEmpty)
                  Text(
                    context2,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  AmountText(
                    amount: movement.amount,
                    size: AmountSize.row,
                    decimals: 2,
                    sign: sign,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    movement.currencyCode,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: inflow ? colors.positive : colors.negative,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// رقاقة حالة مصغّرة (ملغاة/إبطال) — أخف من StatusChip لصفوف القوائم.
class StatusChipLite extends StatelessWidget {
  const StatusChipLite({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────
/// عناصر النماذج
/// ─────────────────────────────────────────────────────────────────────

/// حقل مبلغ موحد (لوحة أرقام عشرية + منع الصفر/السالب عند التحويل).
class CashAmountField extends StatelessWidget {
  const CashAmountField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.suffixCode,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? suffixCode;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,6}')),
      ],
      onChanged: onChanged,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        suffixText: suffixCode,
        prefixIcon: const Icon(Icons.payments_rounded),
      ),
    );
  }

  /// يحل نص الحقل رقماً (يقبل الفاصلة العشرية «,») — null عند اللاغي.
  static double? parse(String raw) {
    final trimmed = raw.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return null;
    final value = double.tryParse(trimmed);
    if (value == null || value.isNaN || value.isInfinite) return null;
    return value;
  }
}

/// منتقي صندوق (Dropdown) — يعرض الاسم والعملة والرصيد الحي في البند.
class CashBoxPickerField extends StatelessWidget {
  const CashBoxPickerField({
    super.key,
    required this.boxes,
    required this.selectedId,
    required this.label,
    required this.onChanged,
    this.enabled = true,
    this.icon = Icons.account_balance_wallet_rounded,
  });

  final List<CashboxWithBalance> boxes;
  final int? selectedId;
  final String label;
  final ValueChanged<int?> onChanged;
  final bool enabled;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    return DropdownButtonFormField<int>(
      initialValue: selectedId,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: [
        for (final b in boxes)
          DropdownMenuItem<int>(
            value: b.box.id,
            child: Text(
              '${b.box.name} · ${b.box.currencyCode} · '
              '${b.nativeBalance < 0 ? '−' : ''}${AmountText.format(b.nativeBalance.abs(), 2)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: b.isNegative ? colors.negative : null,
                fontFeatures: FinText.tabularNums,
              ),
            ),
          ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────
/// بوابة سعر الصرف (FR-08-09) — مرآة بوابة البيع/الشراء فوق عقد عام
/// ─────────────────────────────────────────────────────────────────────

/// يفتح بوابة إدخال سعر اليوم — يعيد `true` إذا حُفظ السعر بنجاح.
Future<bool> showCashFxGateSheet(
  BuildContext context, {
  required String currencyCode,
  required Future<bool> Function(double rate) onSave,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // فوق شريط التبويبات (متصفح الفرع) — لا من أسفل الشاشة خلفه.
    useRootNavigator: false,
    builder: (_) =>
        _CashFxGateSheet(currencyCode: currencyCode, onSave: onSave),
  );
  return saved ?? false;
}

class _CashFxGateSheet extends StatefulWidget {
  const _CashFxGateSheet({required this.currencyCode, required this.onSave});

  final String currencyCode;
  final Future<bool> Function(double rate) onSave;

  @override
  State<_CashFxGateSheet> createState() => _CashFxGateSheetState();
}

class _CashFxGateSheetState extends State<_CashFxGateSheet> {
  final TextEditingController _rateController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final rate = CashAmountField.parse(_rateController.text);
    if (rate == null || rate <= 0) {
      setState(() => _error = l10n.fxRateInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.onSave(rate);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = l10n.genericErrorTitle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CashSheetDragHandle(),
            const SizedBox(height: 16),
            FinCard(
              accent: colors.warning,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.currency_exchange_rounded,
                        color: colors.warning,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.sellFxGateTitle(widget.currencyCode),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.sellFxGateBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rateController,
              autofocus: true,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,6}')),
              ],
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: l10n.sellFxGateFieldLabel,
                suffixText: widget.currencyCode,
                errorText: _error,
                helperText: l10n.sellFxGateFieldHelper,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(l10n.sellFxGateSave),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
  }
}
