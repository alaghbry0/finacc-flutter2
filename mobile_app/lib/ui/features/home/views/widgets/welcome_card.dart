/// بطاقة الترحيب — اسم المنشأة + التاريخ هجري/ميلادي (§6.5) بزخرفة
/// هندسية مالية خافتة وخط ذهبي فاصل وحلقة متدرجة حول أيقونة المتجر.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import 'date_detail_sheet.dart';

class WelcomeCard extends StatelessWidget {
  const WelcomeCard({
    super.key,
    required this.companyName,
    required this.hijriText,
    required this.gregorianText,
  });

  final String companyName;
  final String hijriText;
  final String gregorianText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? l10n.morningGreeting : l10n.eveningGreeting;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.32)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      foregroundDecoration: _PatternOverlay(color: colors.gold),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      companyName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // حلقة متدرجة حول أيقونة المتجر (لمسة فاخرة).
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.gold.withValues(alpha: 0.9),
                      scheme.onPrimary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(2.4),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(scheme.primary, Colors.black, 0.22),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: scheme.onPrimary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // خط ذهبي فاصل رفيع قبل شريط التاريخ.
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  colors.gold.withValues(alpha: 0.75),
                  colors.gold.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // شريط التاريخ — قابل للنقر يفتح لوحة تفاصيل التقويمين.
          Material(
            color: scheme.onPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => showHomeDateDetails(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: scheme.onPrimary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$hijriText  •  $gregorianText',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.expand_less_rounded,
                      size: 14,
                      color: scheme.onPrimary.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// زخرفة هندسية خافتة فوق البطاقة: دوائر عملة وخطوط دقيقة بزوايا
/// إسلامية هندسية — تُرسم مرة واحدة (CustomPainter) بشفافية منخفضة.
class _PatternOverlay extends Decoration {
  const _PatternOverlay({required this.color});

  final Color color;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _PatternPainter(color: color);
  }
}

class _PatternPainter extends BoxPainter {
  _PatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    canvas.save();
    try {
      // قصّ داخل البطاقة حتى لا تتجاوز الزخرفة حوافها المستديرة.
      canvas.clipRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.16);

      // دوائر متراكزة ركنية (يمين أعلى — اتجاه البداية في RTL).
      final c = Offset(rect.right - 26, rect.top + 30);
      for (final r in [46.0, 34.0, 22.0]) {
        canvas.drawCircle(c, r, paint);
      }
      // خطوط قطرية دقيقة أسفل يسار.
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.10);
      for (var i = 0; i < 4; i++) {
        final x = rect.left + 18.0 + i * 14;
        canvas.drawLine(
          Offset(x, rect.bottom),
          Offset(x + 26, rect.bottom - 26),
          p,
        );
      }
      // نقاط عملة صغيرة على قوس.
      final dots = Paint()..color = color.withValues(alpha: 0.22);
      for (var i = 0; i < 5; i++) {
        final angle = -1.2 + i * 0.3;
        canvas.drawCircle(
          Offset(c.dx + 58 * math.cos(angle), c.dy + 58 * math.sin(angle)),
          1.6,
          dots,
        );
      }
    } finally {
      canvas.restore();
    }
  }
}
