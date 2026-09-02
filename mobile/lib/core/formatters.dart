import 'package:intl/intl.dart';
import 'brand.dart';

final _date = DateFormat('d MMM yyyy');
final _dateShort = DateFormat('d MMM');
final _dateTime = DateFormat('d MMM yyyy, h:mm a');
final _dayName = DateFormat('EEEE');
final _iso = DateFormat('yyyy-MM-dd');

class Fmt {
  const Fmt._();

  static DateTime? parse(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  static String date(dynamic v, {String fallback = '—'}) {
    final d = parse(v);
    return d == null ? fallback : _date.format(d);
  }

  static String dateShort(dynamic v, {String fallback = '—'}) {
    final d = parse(v);
    return d == null ? fallback : _dateShort.format(d);
  }

  static String dateTime(dynamic v, {String fallback = '—'}) {
    final d = parse(v);
    return d == null ? fallback : _dateTime.format(d);
  }

  static String dayName(dynamic v) {
    final d = parse(v);
    return d == null ? '—' : _dayName.format(d);
  }

  static String iso(DateTime d) => _iso.format(d);

  /// 1234567 -> "₹12,34,567" (Indian grouping, no decimals when whole).
  static String money(num? v, {bool symbol = true}) {
    final value = v ?? 0;
    final f = NumberFormat.currency(
      locale: 'en_IN',
      symbol: symbol ? Brand.currencySymbol : '',
      decimalDigits: value == value.roundToDouble() ? 0 : 2,
    );
    return f.format(value).trim();
  }

  /// Compact money for tight stat cards: ₹1.2L, ₹45.0K.
  static String moneyCompact(num? v) {
    final value = (v ?? 0).toDouble();
    final sign = value < 0 ? '-' : '';
    final a = value.abs();
    if (a >= 10000000) {
      return '$sign${Brand.currencySymbol}${(a / 10000000).toStringAsFixed(1)}Cr';
    }
    if (a >= 100000) {
      return '$sign${Brand.currencySymbol}${(a / 100000).toStringAsFixed(1)}L';
    }
    if (a >= 1000) {
      return '$sign${Brand.currencySymbol}${(a / 1000).toStringAsFixed(1)}K';
    }
    return '$sign${Brand.currencySymbol}${a.toStringAsFixed(0)}';
  }

  static String percent(num? v) => '${(v ?? 0).toStringAsFixed(1)}%';

  /// "07:00" -> "7:00 AM"
  static String time(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return '—';
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? parts[1] : '00';
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $suffix';
  }

  static String timeRange(String? start, String? end) =>
      '${time(start)} – ${time(end)}';

  /// MONDAY -> Monday
  static String titleCase(String? s) {
    if (s == null || s.isEmpty) return '—';
    return s
        .split(RegExp(r'[_\s]+'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static String fileSize(int? bytes) {
    final b = bytes ?? 0;
    if (b >= 1048576) return '${(b / 1048576).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }

  /// "in 2 h 15 m" style countdown used for the next class.
  static String inMinutes(int? minutes) {
    final m = minutes ?? 0;
    if (m < 1) return 'now';
    if (m < 60) return 'in $m min';
    final days = m ~/ 1440;
    final hours = (m % 1440) ~/ 60;
    if (days > 0) return 'in ${days}d ${hours}h';
    final mins = m % 60;
    return mins == 0 ? 'in ${hours}h' : 'in ${hours}h ${mins}m';
  }
}
