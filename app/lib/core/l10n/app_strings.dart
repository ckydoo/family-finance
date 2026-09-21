import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

import '../models/models.dart';
import '../state/app_state.dart';

/// Lightweight demo localization for EN / SN / ND (spec J6).
///
/// This is a deliberate stop-gap: Phase 2 migrates to the official
/// `flutter gen-l10n` toolchain with `.arb` files under `lib/l10n/`
/// (see app README). The maps below are initial drafts — have native
/// Shona / Ndebele speakers review before public launch.
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
  'sn': {
    'family': 'Mhuri',
    'hi': 'Mhoro',
    'mySavings': 'Mari dzangu',
    'addToJar': 'Wekira mari',
    'savingsMatch': 'Kufanana chengeto',
    'savingsMatchNote': 'Vabereki vanoisa 50% paunochengeta',
    'earnings': 'Mibairo',
    'logEarning': 'Nyora mubairo',
    'myProposals': 'Zvandatumira',
    'proposeExpense': 'Tumira mari yainobuda',
    'proposeTitle': 'Kumbira mari yainobuda',
    'peek': 'Vabereki vakakubvumira kuona iyi',
    'plan': 'Hurongwa: shandisa · chengeta · pa',
    'reportTitle': 'Bhuku rimwe',
    'income': 'Mari yapisika',
    'spent': 'Mari yashandiswa',
    'saved': 'Mari yachengetwa',
    'safePerDay': 'Zvakanaka pazuva',
    'envelopeHealth': 'Utano hwebajeti',
    'cashLeak': 'Mari yeresandla',
    'shareReport': 'Govera nemhuri',
    'language': 'Mutauro',
  },
  'nd': {
    'family': 'Umndeni',
    'hi': 'Sawubona',
    'mySavings': 'imali yami',
    'addToJar': 'Faka kumali',
    'savingsMatch': 'Ukufanisa okugciniwe',
    'savingsMatchNote': 'Abazali bafaka i-50% yokhu ozigciniyela',
    'earnings': 'imvuzo',
    'logEarning': 'Bhala imvuzo',
    'myProposals': 'iziphakamiso zami',
    'proposeExpense': 'Phakamisa isondlo',
    'proposeTitle': 'Cela imali esondweni',
    'peek': 'Abazali bakuvumele ukhu ubone lokhu',
    'plan': 'Uhlelo: sebenzisa · gcina · nikela',
    'reportTitle': 'Ikadi lembiko',
    'income': 'imali engenayo',
    'spent': 'okuchithiwe',
    'saved': 'okugciniwe',
    'safePerDay': 'okuphephile / usuku',
    'envelopeHealth': 'impilo yebhajethi',
    'cashLeak': 'imali yesandla',
    'shareReport': 'Yabelana nomndeni',
    'language': 'Ulimi',
  },
};

const kLanguageNames = {
  'en': 'English',
  'sn': 'chiShona',
  'nd': 'isiNdebele',
  'es': 'Español',
  'fr': 'Français',
  'pt': 'Português',
};

/// `tStr(context, 'income')` — M6: routes through the generated
/// AppLocalizations (6 languages). The legacy `kStrings` maps remain as the
/// EN/SN/ND draft source and fall back for any key not yet in the ARBs.
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
    } ?? _legacy(key, AppScope.of(context).localeCode);
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
      Role.adult => l.roleAdult,
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
