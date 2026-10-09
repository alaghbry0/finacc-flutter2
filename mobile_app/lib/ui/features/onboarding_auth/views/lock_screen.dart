/// شاشة القفل — PIN بسياسة FR-12-06 الكاملة + بوابة عبارة المرور + مسح
/// بتأكيد مزدوج (AC-15).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../domain/services/hijri_date.dart';
import '../../../../domain/services/numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/session/app_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/confirm_word_dialog.dart';
import '../../../core/widgets/numerals_scope.dart';
import '../../../core/widgets/pin_pad.dart';
import '../view_models/lock_view_model.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    return ChangeNotifierProvider(
      create: (_) => LockViewModel()..attach(app.users!),
      child: const _LockBody(),
    );
  }
}

class _LockBody extends StatefulWidget {
  const _LockBody();

  @override
  State<_LockBody> createState() => _LockBodyState();
}

class _LockBodyState extends State<_LockBody> {
  final _passphraseController = TextEditingController();

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LockViewModel>();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final companyName = context.read<AppController>().company?.name;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: vm.mode == LockUiMode.pin
              ? _pinMode(context, vm, l10n, companyName)
              : _passphraseMode(context, vm, l10n, companyName),
        ),
      ),
    );
  }

  Widget _pinMode(
    BuildContext context,
    LockViewModel vm,
    AppLocalizations l10n,
    String? companyName,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final gate = vm.gate;
    final messageText = _messageText(context, gate.messageCode, vm);
    return ListView(
      key: const ValueKey('lock-pin'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        const BrandMark(size: 72),
        const SizedBox(height: 18),
        // ساعة حية + اسم المنشأة — سياق «من يفتح ومتى» بلغة فاخرة.
        _LockClock(companyName: companyName),
        const SizedBox(height: 18),
        Text(
          l10n.lockTitle,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.lockSubtitle,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 26),
        PinDots(
          length: 6,
          filled: vm.pin.length,
          error: gate.messageCode == LockMessage.wrong,
          shakeKey: vm.shakeKey,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 22,
          child: vm.verifying
              ? Text(
                  l10n.lockVerifying,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                )
              : messageText == null
              ? null
              : Text(
                  messageText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: gate.messageCode == LockMessage.wrong
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
        ),
        const SizedBox(height: 14),
        PinPad(
          onDigit: (digit) {
            vm.addDigit(digit);
            // إرسال تلقائي عند بلوغ الحد الأقصى (6 خانات).
            if (vm.pin.length == 6) {
              unawaited(vm.submitPin(context.read<AppController>()));
            }
          },
          onBackspace: vm.backspace,
          enabled: gate.enabled,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: vm.pin.length >= 4 && gate.enabled && !vm.verifying
                ? () => vm.submitPin(context.read<AppController>())
                : null,
            icon: const Icon(Icons.lock_open_rounded, size: 20),
            label: Text(
              vm.verifying ? l10n.lockVerifying : l10n.lockUnlockButton,
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (gate.remainingDelay != Duration.zero)
          _CountdownBadge(remaining: gate.remainingDelay),
        const SizedBox(height: 10),
        TextButton(
          onPressed: vm.switchToPassphrase,
          child: Text(l10n.lockUsePassphrase),
        ),
      ],
    );
  }

  Widget _passphraseMode(
    BuildContext context,
    LockViewModel vm,
    AppLocalizations l10n,
    String? companyName,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final gate = vm.gate;
    return ListView(
      key: const ValueKey('lock-passphrase'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        const BrandMark(size: 72),
        const SizedBox(height: 22),
        Text(
          l10n.lockPassphraseTitle,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.lockPassphraseMessage,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 26),
        TextField(
          controller: _passphraseController,
          obscureText: true,
          onSubmitted: (value) =>
              vm.submitPassphrase(context.read<AppController>(), value),
          decoration: InputDecoration(
            labelText: l10n.lockPassphraseFieldLabel,
            prefixIcon: const Icon(Icons.key_rounded),
          ),
        ),
        const SizedBox(height: 12),
        if (gate.messageCode == LockMessage.passphraseFailed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l10n.lockPassphraseFailed,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: vm.verifying
                ? null
                : () => vm.submitPassphrase(
                    context.read<AppController>(),
                    _passphraseController.text,
                  ),
            icon: const Icon(Icons.lock_open_rounded, size: 20),
            label: Text(l10n.lockUnlockButton),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: vm.backToPin, child: Text(l10n.lockBackToPin)),
        if (vm.wipeOffered)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: OutlinedButton.icon(
              onPressed: () => _confirmWipe(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
              ),
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              label: Text(l10n.wipeDialogTitle),
            ),
          ),
      ],
    );
  }

  /// مسار المسح المحروس الموحد (AC-15 — P1-5): حوار ← كتابة الكلمة ←
  /// **نسخة أمان إجبارية قبل المسح** ← حوار نجاح يذكر ملف النسخة
  /// الأخيرة (نفس مسار الإعدادات — مساعد واحد للاثنين).
  Future<void> _confirmWipe(BuildContext context) async {
    await runGuardedWipeFlow(context, context.read<AppController>());
  }

  String? _messageText(
    BuildContext context,
    LockMessage? code,
    LockViewModel vm,
  ) {
    if (code == null) return null;
    final l10n = AppLocalizations.of(context)!;
    return switch (code) {
      LockMessage.wrong => l10n.lockAttemptsBeforeLock(
        vm.gate.attemptsLeftBeforeDelay,
      ),
      LockMessage.delayed => l10n.lockDelayedMessage(
        _formatDuration(vm.remaining),
      ),
      LockMessage.passphraseRequired => null,
      LockMessage.passphraseFailed => l10n.lockPassphraseFailed,
    };
  }

  static String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

/// شارة العدّاد التنازلي أثناء نافذة الانتظار.
class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_rounded, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              '$minutes:$seconds',
              style: FinText.withTabularDigits(
                Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ساعة حية أعلى شاشة القفل: الوقت الآن (يُحدَّث كل 20 ثانية) بأرقام
/// جدولية كبيرة + اسم المنشأة تحتها — تفتح الجلسة بسياق زمني ومؤسسي.
class _LockClock extends StatefulWidget {
  const _LockClock({this.companyName});

  final String? companyName;

  @override
  State<_LockClock> createState() => _LockClockState();
}

class _LockClockState extends State<_LockClock> {
  DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = FinColors.of(context);
    final time = DateFormat('HH:mm').format(_now);
    final hijri = HijriCalendar.fromDateTime(_now).toString();
    final arabicIndic = NumeralsScope.of(context);
    String num(String t) => arabicIndic ? Numerals.toArabicIndic(t) : t;
    return Center(
      child: Column(
        children: [
          Text(
            num(time),
            style: FinText.withTabularDigits(
              Theme.of(context).textTheme.displaySmall!.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: scheme.onSurface,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // شريط التاريخ الهجري — كبسولة ذهبية رفيعة تحت الساعة.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: colors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.gold.withValues(alpha: 0.3)),
            ),
            child: Text(
              num(hijri),
              style: FinText.withTabularDigits(
                Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: colors.gold,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          if (widget.companyName != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.companyName!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
