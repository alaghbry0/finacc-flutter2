/// قسم العميل بنمط SIM (V4) — أكورديون أبيض (أيقونة شخص + اسم العميل +
/// رمز العملة + شيفرون) يتوسع لأزرار الاختيار: عميل/نقدي + صف عملات
/// الفاتورة. يحل محل شريط الأهداف المسطح القديم مع حفاظ حرفي على
/// الأفعال الثلاثة (اختيار عميل، عميل نقدي، تغيير عملة) — §6.5.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../view_models/sell_cart_view_model.dart';
import 'sell_widgets.dart';
import 'sim_invoice_widgets.dart';

class SellClientSection extends StatelessWidget {
  const SellClientSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.onPickCustomer,
    required this.onPickCash,
    required this.onPickCurrency,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onPickCustomer;
  final VoidCallback onPickCash;
  final ValueChanged<int> onPickCurrency;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellCartViewModel>();
    final state = vm.state;
    final l10n = AppLocalizations.of(context)!;
    final currency = state.selectedCurrency;

    final customerLabel = state.customer?.name ?? l10n.sellCashCustomer;
    return Column(
      children: [
        SimAccordionHeader(
          icon: Icons.person_outline_rounded,
          title: customerLabel,
          expanded: expanded,
          onToggle: onToggle,
          trailingAmount: currency?.code,
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 240),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPickCustomer,
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: Text(l10n.sellPickCustomer),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPickCash,
                        icon: const Icon(Icons.person_off_outlined, size: 18),
                        label: Text(l10n.sellCashCustomer),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CurrencyPickerRow(
                  currencies: [
                    for (final c in state.currencies)
                      CurrencyOption(
                        id: c.id,
                        code: c.code,
                        isBase: c.isBase,
                        rateKnown: c.isBase || c.id == state.currencyId
                            ? state.rateKnown
                            : true,
                      ),
                  ],
                  selectedId: state.currencyId,
                  todayRate: state.todayRate,
                  onSelect: onPickCurrency,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
