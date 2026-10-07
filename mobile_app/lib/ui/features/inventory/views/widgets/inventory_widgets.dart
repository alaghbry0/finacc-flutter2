/// مكونات مشتركة لواجهات المخزن — معاينة الباركود (EAN-13/Code128/QR)،
/// عنوان القسم، شارة العدّاد، رقاقة أيام الصلاحية، والنص الأحادي LTR.
library;

import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../../../../domain/services/barcode_ean13.dart';
import '../../../../../domain/services/numerals.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/numerals_scope.dart';
import '../../../../core/widgets/status_chip.dart';

/// معاينة باركود صنف — EAN-13 صالح أو Code128 احتياطياً + رمز QR قابل
/// للتبديل (FR-01-02). خلفية بيضاء دائماً حتى يبقى قابلاً للمسح في
/// الوضعين الفاتح والداكن.
class BarcodePreview extends StatefulWidget {
  const BarcodePreview({
    super.key,
    required this.code,
    this.name,
    this.allowToggle = true,
    this.caption,
  });

  /// قيمة الباركود (فارغة = لا معاينة).
  final String code;

  /// اسم الصنف — يضمَّن في حمولة QR.
  final String? name;

  /// إظهار تبديل EAN/QR.
  final bool allowToggle;

  /// تعليق صغير تحت المعاينة (اختياري).
  final String? caption;

  @override
  State<BarcodePreview> createState() => _BarcodePreviewState();
}

class _BarcodePreviewState extends State<BarcodePreview> {
  bool _showQr = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final code = widget.code.trim();
    if (code.isEmpty) {
      return const SizedBox.shrink();
    }
    final isEan = Ean13Generator.isValidEan13(code);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.allowToggle)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PreviewToggle(
                  label: l10n.itemFormBarcodeEanToggle,
                  selected: !_showQr,
                  onTap: () => setState(() => _showQr = false),
                ),
                const SizedBox(width: 8),
                _PreviewToggle(
                  label: l10n.itemFormBarcodeQrToggle,
                  selected: _showQr,
                  onTap: () => setState(() => _showQr = true),
                ),
              ],
            ),
          ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: _showQr
                ? BarcodeWidget(
                    key: const Key('barcode_preview_qr'),
                    barcode: Barcode.qrCode(),
                    data: _qrPayload(code, widget.name),
                    width: 140,
                    height: 140,
                    drawText: false,
                    color: Colors.black,
                  )
                : BarcodeWidget(
                    key: Key('barcode_preview_${isEan ? 'ean13' : 'code128'}'),
                    barcode: isEan ? Barcode.ean13() : Barcode.code128(),
                    data: code,
                    width: 220,
                    height: 76,
                    drawText: false,
                    color: Colors.black,
                  ),
          ),
        ),
        const SizedBox(height: 6),
        // الأرقام تحت الرسم — أحادية LTR بأرقام جدولية (قابلة للقراءة
        // والنسخ وللاختبار).
        Center(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              code,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        if (!isEan && !_showQr)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Center(
              child: Text(
                l10n.itemFormCode128Caption,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        if (widget.caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Center(
              child: Text(
                widget.caption!,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  /// حمولة QR — بصمة FinAcc مع الباركود والاسم (مقصوصة إلى 200 حرفاً).
  static String _qrPayload(String code, String? name) {
    final payload = jsonEncode({
      't': 'finacc',
      'bc': code,
      if (name != null && name.trim().isNotEmpty) 'n': name.trim(),
    });
    return payload.length <= 200 ? payload : payload.substring(0, 200);
  }
}

/// رقاقة تبديل المعاينة (EAN / QR).
class _PreviewToggle extends StatelessWidget {
  const _PreviewToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// عنوان قسم داخل شاشات المخزن — أيقونة داخل حاوية مصبوغة + نص عريض.
class InventorySectionTitle extends StatelessWidget {
  const InventorySectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

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
            borderRadius: BorderRadius.circular(9),
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
      ],
    );
  }
}

/// شارة عدّاد — رقم بأرقام جدولية داخل كبسولة مصبوغة.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.color});

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

/// رقاقة أيام الصلاحية المتبقية — خضراء > 30، كهرمانية ≤ 30، حمراء منتهية.
class ExpiryDaysChip extends StatelessWidget {
  const ExpiryDaysChip({super.key, required this.days});

  /// الأيام حتى الانتهاء (سالب = منتهية).
  final int days;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (days < 0) {
      return StatusChip(
        label: l10n.batchExpired,
        tone: ChipTone.negative,
        icon: Icons.block_rounded,
        dense: true,
      );
    }
    // الدفعات الافتتاحية (صلاحية 9999-12-31): «بلا صلاحية» بدل رقم
    // أيام فلكي يتجاوز الرقاقة — عتبة 100 سنة تكفي دون المس بالدفعات
    // الحقيقية بعيدة المدى.
    if (days >= 36500) {
      return StatusChip(
        label: l10n.batchNoExpiry,
        tone: ChipTone.positive,
        icon: Icons.all_inclusive_rounded,
        dense: true,
      );
    }
    final tone = days <= 30 ? ChipTone.warning : ChipTone.positive;
    return StatusChip(
      label: l10n.batchDaysLeft(days),
      tone: tone,
      icon: days <= 30
          ? Icons.hourglass_bottom_rounded
          : Icons.event_available_rounded,
      dense: true,
    );
  }
}

/// نص أحادي (باركود/رقم دفعة) — LTR بخط أحادي وأرقام جدولية.
class MonoText extends StatelessWidget {
  const MonoText(this.text, {super.key, this.style});

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

/// بطاقة ملاحظة معلوماتية خفيفة (شرح/تأجيل) داخل شاشات المخزن.
class InfoNoteCard extends StatelessWidget {
  const InfoNoteCard({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    return FinCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.gold),
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
