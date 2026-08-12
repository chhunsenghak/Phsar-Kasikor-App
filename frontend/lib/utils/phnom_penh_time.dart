/// Backend timestamps come back as naive UTC with no offset marker (e.g.
/// "2026-08-10T10:54:48") — parsing that directly with `DateTime.parse`
/// makes Dart treat it as the *device's own local time* instead of UTC,
/// which silently corrupts every downstream conversion depending on
/// whatever timezone the device happens to be set to. This is the one
/// place that forces the correct interpretation (append 'Z' before
/// parsing), so every screen/service converts through here instead of
/// re-deriving — and risking re-breaking — the same logic.
library;

/// Parses a raw backend timestamp string as UTC, forcing a 'Z' suffix onto
/// any value that doesn't already carry an explicit UTC/offset marker.
/// Throws if [raw] isn't a parsable date at all.
DateTime parseBackendUtc(String raw) {
  String cleaned = raw.trim().replaceAll(' ', 'T');
  if (!cleaned.endsWith('Z') && !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(cleaned)) {
    cleaned += 'Z';
  }
  return DateTime.parse(cleaned);
}

/// Same as [parseBackendUtc], but returns null instead of throwing when
/// [raw] is null, empty, or unparsable.
DateTime? tryParseBackendUtc(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return parseBackendUtc(raw);
  } catch (_) {
    return null;
  }
}

/// Converts a raw backend UTC timestamp string to Phnom Penh wall-clock
/// time (ICT, a fixed UTC+7 — Cambodia does not observe DST).
DateTime? backendUtcToPhnomPenh(String? raw) {
  final parsed = tryParseBackendUtc(raw);
  if (parsed == null) return null;
  return parsed.toUtc().add(const Duration(hours: 7));
}

String _pad2(int n) => n.toString().padLeft(2, '0');

String _dateOnly(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-${_pad2(dt.month)}-${_pad2(dt.day)}';

String _timeOnly(DateTime dt) {
  int hour = dt.hour;
  final minute = _pad2(dt.minute);
  final ampm = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return '${_pad2(hour)}:$minute $ampm';
}

/// "05:07 PM" — time only, 12-hour clock, Phnom Penh time.
String formatPhnomPenhTime(String? raw) {
  final dt = backendUtcToPhnomPenh(raw);
  return dt == null ? '' : _timeOnly(dt);
}

/// "2026-08-10" — date only, Phnom Penh calendar day.
String formatPhnomPenhDate(String? raw) {
  final dt = backendUtcToPhnomPenh(raw);
  return dt == null ? '' : _dateOnly(dt);
}

/// Formats an already-Phnom-Penh-converted DateTime (e.g. from
/// [backendUtcToPhnomPenh]) as "2026-08-10" — for callers that already have
/// the DateTime and don't need to re-parse a raw string.
String formatDateOnly(DateTime phnomPenhDateTime) => _dateOnly(phnomPenhDateTime);

/// "2026-08-10 05:07 PM" — the full date+time convention already used
/// across the order/notification screens. Falls back to the raw string's
/// date-looking prefix (rather than blank) if it can't be parsed at all,
/// since that's still more useful than nothing.
String formatPhnomPenhDateTime(String? raw) {
  final dt = backendUtcToPhnomPenh(raw);
  if (dt != null) return '${_dateOnly(dt)} ${_timeOnly(dt)}';
  return raw?.split('T').first ?? '';
}

/// Same as [formatPhnomPenhDateTime], but formats an already-parsed local
/// [DateTime] (e.g. `DateTime.now()`) instead of a raw backend string —
/// for the "no timestamp available, show the current time instead" case.
/// `DateTime.now()` is correctly local-aware, so `.toUtc()` here is safe
/// (unlike calling it on a naive backend string, which is the bug this
/// file exists to avoid).
String formatPhnomPenhDateTimeFromLocal(DateTime localDateTime) {
  final dt = localDateTime.toUtc().add(const Duration(hours: 7));
  return '${_dateOnly(dt)} ${_timeOnly(dt)}';
}

/// Time-only if [raw] falls on today (Phnom Penh calendar day), otherwise
/// the full date — the chat inbox's "clock for today, date otherwise"
/// convention.
String formatPhnomPenhSmartDate(String? raw) {
  final dt = backendUtcToPhnomPenh(raw);
  if (dt == null) return '';
  final now = DateTime.now().toUtc().add(const Duration(hours: 7));
  final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
  return isToday ? _timeOnly(dt) : _dateOnly(dt);
}
