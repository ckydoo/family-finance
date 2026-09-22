import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/core/money/money.dart';

void main() {
  group('Money formatting (spec §5.2)', () {
    test('USD always shows cents', () {
      expect(Money.fromMajor(1240.5, Currency.usd).text, 'US\$ 1,240.50');
    });

    test('ZiG hides whole cents', () {
      expect(Money.fromMajor(18940, Currency.zwg).text, 'ZiG 18,940');
      expect(Money.fromMajor(18940.25, Currency.zwg).text, 'ZiG 18,940.25');
    });

    test('negative amounts', () {
      expect(const Money(-4200, Currency.usd).text, '-US\$ 42.00');
    });
  });

  group('Conversion (default rate 15.27)', () {
    const rate = 15.27;

    test('USD → ZiG', () {
      expect(
        Money.fromMajor(100, Currency.usd).converted(rate).text,
        'ZiG 1,527',
      );
    });

    test('ZiG → USD', () {
      expect(
        Money.fromMajor(1527, Currency.zwg).converted(rate).text,
        'US\$ 100.00',
      );
    });

    test('no silent conversion — original stays authoritative', () {
      final m = Money.fromMajor(50, Currency.usd);
      m.converted(rate); // returns a new value; must not mutate
      expect(m.currency, Currency.usd);
      expect(m.minor, 5000);
    });
  });

  test('times() multiplies in minor units', () {
    expect(Money.fromMajor(9.5, Currency.usd).times(2).text, 'US\$ 19.00');
  });
}
