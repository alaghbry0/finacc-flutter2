/// بطاقة البيانات لتفاصيل الطرف — الاسم والهواتف والعنوان وحد الائتمان
/// والافتتاحي، وسطر المعلومة (أيقونة + تسمية + قيمة).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../view_models/party_detail_view_model.dart';
import '../../view_models/party_kind.dart';
import 'parties_widgets.dart';

/// بطاقة البيانات — الاسم والهواتف والعنوان وحد الائتمان والافتتاحي.
class PartyDetailInfoCard extends StatelessWidget {
  const PartyDetailInfoCard({super.key, required this.state});

  final PartyDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final record = state.record!;
    final isCustomer = state.kind == PartyKind.customer;

    return FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PartyAvatar(kind: state.kind, name: record.name, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (isCustomer)
                          CreditLimitChip(creditLimit: record.creditLimit),
                        if (record.archived)
                          StatusChip(
                            label: l10n.partiesArchivedBadge,
                            tone: ChipTone.neutral,
                            icon: Icons.archive_rounded,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PartyDetailInfoRow(
            icon: Icons.call_rounded,
            label: l10n.partyFormPhoneLabel,
            child: (record.phone ?? '').isNotEmpty
                ? PartyPhoneText(record.phone!)
                : Text(
                    l10n.partiesNoPhone,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
          ),
          if (isCustomer && (record.whatsapp ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            PartyDetailInfoRow(
              icon: Icons.chat_rounded,
              label: l10n.partyFormWhatsappLabel,
              child: PartyPhoneText(record.whatsapp!),
            ),
          ],
          if ((record.address ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            PartyDetailInfoRow(
              icon: Icons.location_on_rounded,
              label: l10n.partyFormAddressLabel,
              child: Expanded(
                child: Text(
                  record.address!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
          if (isCustomer && (record.area ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            PartyDetailInfoRow(
              icon: Icons.map_rounded,
              label: l10n.partyFormAreaLabel,
              child: Text(
                record.area!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          if (record.openingBalance != 0) ...[
            const SizedBox(height: 8),
            PartyDetailInfoRow(
              icon: Icons.savings_rounded,
              label: l10n.statementKindOpening,
              child: Expanded(
                child: Text(
                  l10n.partyDetailOpeningRow(
                    partyFormatDate(context, record.openingDate),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
          if ((record.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            PartyDetailInfoRow(
              icon: Icons.sticky_note_2_rounded,
              label: l10n.partyDetailNotesLabel,
              child: Expanded(
                child: Text(
                  record.notes!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// سطر معلومة — أيقونة + تسمية + قيمة.
class PartyDetailInfoRow extends StatelessWidget {
  const PartyDetailInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (child is Expanded) child else Expanded(child: child),
      ],
    );
  }
}
