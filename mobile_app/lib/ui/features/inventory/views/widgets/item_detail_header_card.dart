/// رأس البطاقة — الاسم والشارات والباركود وشرح تأجيل الطباعة.
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/fin_tokens.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/item_detail_view_model.dart';
import 'inventory_widgets.dart';

class ItemDetailHeaderCard extends StatelessWidget {
  const ItemDetailHeaderCard({super.key, required this.state});

  final ItemDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final item = state.detail!.item;
    return FinCard(
      accent: FinColors.of(context).gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
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
                  item.isService
                      ? Icons.miscellaneous_services_rounded
                      : Icons.inventory_2_rounded,
                  color: scheme.onPrimary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (item.isService)
                StatusChip(label: l10n.itemServiceBadge, tone: ChipTone.brand),
              if (item.trackBatches)
                StatusChip(
                  label: l10n.itemDetailBatchesBadge,
                  icon: Icons.layers_rounded,
                ),
              if (state.archived)
                StatusChip(
                  label: l10n.itemDetailArchivedBadge,
                  tone: ChipTone.negative,
                  icon: Icons.archive_rounded,
                ),
            ],
          ),
          if (item.barcode != null && item.barcode!.isNotEmpty) ...[
            const SizedBox(height: 14),
            BarcodePreview(
              code: item.barcode!,
              name: item.name,
              caption: l10n.itemDetailBarcodeNote,
            ),
          ],
        ],
      ),
    );
  }
}
