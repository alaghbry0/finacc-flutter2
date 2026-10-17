/// لافتات فاتورة الشراء فوق قائمة البنود: رفض الترحيل وحالة الفاتورة
/// الفارغة.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/purchase_cart_view_model.dart';

/// لافتة رفض الترحيل — رسالة عربية واضحة والفاتورة محفوظة.
class PurchasePostErrorBanner extends StatelessWidget {
  const PurchasePostErrorBanner({super.key, required this.message});

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
                  context.read<PurchaseCartViewModel>().clearPostError(),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// حالة الفاتورة الفارغة — CTA واحد كبير لإضافة أول صنف.
class PurchaseEmptyCart extends StatelessWidget {
  const PurchaseEmptyCart({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: EmptyState(
        icon: Icons.add_shopping_cart_outlined,
        title: l10n.purEmptyCartTitle,
        message: l10n.purEmptyCartBody,
        actionLabel: l10n.purAddItem,
        onAction: onAdd,
      ),
    );
  }
}
