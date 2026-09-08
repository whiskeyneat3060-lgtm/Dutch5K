/// Date helpers. All dates are **local** `YYYY-MM-DD` strings, matching the web
/// app so that stored values are byte-identical and lexicographic comparison
/// works (BUILD-SPEC 7.6).
library;

String dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String todayStr([DateTime? now]) => dateStr(now ?? DateTime.now());

/// Parses a `YYYY-MM-DD` string at local midnight.
DateTime parseDay(String s) {
  final List<String> p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Adds [n] days to a `YYYY-MM-DD` string, handling month, year and DST
/// rollover the way `Date.setDate` does.
String addDays(String dateString, int n) {
  final DateTime d = parseDay(dateString);
  return dateStr(DateTime(d.year, d.month, d.day + n));
}

/// Whole days between two `YYYY-MM-DD` strings, rounded — mirrors the web app's
/// `Math.round((Date(b) - Date(a)) / 86400000)`, which is DST-tolerant.
int daysBetween(String a, String b) {
  final Duration diff = parseDay(b).difference(parseDay(a));
  return (diff.inMilliseconds / 86400000).round();
}
