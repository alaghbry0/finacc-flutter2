/// طور البنود للمرتجع — رأس الفاتورة الأصلية + البنود القابلة للإرجاع
/// بكميات (سقف المتاح) (R19-D3c — مستخرج حرفياً من `returns_screen.dart`
/// بلا أي تغيير دلالة).
library;

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/fin_card.dart';
import '../../view_models/returns_view_model.dart';
import 'return_line_card.dart';
import 'return_refund_bottom_bar.dart';
import 'return_selected_invoice_header.dart';

/// طور البنود — رأس الفاتورة الأصلية + البنود القابلة للإرجاع بكميات
/// (سقف المتاح) + شريط سفلي بقيمة المرتجع وزر الترحيل.
class ReturnLinesSection extends StatelessWidget {
  const ReturnLinesSection({super.key, required this.vm, required this.isSale});

  final ReturnFlowVm vm;
  final bool isSale;

  @override
  Widget build(BuildContext context) {
    final state = vm.state;
    final l10n = AppLocalizations.of(context)!;
    final selected = state.selected;
    if (selected == null) return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              ReturnSelectedInvoiceHeader(
                invoice: selected,
                isSale: isSale,
                onChange: vm.backToInvoices,
              ),
              const SizedBox(height: 12),
              if (state.postError != null) ...[
                FinCard(
                  padding: const EdgeInsets.all(14),
                  accent: FinColors.of(context).negative,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: FinColors.of(context).negative,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.postError!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (state.linesLoading)
                const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
              else if (state.linesError != null)
                ErrorState(
                  title: l10n.genericErrorTitle,
                  message: l10n.dbOpenErrorMessage,
                  technicalDetails: state.linesError.toString(),
                  retryLabel: l10n.commonRetry,
                  onRetry: () => vm.selectInvoice(selected.id),
                  compact: true,
                )
              else if (state.lines.isEmpty)
                EmptyState(
                  icon: Icons.block_rounded,
                  title: l10n.retNoLinesTitle,
                  message: l10n.retNoLinesBody,
                  compact: true,
                )
              else ...[
                Text(
                  l10n.retLinesTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < state.lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ReturnLineCard(
                      line: state.lines[i],
                      onChanged: (qty) => vm.setQty(i, qty),
                    ),
                  ),
              ],
            ],
          ),
        ),
        ReturnRefundBottomBar(vm: vm, isSale: isSale),
      ],
    );
  }
}
