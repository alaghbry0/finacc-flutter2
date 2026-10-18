/// تاريخ قياسي (ميلادي) بأرقام السياق — «YYYY/MM/dd HH:mm».
library;

import 'package:intl/intl.dart';

import '../../../../../domain/services/numerals.dart';

String itemDetailFormatDate(DateTime date, bool arabicIndic) {
  final formatted = DateFormat('yyyy/MM/dd HH:mm').format(date);
  return arabicIndic ? Numerals.toArabicIndic(formatted) : formatted;
}
