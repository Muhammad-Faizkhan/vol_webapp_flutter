// Display helpers, ported from packages/api-client/src/format.ts.

const _units = [(60.0, 's'), (60.0, 'min'), (24.0, 'h'), (7.0, 'd'), (4.35, 'w'), (12.0, 'mo')];

/// "12min ago", "3d ago", "just now".
String timeAgo(DateTime? date) {
  if (date == null) return 'never';
  var value = DateTime.now().difference(date).inMilliseconds / 1000;
  if (value < 45) return 'just now';
  for (final (size, unit) in _units) {
    if (value < size) return '${value.floor()}$unit ago';
    value /= size;
  }
  return '${value.floor()}y ago';
}

/// 1431 -> "1,431".
String formatNumber(num n) {
  final digits = n.round().abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// 2400 -> "2.4k".
String compactNumber(num n) {
  String trim(String s) => s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  if (n < 1000) return '$n';
  if (n < 1000000) return '${trim((n / 1000).toStringAsFixed(n < 10000 ? 1 : 0))}k';
  return '${trim((n / 1000000).toStringAsFixed(1))}M';
}

String formatDate(DateTime? date) => date == null ? '—' : date.toUtc().toIso8601String().substring(0, 10);

/// "John Smith" -> "JS".
String initials(String name) => name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

/// "COLLABORATOR" -> "Collaborator".
String titleCase(String s) => s.isEmpty ? s : s[0] + s.substring(1).toLowerCase().replaceAll('_', ' ');

/// "ABC123" -> "ABC-123" (classroom join codes).
String formatJoinCode(String code) => code.length == 6 ? '${code.substring(0, 3)}-${code.substring(3)}' : code;

String? formatMinutes(int? minutes) {
  if (minutes == null || minutes == 0) return null;
  if (minutes < 60) return '$minutes mins';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m > 0 ? '${h}h ${m}m' : '${h}h';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Oct 24, 2026", matching toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" }).
String shortDate(DateTime d) {
  final l = d.toLocal();
  return '${_months[l.month - 1]} ${l.day}, ${l.year}';
}

/// "October 2026".
String monthYear(DateTime d) {
  const full = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final l = d.toLocal();
  return '${full[l.month - 1]} ${l.year}';
}

/// "1 canvas" / "3 canvases".
String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

String greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
}

/// "UPDATED 3H AGO" for anything touched in the last day.
String? updatedTag(DateTime date) =>
    DateTime.now().difference(date) < const Duration(days: 1) ? 'UPDATED ${timeAgo(date).toUpperCase()}' : null;
