/// الخط الزمني: رؤوس أيام + أحداث بخط عمودي واصل.
library;

import 'package:flutter/material.dart';

import '../../../../../domain/models/audit_event.dart';
import '../../../../core/widgets/numerals_scope.dart';
import 'audit_day_header.dart';
import 'audit_timeline_event.dart';

class AuditTimeline extends StatelessWidget {
  const AuditTimeline({super.key, required this.events});

  final List<AuditEvent> events;

  @override
  Widget build(BuildContext context) {
    final arabicIndic = NumeralsScope.of(context);
    // تجميع باليوم المحلي مع الحفاظ على الترتيب.
    final groups = <String, List<AuditEvent>>{};
    for (final e in events) {
      groups.putIfAbsent(_dayKey(e.atLocal), () => []).add(e);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          AuditDayHeader(
            dayKey: entry.key,
            arabicIndic: arabicIndic,
            count: entry.value.length,
          ),
          for (final event in entry.value)
            AuditTimelineEvent(event: event, arabicIndic: arabicIndic),
        ],
      ],
    );
  }

  static String _dayKey(DateTime local) =>
      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
