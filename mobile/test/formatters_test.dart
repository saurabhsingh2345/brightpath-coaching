import 'package:flutter_test/flutter_test.dart';
import 'package:brightpath_coaching/core/formatters.dart';

void main() {
  group('money', () {
    test('uses Indian grouping and drops decimals when whole', () {
      expect(Fmt.money(1234567), '₹12,34,567');
      expect(Fmt.money(20000), '₹20,000');
      expect(Fmt.money(0), '₹0');
    });

    test('keeps paise when the amount is fractional', () {
      expect(Fmt.money(1500.5), contains('1,500.50'));
    });

    test('compact form switches unit at lakh and crore', () {
      expect(Fmt.moneyCompact(45000), '₹45.0K');
      expect(Fmt.moneyCompact(290000), '₹2.9L');
      expect(Fmt.moneyCompact(12500000), '₹1.3Cr');
      expect(Fmt.moneyCompact(-5000), '-₹5.0K');
    });
  });

  group('time', () {
    test('converts 24h to 12h with meridiem', () {
      expect(Fmt.time('07:00'), '7:00 AM');
      expect(Fmt.time('12:30'), '12:30 PM');
      expect(Fmt.time('00:15'), '12:15 AM');
      expect(Fmt.time('17:45'), '5:45 PM');
    });

    test('falls back rather than throwing on bad input', () {
      expect(Fmt.time(null), '—');
      expect(Fmt.time('nonsense'), '—');
    });

    test('countdown reads naturally at each scale', () {
      expect(Fmt.inMinutes(0), 'now');
      expect(Fmt.inMinutes(45), 'in 45 min');
      expect(Fmt.inMinutes(120), 'in 2h');
      expect(Fmt.inMinutes(135), 'in 2h 15m');
      expect(Fmt.inMinutes(2235), 'in 1d 13h');
    });
  });

  group('text helpers', () {
    test('initials take first and last name', () {
      expect(Fmt.initials('Aarav Sharma'), 'AS');
      expect(Fmt.initials('Priya'), 'P');
      expect(Fmt.initials('  '), '?');
      expect(Fmt.initials(null), '?');
    });

    test('titleCase normalises enum-style values', () {
      expect(Fmt.titleCase('MONDAY'), 'Monday');
      expect(Fmt.titleCase('BANK_TRANSFER'), 'Bank Transfer');
      expect(Fmt.titleCase(null), '—');
    });

    test('fileSize picks a sensible unit', () {
      expect(Fmt.fileSize(512), '512 B');
      expect(Fmt.fileSize(2048), '2 KB');
      expect(Fmt.fileSize(1572864), '1.5 MB');
    });
  });
}
