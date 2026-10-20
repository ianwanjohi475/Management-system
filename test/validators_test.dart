import 'package:flutter_test/flutter_test.dart';
import 'package:shamba/core/utils/formatters.dart';
import 'package:shamba/core/utils/validators.dart';

void main() {
  test('email', () {
    expect(V.email('farmer@shamba.app'), isNull);
    expect(V.email('nope'), isNotNull);
    expect(V.email(''), 'Email is required');
  });

  test('phone accepts Kenyan formats', () {
    expect(V.phone('0712 345 678'), isNull);
    expect(V.phone('+254712345678'), isNull);
    expect(V.phone('12'), isNotNull);
    expect(V.phone('', optional: true), isNull);
  });

  test('numbers', () {
    expect(V.number('12'), isNull);
    expect(V.number('0'), isNotNull);
    expect(V.number('0', allowZero: true), isNull);
    expect(V.number('-3'), isNotNull);
    expect(V.number('2.5', integer: true), 'Use a whole number');
    expect(V.number('600', max: 450), isNotNull);
    expect(V.parse('1,500'), 1500);
  });

  test('password strength', () {
    expect(V.password('abc'), isNotNull);
    expect(V.password('abcdefg'), isNotNull);
    expect(V.password('kuku2026'), isNull);
  });

  test('formatters', () {
    Fmt.currency = 'KES';
    expect(Fmt.money(1500), 'KES 1,500');
    expect(Fmt.axis(65400), '65K');
    final now = DateTime(2026, 10, 20, 9);
    expect(Fmt.relativeDay(DateTime(2026, 10, 21), now: now), 'Tomorrow');
    expect(Fmt.relativeDay(DateTime(2026, 10, 17), now: now), '3 days ago');
    expect(Fmt.age(DateTime(2026, 9, 1), now: now), '7 wks');
  });
}
