import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/generated/app_localizations.dart';

/// Flutter does not ship framework translations for Shona or Ndebele.
///
/// Mhuri Money still provides its own translated strings for those locales;
/// these delegates supply the English framework labels and formatting needed
/// by widgets such as [RefreshIndicator], date pickers and text fields.
const mhuriLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  _MaterialFallbackDelegate(),
  _CupertinoFallbackDelegate(),
  _WidgetsFallbackDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

bool _needsFrameworkFallback(Locale locale) =>
    locale.languageCode == 'sn' || locale.languageCode == 'nd';

class _MaterialFallbackDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialFallbackDelegate();

  @override
  bool isSupported(Locale locale) => _needsFrameworkFallback(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_MaterialFallbackDelegate old) => false;
}

class _CupertinoFallbackDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _CupertinoFallbackDelegate();

  @override
  bool isSupported(Locale locale) => _needsFrameworkFallback(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_CupertinoFallbackDelegate old) => false;
}

class _WidgetsFallbackDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _WidgetsFallbackDelegate();

  @override
  bool isSupported(Locale locale) => _needsFrameworkFallback(locale);

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(_WidgetsFallbackDelegate old) => false;
}
