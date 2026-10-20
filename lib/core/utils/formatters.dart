import 'package:intl/intl.dart';

/// Formatting helpers. Currency code is set once from the farm profile.
abstract final class Fmt {
  static String currency = 'KES';

  static String money(num value, {bool compact = false}) {
    if (compact && value.abs() >= 10000) {
      return '$currency ${NumberFormat.compact().format(value)}';
    }
    final f = NumberFormat.currency(symbol: '$currency ', decimalDigits: value % 1 == 0 ? 0 : 2);
    return f.format(value);
  }

  static String number(num value, {int decimals = 0}) {
    final f = NumberFormat.decimalPatternDigits(decimalDigits: decimals);
    return f.format(value);
  }

  static String compact(num value) => NumberFormat.compact().format(value);

  /// Short whole-number axis label: 950, 12K, 1.2M.
  static String axis(num v) {
    final a = v.abs();
    if (a >= 1000000) return '${(v / 1000000).toStringAsFixed(a >= 10000000 ? 0 : 1)}M';
    if (a >= 1000) return '${(v / 1000).round()}K';
    return v.round().toString();
  }

  static String kg(num value) => '${number(value, decimals: value % 1 == 0 ? 0 : 1)} kg';

  static String percent(num value, {int decimals = 0}) => '${value.toStringAsFixed(decimals)}%';

  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d);
  static String dateShort(DateTime d) => DateFormat('d MMM').format(d);
  static String dayMonth(DateTime d) => DateFormat('EEE, d MMM').format(d);
  static String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);
  static String monthShort(DateTime d) => DateFormat('MMM').format(d);
  static String time(DateTime d) => DateFormat('h:mm a').format(d);
  static String dateTime(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);

  /// "Today", "Yesterday", "In 3 days", "5 days ago"…
  static String relativeDay(DateTime d, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final diff = dateOnly(d).difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1 && diff < 7) return 'In $diff days';
    if (diff < -1 && diff > -7) return '${-diff} days ago';
    return dateShort(d);
  }

  /// Animal age like "3 wks", "4 mo", "1 yr 2 mo".
  static String age(DateTime birth, {DateTime? now}) {
    final days = (now ?? DateTime.now()).difference(birth).inDays;
    if (days < 0) return '—';
    if (days < 14) return '$days ${days == 1 ? 'day' : 'days'}';
    if (days < 90) return '${days ~/ 7} wks';
    final months = days ~/ 30.44;
    if (months < 12) return '$months mo';
    final y = months ~/ 12, m = months % 12;
    return m == 0 ? '$y yr' : '$y yr $m mo';
  }

  static String greeting([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String plural(int n, String one, [String? many]) => '${number(n)} ${n == 1 ? one : (many ?? '${one}s')}';
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

extension DateX on DateTime {
  bool isSameDay(DateTime o) => year == o.year && month == o.month && day == o.day;
  bool get isToday => isSameDay(DateTime.now());
  DateTime get startOfMonth => DateTime(year, month);
}
