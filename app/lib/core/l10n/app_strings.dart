import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

import '../models/models.dart';
import '../state/app_state.dart';

/// Lightweight localization fallback for English (`en`), with full translations
/// across the four supported app locales (`en`, `es`, `fr`, `pt`) generated
/// from `lib/l10n/app_*.arb` via `flutter gen-l10n`.
const Map<String, Map<String, String>> kStrings = {
  'en': {
    'family': 'Family',
    'hi': 'Hi',
    'mySavings': 'My savings',
    'addToJar': 'Add to jar',
    'savingsMatch': 'Savings match',
    'savingsMatchNote': 'Parents match 50% of everything you save',
    'earnings': 'Earnings',
    'logEarning': 'Log earning',
    'myProposals': 'My proposals',
    'proposeExpense': 'Propose expense',
    'proposeTitle': 'Propose an expense',
    'peek': 'Parents let you see this envelope',
    'plan': 'Spend · Save · Give plan',
    'reportTitle': 'Report card',
    'income': 'Income',
    'spent': 'Spent',
    'saved': 'Saved',
    'safePerDay': 'Safe / day',
    'envelopeHealth': 'Envelope health',
    'cashLeak': 'Cash leak',
    'shareReport': 'Share to family group',
    'language': 'Language',
  },
};

const kLanguageNames = {
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'pt': 'Português',
};

/// Normalizes any persisted or server locale code to a currently supported
/// language code, falling back cleanly to English (`'en'`).
String normalizeSupportedLocale(String? code) =>
    (code != null && kLanguageNames.containsKey(code)) ? code : 'en';

/// `tStr(context, 'income')` - routes through the generated
/// [AppLocalizations] (4 languages: en, es, fr, pt), with `kStrings['en']`
/// fallback when outside a localized widget subtree.
String tStr(BuildContext context, String key) {
  final l = AppLocalizations.of(context);
  if (l != null) {
    return switch (key) {
          'family' => l.family,
          'hi' => l.hi,
          'mySavings' => l.mySavings,
          'addToJar' => l.addToJar,
          'savingsMatch' => l.savingsMatch,
          'savingsMatchNote' => l.savingsMatchNote,
          'earnings' => l.earnings,
          'logEarning' => l.logEarning,
          'myProposals' => l.myProposals,
          'proposeExpense' => l.proposeExpense,
          'proposeTitle' => l.proposeTitle,
          'peek' => l.peek,
          'plan' => l.plan,
          'reportTitle' => l.reportTitle,
          'income' => l.income,
          'spent' => l.spent,
          'saved' => l.saved,
          'safePerDay' => l.safePerDay,
          'envelopeHealth' => l.envelopeHealth,
          'cashLeak' => l.cashLeak,
          'shareReport' => l.shareReport,
          'language' => l.language,
          _ => null,
        } ??
        _legacy(key, AppScope.of(context).localeCode);
  }
  return _legacy(key, AppScope.of(context).localeCode);
}

String _legacy(String key, String code) =>
    kStrings[code]?[key] ?? kStrings['en']![key] ?? key;

/// ── Enum label lookups (l10n completion pass) ──────────────────────────────
String methodLabel(AppLocalizations l, Method m) => switch (m) {
      Method.cash => l.methodCash,
      Method.mobileMoney => l.methodMobile,
      Method.bankCard => l.methodCard,
      Method.bankTransfer => l.methodTransfer,
      Method.agent => l.methodAgent,
      Method.other => l.methodOther,
    };

String roleLabel(AppLocalizations l, Role r) => switch (r) {
      Role.owner => l.roleOwner,
      Role.admin => l.roleParent,
      Role.adult => l.roleAdult,
      Role.contributor => 'Contributor',
      Role.teen => l.roleTeen,
      Role.kid => l.roleKid,
      Role.viewer => l.roleViewer,
    };

String itemStateLabel(AppLocalizations l, ItemState st) => switch (st) {
      ItemState.tobuy => l.stateToBuy,
      ItemState.incart => l.stateInCart,
      ItemState.done => l.stateDone,
    };

String freqLabel(AppLocalizations l, Frequency f) => switch (f) {
      Frequency.weekly => l.freqWeekly,
      Frequency.monthly => l.freqMonthly,
      Frequency.term => l.freqTerm,
    };

String rolloverLabel(AppLocalizations l, Rollover r) => switch (r) {
      Rollover.reset => l.rollReset,
      Rollover.roll => l.rollRoll,
      Rollover.accumulate => l.rollAccum,
    };
