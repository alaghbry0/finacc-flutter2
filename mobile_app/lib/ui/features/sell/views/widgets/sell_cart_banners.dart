/// لافتات الكاشير فوق قائمة السلة: رفض الترحيل، تحذير البيع تحت
/// التكلفة (UX-2a)، وحالة السلة الفارغة.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/sell_cart_view_model.dart';

/// لافتة رفض الترحيل — رسالة عربية واضحة والسلة محفوظة.
class SellPostErrorBanner extends StatelessWidget {
  const SellPostErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = FinColors.of(context);
    return FinCard(
      padding: const EdgeInsets.all(14),
      accent: colors.negative,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.negative, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: AppLocalizations.of(context)!.commonDone,
              onPressed: () =>
                  context.read<SellCartViewModel>().clearPostError(),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// لافتة تحذير البيع تحت التكلفة (UX-2a —
/// `invoicing.discount_below_margin` = on): صافي السطر بعد كل الخصومات
/// أدنى من تكلفته — تحذير ذهبي للمستخدم لا منع للترحيل.
class SellBelowCostBanner extends StatelessWidget {
  const SellBelowCostBanner({super.key, required this.lineNames});

  final List<String> lineNames;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = FinColors.of(context);
    final names = lineNames.take(3).join(' · ');
    return FinCard(
      padding: const EdgeInsets.all(14),
      accent: colors.warning,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.trending_down_rounded, color: colors.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.settings2BelowCostWarning(names),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// حالة السلة الفارغة — CTA واحد كبير لإضافة أول صنف.
class SellEmptyCart extends StatelessWidget {
  const SellEmptyCart({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: l10n.sellEmptyCartTitle,
        message: l10n.sellEmptyCartBody,
        actionLabel: l10n.sellAddItem,
        onAction: onAdd,
      ),
    );
  }
}
