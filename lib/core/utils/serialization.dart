/// Consistent DateTime <-> wire conversion for all shared models.
///
/// Models store dates as ISO-8601 UTC strings in their maps so serialization
/// stays Firestore-agnostic and fully testable without Firebase. A Firestore
/// converter can adapt these strings to `Timestamp` at the data-source layer.
library;

String? dateToWire(DateTime? value) => value?.toUtc().toIso8601String();

DateTime? dateFromWire(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw)?.toUtc();
  // Support epoch millis (some sources encode dates as ints).
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  return null;
}

/// Required-date variant that throws nothing but defaults to epoch when absent —
/// callers should validate presence separately where the field is mandatory.
DateTime dateFromWireOr(Object? raw, DateTime fallback) =>
    dateFromWire(raw) ?? fallback;
