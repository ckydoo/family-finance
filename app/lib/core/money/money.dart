import 'package:intl/intl.dart';

/// Currency support per spec §5: every amount is stored as an integer number
/// of minor units (cents / ziG cents) plus its currency. Never a float.
enum Currency { usd, zwg }

extension CurrencyX on Currency {
  String get long =>
      this == Currency.usd ? 'US Dollar (USD)' : 'Zimbabwe Gold (ZiG)';
  String get short => this == Currency.usd ? 'USD' : 'ZiG';
  String get symbol => this == Currency.usd ? 'US\$' : 'ZiG';
  Currency get other => this == Currency.usd ? Currency.zwg : Currency.usd;
}

/// Immutable money value. All arithmetic stays in minor units; conversions
/// round half-up and the original recorded amount always remains authoritative
/// (no silent conversion — display conversion is always explicit).
class Money {
  final int minor;
  final Currency currency;

  /// G7: app locale for number grouping (set once per build from MaterialApp).
  /// Only locales intl formats well; null keeps the original en-US grouping
  /// (tests + default boot).
  static String? localeTag;
  static const _intlLocales = {'es', 'fr', 'pt'};

  const Money(this.minor, this.currency);

  factory Money.fromMajor(num major, Currency currency) =>
      Money((major * 100).round(), currency);

  double get major => minor / 100;
  bool get isZero => minor == 0;

  Money operator +(Money o) {
    assert(o.currency == currency, 'cannot add mixed currencies');
    return Money(minor + o.minor, currency);
  }

  Money operator -(Money o) {
    assert(o.currency == currency, 'cannot subtract mixed currencies');
    return Money(minor - o.minor, currency);
  }

  Money times(int factor) => Money(minor * factor, currency);

  /// Display conversion using the day's rate (central-bank mid or the user's market rate).
  Money converted(double rate) => currency == Currency.usd
      ? Money((minor * rate).round(), Currency.zwg)
      : Money((minor / rate).round(), Currency.usd);

  Money inCurrency(Currency c, double rate) =>
      c == currency ? this : converted(rate);

  /// "US$ 1,240.50" / "ZiG 18,940" — ZiG hides whole cents per spec §5.2.
  /// G7: in es/fr/pt locales grouping/decimal separators follow the locale
  /// (1.234,56); en (and untranslated locales) keep the original format.
  String get text {
    final neg = minor < 0;
    final abs = minor.abs();
    final units = abs ~/ 100;
    final cents = abs % 100;
    final sign = neg ? '-' : '';
    final tag = localeTag;
    if (tag != null && _intlLocales.contains(tag)) {
      final dec = currency == Currency.usd || cents > 0 ? 2 : 0;
      final f = NumberFormat.decimalPatternDigits(decimalDigits: dec, locale: tag);
      return '$sign${currency.symbol} ${f.format(abs / 100)}';
    }
    final g = _group(units);
    if (currency == Currency.usd) {
      return '$sign${currency.symbol} $g.${cents.toString().padLeft(2, '0')}';
    }
    return cents == 0
        ? '$sign${currency.symbol} $g'
        : '$sign${currency.symbol} $g.${cents.toString().padLeft(2, '0')}';
  }

  static String _group(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      b.write(s[i]);
      final rem = s.length - 1 - i;
      if (rem > 0 && rem % 3 == 0) b.write(',');
    }
    return b.toString();
  }
}
