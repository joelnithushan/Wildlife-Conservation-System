import 'package:intl/intl.dart';

extension DateTimeFormatting on DateTime {
  String toDisplayDate() => DateFormat('dd MMM yyyy').format(this);
  String toDisplayDateTime() => DateFormat('dd MMM yyyy, HH:mm').format(this);
  String toIso8601Short() => DateFormat('yyyy-MM-dd').format(this);
}

extension NullableDateTimeFormatting on DateTime? {
  String toDisplayDateOrEmpty() =>
      this == null ? '—' : DateFormat('dd MMM yyyy').format(this!);
}
