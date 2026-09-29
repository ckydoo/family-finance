import 'package:intl/intl.dart';

/// Currency support per spec §5: every amount is stored as an integer number
/// of minor units (cents / subunits) plus its currency. Never a float.
enum Currency {
  usd,
  eur,
  gbp,
  zar,
  cad,
  aud,
  kes,
  ngn,
  inr,
  zwg,
}

extension CurrencyX on Currency {
  String get long => switch (this) {
        Currency.usd => 'US Dollar (USD)',
        Currency.eur => 'Euro (EUR)',
        Currency.gbp => 'British Pound (GBP)',
        Currency.zar => 'South African Rand (ZAR)',
        Currency.cad => 'Canadian Dollar (CAD)',
        Currency.aud => 'Australian Dollar (AUD)',
        Currency.kes => 'Kenyan Shilling (KES)',
        Currency.ngn => 'Nigerian Naira (NGN)',
        Currency.inr => 'Indian Rupee (INR)',
        Currency.zwg => 'Zimbabwe Gold (ZiG)',
      };

  String get short => switch (this) {
        Currency.usd => 'USD',
        Currency.eur => 'EUR',
        Currency.gbp => 'GBP',
        Currency.zar => 'ZAR',
        Currency.cad => 'CAD',
        Currency.aud => 'AUD',
        Currency.kes => 'KES',
        Currency.ngn => 'NGN',
        Currency.inr => 'INR',
        Currency.zwg => 'ZiG',
      };

  String get symbol => switch (this) {
        Currency.usd => 'US\$',
        Currency.eur => '€',
        Currency.gbp => '£',
        Currency.zar => 'R',
        Currency.cad => 'CA\$',
        Currency.aud => 'AU\$',
        Currency.kes => 'KSh',
        Currency.ngn => '₦',
        Currency.inr => '₹',
        Currency.zwg => 'ZiG',
      };

  String get code => switch (this) {
        Currency.usd => 'USD',
        Currency.eur => 'EUR',
        Currency.gbp => 'GBP',
        Currency.zar => 'ZAR',
        Currency.cad => 'CAD',
        Currency.aud => 'AUD',
        Currency.kes => 'KES',
        Currency.ngn => 'NGN',
        Currency.inr => 'INR',
        Currency.zwg => 'ZWG',
      };

  /// Market benchmark relative to 1 USD (1 USD = X Currency)
  double get benchmarkRateToUsd => switch (this) {
        Currency.usd => 1.0,
        Currency.eur => 0.92,
        Currency.gbp => 0.79,
        Currency.zar => 18.25,
        Currency.cad => 1.36,
        Currency.aud => 1.52,
        Currency.kes => 129.0,
        Currency.ngn => 1600.0,
        Currency.inr => 83.5,
        Currency.zwg => 26.54,
      };

  /// Default exchange rate from this currency to [target] (1 this = X target).
  double defaultRateTo(Currency target) {
    if (this == target) return 1.0;
    final r = target.benchmarkRateToUsd / benchmarkRateToUsd;
    if (r >= 10) return double.parse(r.toStringAsFixed(2));
    if (r >= 1) return double.parse(r.toStringAsFixed(3));
    return double.parse(r.toStringAsFixed(4));
  }

  Currency get other => this == Money.primaryCurrency
      ? (Money.secondaryCurrency ?? Money.primaryCurrency)
      : Money.primaryCurrency;
}

/// Immutable money value. All arithmetic stays in minor units; conversions
/// round half-up and the original recorded amount always remains authoritative
/// (no silent conversion - display conversion is always explicit).
class Money {
  final int minor;
  final Currency currency;

  static Currency primaryCurrency = Currency.usd;
  static Currency? secondaryCurrency = Currency.zwg;

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

  /// Display conversion using the conversion rate (base to quote rate).
  Money converted(double rate, [Currency? targetCurrency]) {
    final target = targetCurrency ??
        (currency == primaryCurrency
            ? (secondaryCurrency ?? primaryCurrency)
            : primaryCurrency);
    if (rate <= 0 || target == currency) return Money(minor, target);

    if (currency == primaryCurrency && target == secondaryCurrency) {
      return Money((minor * rate).round(), target);
    }
    if (currency == secondaryCurrency && target == primaryCurrency) {
      return Money((minor / rate).round(), target);
    }
    if (target == Currency.usd && currency == Currency.zwg) {
      return Money((minor / rate).round(), target);
    }
    if (target == Currency.zwg && currency == Currency.usd) {
      return Money((minor * rate).round(), target);
    }
    final bench = currency.defaultRateTo(target);
    return Money((minor * bench).round(), target);
  }

  Money inCurrency(Currency c, double rate) =>
      c == currency ? this : converted(rate, c);

  /// "US$ 1,240.50" / "€ 1,240.50" / "ZiG 18,940"
  /// G7: in es/fr/pt locales grouping/decimal separators follow the locale
  /// (1.234,56); en (and untranslated locales) keep the standard format.
  String get text {
    final neg = minor < 0;
    final abs = minor.abs();
    final units = abs ~/ 100;
    final cents = abs % 100;
    final sign = neg ? '-' : '';
    final tag = localeTag;
    if (tag != null && _intlLocales.contains(tag)) {
      final dec = currency != Currency.zwg || cents > 0 ? 2 : 0;
      final f =
          NumberFormat.decimalPatternDigits(decimalDigits: dec, locale: tag);
      return '$sign${currency.symbol} ${f.format(abs / 100)}';
    }
    final g = _group(units);
    if (currency == Currency.zwg && cents == 0) {
      return '$sign${currency.symbol} $g';
    }
    return '$sign${currency.symbol} $g.${cents.toString().padLeft(2, '0')}';
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
