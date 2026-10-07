/// بوابة تباين WCAG — كل أزواج النص/الخلفية الدلالية ≥ 4.5:1 (DS-30).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/ui/core/theme/app_colors.dart';

/// نسبة التباين وفق معادلة WCAG 2.1.
double contrastRatio(Color a, Color b) {
  double luminance(Color c) {
    // القنوات r/g/b نسبيّة (0.0–1.0) في الواجهة الحديثة.
    double channel(double s) {
      return s <= 0.03928
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  final l1 = luminance(a);
  final l2 = luminance(b);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  void checkPairs(String mode, FinColors tokens, Color onSurfaceBg) {
    group('وضع $mode —', () {
      test('أزواج الأزرار الدلالية (positive/negative/warning)', () {
        expect(
          contrastRatio(tokens.onPositive, tokens.positive),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(tokens.onNegative, tokens.negative),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(tokens.onWarning, tokens.warning),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('أزواج الحاويات الدلالية', () {
        expect(
          contrastRatio(tokens.onPositiveContainer, tokens.positiveContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(tokens.onNegativeContainer, tokens.negativeContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(tokens.onWarningContainer, tokens.warningContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(tokens.onNeutralContainer, tokens.neutralContainer),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('النص الدلالي الملون فوق خلفية السطح قابل للقراءة', () {
        expect(
          contrastRatio(tokens.positive, onSurfaceBg),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(tokens.negative, onSurfaceBg),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(tokens.warning, onSurfaceBg),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(tokens.neutral, onSurfaceBg),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }

  // خلفية سطح البطاقة: أبيض للفاتح، ودرجة scaffoldAccent للداكن.
  checkPairs('فاتح', FinColors.light, Colors.white);
  checkPairs('داكن', FinColors.dark, const Color(0xFF0F211C));
}
