import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_nd.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_sn.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('nd'),
    Locale('pt'),
    Locale('sn')
  ];

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get tabBudgets;

  /// No description provided for @tabSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get tabSavings;

  /// No description provided for @tabLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get tabLists;

  /// No description provided for @tabFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get tabFamily;

  /// No description provided for @tabActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get tabActivity;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @familyPool.
  ///
  /// In en, this message translates to:
  /// **'Family Pool'**
  String get familyPool;

  /// No description provided for @safeToSpend.
  ///
  /// In en, this message translates to:
  /// **'Safe to spend today: {amount}'**
  String safeToSpend(String amount);

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @notThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Not this week'**
  String get notThisWeek;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @meeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meeting;

  /// No description provided for @newEnvelope.
  ///
  /// In en, this message translates to:
  /// **'New envelope'**
  String get newEnvelope;

  /// No description provided for @recurringExpenses.
  ///
  /// In en, this message translates to:
  /// **'Recurring expenses'**
  String get recurringExpenses;

  /// No description provided for @shopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shopping;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityTitle;

  /// No description provided for @noActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get noActivityTitle;

  /// No description provided for @noActivityHint.
  ///
  /// In en, this message translates to:
  /// **'Every expense, income and approval shows up here — add your first one with the + button.'**
  String get noActivityHint;

  /// No description provided for @noGoals.
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get noGoals;

  /// No description provided for @noGoalsHint.
  ///
  /// In en, this message translates to:
  /// **'Start with an emergency fund — even a little each week changes how emergencies feel.'**
  String get noGoalsHint;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report card'**
  String get reportTitle;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @spent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spent;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @safePerDay.
  ///
  /// In en, this message translates to:
  /// **'Safe / day'**
  String get safePerDay;

  /// No description provided for @envelopeHealth.
  ///
  /// In en, this message translates to:
  /// **'Envelope health'**
  String get envelopeHealth;

  /// No description provided for @cashLeak.
  ///
  /// In en, this message translates to:
  /// **'Cash leak'**
  String get cashLeak;

  /// No description provided for @shareReport.
  ///
  /// In en, this message translates to:
  /// **'Share to family group'**
  String get shareReport;

  /// No description provided for @meetingCta.
  ///
  /// In en, this message translates to:
  /// **'Start the family meeting'**
  String get meetingCta;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export transactions (CSV)'**
  String get exportCsv;

  /// No description provided for @family.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get family;

  /// No description provided for @hi.
  ///
  /// In en, this message translates to:
  /// **'Hi'**
  String get hi;

  /// No description provided for @mySavings.
  ///
  /// In en, this message translates to:
  /// **'My savings'**
  String get mySavings;

  /// No description provided for @addToJar.
  ///
  /// In en, this message translates to:
  /// **'Add to jar'**
  String get addToJar;

  /// No description provided for @savingsMatch.
  ///
  /// In en, this message translates to:
  /// **'Savings match'**
  String get savingsMatch;

  /// No description provided for @savingsMatchNote.
  ///
  /// In en, this message translates to:
  /// **'Parents match 50% of everything you save'**
  String get savingsMatchNote;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @logEarning.
  ///
  /// In en, this message translates to:
  /// **'Log earning'**
  String get logEarning;

  /// No description provided for @myProposals.
  ///
  /// In en, this message translates to:
  /// **'My proposals'**
  String get myProposals;

  /// No description provided for @proposeExpense.
  ///
  /// In en, this message translates to:
  /// **'Propose expense'**
  String get proposeExpense;

  /// No description provided for @proposeTitle.
  ///
  /// In en, this message translates to:
  /// **'Propose an expense'**
  String get proposeTitle;

  /// No description provided for @peek.
  ///
  /// In en, this message translates to:
  /// **'Parents let you see this envelope'**
  String get peek;

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Spend · Save · Give plan'**
  String get plan;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @remindersOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Reminders on this device'**
  String get remindersOnDevice;

  /// No description provided for @remindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bills, budgets, kids, goals, savings circles & meetings'**
  String get remindersSubtitle;

  /// No description provided for @quietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours (no notifications inside this window)'**
  String get quietHours;

  /// No description provided for @monthStartsOn.
  ///
  /// In en, this message translates to:
  /// **'Month starts on'**
  String get monthStartsOn;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @largeText.
  ///
  /// In en, this message translates to:
  /// **'Large text (easier to read)'**
  String get largeText;

  /// No description provided for @exportCsvSettings.
  ///
  /// In en, this message translates to:
  /// **'Export transactions (CSV)'**
  String get exportCsvSettings;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersTitle;

  /// No description provided for @scheduledOn.
  ///
  /// In en, this message translates to:
  /// **'Scheduled on this device · quiet hours {from}–{to}'**
  String scheduledOn(String from, String to);

  /// No description provided for @remindersOff.
  ///
  /// In en, this message translates to:
  /// **'Reminders are off'**
  String get remindersOff;

  /// No description provided for @nothingComing.
  ///
  /// In en, this message translates to:
  /// **'Nothing coming up'**
  String get nothingComing;

  /// No description provided for @ob1Title.
  ///
  /// In en, this message translates to:
  /// **'Money, managed together'**
  String get ob1Title;

  /// No description provided for @ob1Body.
  ///
  /// In en, this message translates to:
  /// **'One calm place for everything your family earns, spends, saves and plans — in every currency you use, online or off.'**
  String get ob1Body;

  /// No description provided for @ob2Title.
  ///
  /// In en, this message translates to:
  /// **'Envelopes, not guilt'**
  String get ob2Title;

  /// No description provided for @ob2Body.
  ///
  /// In en, this message translates to:
  /// **'Give every dollar a job. Groceries, school fees, transport — see at a glance what is on track, what needs a top-up, and what is safe to spend today.'**
  String get ob2Body;

  /// No description provided for @ob3Title.
  ///
  /// In en, this message translates to:
  /// **'Built for the whole family'**
  String get ob3Title;

  /// No description provided for @ob3Body.
  ///
  /// In en, this message translates to:
  /// **'Partners share the plan. Kids grow jars and stars safely. Teens propose expenses and learn with savings matches. Grandparents keep the savings-circle record.'**
  String get ob3Body;

  /// No description provided for @ob4Title.
  ///
  /// In en, this message translates to:
  /// **'Gentle reminders'**
  String get ob4Title;

  /// No description provided for @syncPill.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change saved on this device — syncs when online} other{{count} changes saved on this device — syncs when online}}'**
  String syncPill(int count);

  /// No description provided for @hideAmountsTip.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts'**
  String get hideAmountsTip;

  /// No description provided for @showAmountsTip.
  ///
  /// In en, this message translates to:
  /// **'Show amounts'**
  String get showAmountsTip;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @sixMonthNet.
  ///
  /// In en, this message translates to:
  /// **'Six-month net (USD)'**
  String get sixMonthNet;

  /// No description provided for @donutEmpty.
  ///
  /// In en, this message translates to:
  /// **'No spending recorded yet this cycle — the donut fills as you add expenses.'**
  String get donutEmpty;

  /// No description provided for @ob4Body.
  ///
  /// In en, this message translates to:
  /// **'Bill nags, budget watch and the weekly family digest — quiet hours respected, everything on your phone. You are in charge.'**
  String get ob4Body;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Mhuri Hub'**
  String get loginWelcome;

  /// No description provided for @loginEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get loginEnterCode;

  /// No description provided for @loginSentCode.
  ///
  /// In en, this message translates to:
  /// **'We sent a code by SMS to {phone}'**
  String loginSentCode(String phone);

  /// No description provided for @loginSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your phone number to open your family space.'**
  String get loginSignInHint;

  /// No description provided for @loginSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get loginSendCode;

  /// No description provided for @loginVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify & sign in'**
  String get loginVerify;

  /// No description provided for @loginChangeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get loginChangeNumber;

  /// No description provided for @loginBadPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number (e.g. +44 7700 900123).'**
  String get loginBadPhone;

  /// No description provided for @loginFooter.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: use any phone number and code 1234.\nLive mode sends a real SMS code.'**
  String get loginFooter;

  /// No description provided for @quickAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get quickAddTitle;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @envelopeLabel.
  ///
  /// In en, this message translates to:
  /// **'Envelope'**
  String get envelopeLabel;

  /// No description provided for @whoLabel.
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get whoLabel;

  /// No description provided for @paidWithLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid with'**
  String get paidWithLabel;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Note (e.g. FreshMart)'**
  String get noteHint;

  /// No description provided for @enterAmountFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount first'**
  String get enterAmountFirst;

  /// No description provided for @savedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved ✓ — works offline, syncs when online'**
  String get savedOffline;

  /// No description provided for @kidsHi.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}!'**
  String kidsHi(String name);

  /// No description provided for @kidsMyJar.
  ///
  /// In en, this message translates to:
  /// **'My Jar'**
  String get kidsMyJar;

  /// No description provided for @kidsGoalSaved.
  ///
  /// In en, this message translates to:
  /// **'Goal: {goal} — {pct}% saved'**
  String kidsGoalSaved(String goal, int pct);

  /// No description provided for @kidsMyChores.
  ///
  /// In en, this message translates to:
  /// **'My Chores'**
  String get kidsMyChores;

  /// No description provided for @kidsWishList.
  ///
  /// In en, this message translates to:
  /// **'Wish List'**
  String get kidsWishList;

  /// No description provided for @kidsWishItem.
  ///
  /// In en, this message translates to:
  /// **'Soccer ball — US\$25 · saved {amount}'**
  String kidsWishItem(String amount);

  /// No description provided for @kidsAskMoney.
  ///
  /// In en, this message translates to:
  /// **'Ask Mom/Dad\nfor money'**
  String get kidsAskMoney;

  /// No description provided for @kidsDoChore.
  ///
  /// In en, this message translates to:
  /// **'Do a chore'**
  String get kidsDoChore;

  /// No description provided for @kidsAllDone.
  ///
  /// In en, this message translates to:
  /// **'All chores done!'**
  String get kidsAllDone;

  /// No description provided for @kidsParents.
  ///
  /// In en, this message translates to:
  /// **'Parents'**
  String get kidsParents;

  /// No description provided for @kidsAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask Mom & Dad'**
  String get kidsAskTitle;

  /// No description provided for @kidsWhatFor.
  ///
  /// In en, this message translates to:
  /// **'What for?'**
  String get kidsWhatFor;

  /// No description provided for @kidsDefaultReason.
  ///
  /// In en, this message translates to:
  /// **'Pocket money'**
  String get kidsDefaultReason;

  /// No description provided for @teenZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Teen Zone · 13–17'**
  String get teenZoneTitle;

  /// No description provided for @teenNoEarnings.
  ///
  /// In en, this message translates to:
  /// **'No earnings logged yet'**
  String get teenNoEarnings;

  /// No description provided for @teenEarnHint.
  ///
  /// In en, this message translates to:
  /// **'Wash a car, help at the corner shop — log it and watch your jar grow.'**
  String get teenEarnHint;

  /// No description provided for @teenSpend.
  ///
  /// In en, this message translates to:
  /// **'Spend 50%'**
  String get teenSpend;

  /// No description provided for @teenSave.
  ///
  /// In en, this message translates to:
  /// **'Save 40%'**
  String get teenSave;

  /// No description provided for @teenGive.
  ///
  /// In en, this message translates to:
  /// **'Give 10%'**
  String get teenGive;

  /// No description provided for @teenSplitHint.
  ///
  /// In en, this message translates to:
  /// **'Suggested split of {amount} earned this month'**
  String teenSplitHint(String amount);

  /// No description provided for @teenSavedJar.
  ///
  /// In en, this message translates to:
  /// **'Saved to your jar — parents match 50%'**
  String get teenSavedJar;

  /// No description provided for @teenWhatDid.
  ///
  /// In en, this message translates to:
  /// **'What did you do?'**
  String get teenWhatDid;

  /// No description provided for @familyTitle.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get familyTitle;

  /// No description provided for @membersDesc.
  ///
  /// In en, this message translates to:
  /// **'Couple + kids · month starts on the 1st'**
  String get membersDesc;

  /// No description provided for @membersInviteHint.
  ///
  /// In en, this message translates to:
  /// **'Share the code or scan to invite a family member'**
  String get membersInviteHint;

  /// No description provided for @membersDemoTip.
  ///
  /// In en, this message translates to:
  /// **'Demo tip: use \"View as\" to switch profiles. Kids open a sealed mode automatically.'**
  String get membersDemoTip;

  /// No description provided for @setCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency & rates'**
  String get setCurrency;

  /// No description provided for @setCurrencySub.
  ///
  /// In en, this message translates to:
  /// **'USD primary · ZiG secondary · {rate}'**
  String setCurrencySub(String rate);

  /// No description provided for @setPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get setPrivacy;

  /// No description provided for @setPrivacySub.
  ///
  /// In en, this message translates to:
  /// **'Private pockets: off — partner sees shared only'**
  String get setPrivacySub;

  /// No description provided for @setMonthStart.
  ///
  /// In en, this message translates to:
  /// **'Month start day'**
  String get setMonthStart;

  /// No description provided for @setMonthStartSub.
  ///
  /// In en, this message translates to:
  /// **'1st — aligns with salary cycle'**
  String get setMonthStartSub;

  /// No description provided for @setNotif.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get setNotif;

  /// No description provided for @setNotifSub.
  ///
  /// In en, this message translates to:
  /// **'Budget 80% warning · bills · kid requests'**
  String get setNotifSub;

  /// No description provided for @setBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & export'**
  String get setBackup;

  /// No description provided for @setBackupSub.
  ///
  /// In en, this message translates to:
  /// **'Encrypted cloud backup · CSV export (owner)'**
  String get setBackupSub;

  /// No description provided for @meetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Family meeting'**
  String get meetingTitle;

  /// No description provided for @mFigures.
  ///
  /// In en, this message translates to:
  /// **'Last month, in numbers'**
  String get mFigures;

  /// No description provided for @figureIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get figureIncome;

  /// No description provided for @figureSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get figureSpent;

  /// No description provided for @figureSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get figureSaved;

  /// No description provided for @mEnvelopeHealth.
  ///
  /// In en, this message translates to:
  /// **'Envelope health'**
  String get mEnvelopeHealth;

  /// No description provided for @mReachedTalk.
  ///
  /// In en, this message translates to:
  /// **'Talk about the envelopes marked \"Reached\". Top them up together — calmly.'**
  String get mReachedTalk;

  /// No description provided for @mGoals.
  ///
  /// In en, this message translates to:
  /// **'Savings goals'**
  String get mGoals;

  /// No description provided for @mChores.
  ///
  /// In en, this message translates to:
  /// **'Chores, jars & requests'**
  String get mChores;

  /// No description provided for @mImprove.
  ///
  /// In en, this message translates to:
  /// **'One thing to improve'**
  String get mImprove;

  /// No description provided for @recSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped — next: {date}'**
  String recSkipped(String date);

  /// No description provided for @recNew.
  ///
  /// In en, this message translates to:
  /// **'New recurring expense'**
  String get recNew;

  /// No description provided for @recReview.
  ///
  /// In en, this message translates to:
  /// **'Nothing is charged automatically — you review and post everything.'**
  String get recReview;

  /// No description provided for @recNoEnvelope.
  ///
  /// In en, this message translates to:
  /// **'No envelope'**
  String get recNoEnvelope;

  /// No description provided for @recNextDue.
  ///
  /// In en, this message translates to:
  /// **'Next due:'**
  String get recNextDue;

  /// No description provided for @recNameAmount.
  ///
  /// In en, this message translates to:
  /// **'Give it a name and an amount'**
  String get recNameAmount;

  /// No description provided for @recSaveRule.
  ///
  /// In en, this message translates to:
  /// **'Save rule'**
  String get recSaveRule;

  /// No description provided for @recNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. School fees levy)'**
  String get recNameHint;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleAdult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get roleAdult;

  /// No description provided for @roleTeen.
  ///
  /// In en, this message translates to:
  /// **'Teen'**
  String get roleTeen;

  /// No description provided for @roleKid.
  ///
  /// In en, this message translates to:
  /// **'Kid'**
  String get roleKid;

  /// No description provided for @roleViewer.
  ///
  /// In en, this message translates to:
  /// **'Elder · Viewer'**
  String get roleViewer;

  /// No description provided for @methodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// No description provided for @methodMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile money'**
  String get methodMobile;

  /// No description provided for @methodCard.
  ///
  /// In en, this message translates to:
  /// **'Bank card'**
  String get methodCard;

  /// No description provided for @methodTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get methodTransfer;

  /// No description provided for @methodAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent / cash point'**
  String get methodAgent;

  /// No description provided for @methodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get methodOther;

  /// No description provided for @stateToBuy.
  ///
  /// In en, this message translates to:
  /// **'To buy'**
  String get stateToBuy;

  /// No description provided for @stateInCart.
  ///
  /// In en, this message translates to:
  /// **'In cart'**
  String get stateInCart;

  /// No description provided for @stateDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get stateDone;

  /// No description provided for @freqWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get freqWeekly;

  /// No description provided for @freqMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get freqMonthly;

  /// No description provided for @rollReset.
  ///
  /// In en, this message translates to:
  /// **'Reset each month'**
  String get rollReset;

  /// No description provided for @rollRoll.
  ///
  /// In en, this message translates to:
  /// **'Roll over what is left'**
  String get rollRoll;

  /// No description provided for @rollAccum.
  ///
  /// In en, this message translates to:
  /// **'Keep accumulating'**
  String get rollAccum;

  /// No description provided for @freqTerm.
  ///
  /// In en, this message translates to:
  /// **'Per term (~3 months)'**
  String get freqTerm;

  /// No description provided for @budgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgetsTitle;

  /// No description provided for @noEnvelopes.
  ///
  /// In en, this message translates to:
  /// **'No envelopes yet'**
  String get noEnvelopes;

  /// No description provided for @envelopesHint.
  ///
  /// In en, this message translates to:
  /// **'Envelopes are budgets you can see: Groceries, School fees, Transport. Create your first one below.'**
  String get envelopesHint;

  /// No description provided for @newEnvStub.
  ///
  /// In en, this message translates to:
  /// **'New envelope — coming in Phase 1'**
  String get newEnvStub;

  /// No description provided for @addRecurringTip.
  ///
  /// In en, this message translates to:
  /// **'Add recurring expense'**
  String get addRecurringTip;

  /// No description provided for @recReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed before posting — nothing is charged silently.'**
  String get recReviewed;

  /// No description provided for @noRecurring.
  ///
  /// In en, this message translates to:
  /// **'No recurring expenses yet'**
  String get noRecurring;

  /// No description provided for @recurringHint.
  ///
  /// In en, this message translates to:
  /// **'Add school fees, rent or airtime rules — we remind you when each one comes due.'**
  String get recurringHint;

  /// No description provided for @chipOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get chipOnTrack;

  /// No description provided for @chipReached.
  ///
  /// In en, this message translates to:
  /// **'Reached'**
  String get chipReached;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @moveMoney.
  ///
  /// In en, this message translates to:
  /// **'Move money'**
  String get moveMoney;

  /// No description provided for @pickFirst.
  ///
  /// In en, this message translates to:
  /// **'Pick envelopes and an amount first'**
  String get pickFirst;

  /// No description provided for @skipPeriod.
  ///
  /// In en, this message translates to:
  /// **'Skip this period'**
  String get skipPeriod;

  /// No description provided for @pauseRule.
  ///
  /// In en, this message translates to:
  /// **'Pause rule'**
  String get pauseRule;

  /// No description provided for @resumeRule.
  ///
  /// In en, this message translates to:
  /// **'Resume rule'**
  String get resumeRule;

  /// No description provided for @meetingHint.
  ///
  /// In en, this message translates to:
  /// **'15 minutes, once a month.'**
  String get meetingHint;

  /// No description provided for @mChoresLine.
  ///
  /// In en, this message translates to:
  /// **'{stars} stars earned · {requests} request(s) waiting · {proposals} teen proposal(s) waiting.'**
  String mChoresLine(Object proposals, Object requests, Object stars);

  /// No description provided for @meetingNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Cook more on Sundays — musika spending is creeping.\"'**
  String get meetingNoteHint;

  /// No description provided for @meetingSaveNote.
  ///
  /// In en, this message translates to:
  /// **'Save our note'**
  String get meetingSaveNote;

  /// No description provided for @savedTick.
  ///
  /// In en, this message translates to:
  /// **'Saved ✓'**
  String get savedTick;

  /// No description provided for @meetingDone.
  ///
  /// In en, this message translates to:
  /// **'Done — see you next month'**
  String get meetingDone;

  /// No description provided for @reportCard.
  ///
  /// In en, this message translates to:
  /// **'Report card'**
  String get reportCard;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// No description provided for @swapCurrency.
  ///
  /// In en, this message translates to:
  /// **'Swap display currency'**
  String get swapCurrency;

  /// No description provided for @yourChild.
  ///
  /// In en, this message translates to:
  /// **'Your child'**
  String get yourChild;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @markCollected.
  ///
  /// In en, this message translates to:
  /// **'Mark collected'**
  String get markCollected;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @sentToParents.
  ///
  /// In en, this message translates to:
  /// **'Sent to Mom & Dad'**
  String get sentToParents;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get sendRequest;

  /// No description provided for @parentsOnly.
  ///
  /// In en, this message translates to:
  /// **'Parents only'**
  String get parentsOnly;

  /// No description provided for @pinExitLine.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to leave Kids Mode.'**
  String get pinExitLine;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get wrongPin;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// No description provided for @listSharedSub.
  ///
  /// In en, this message translates to:
  /// **'Family shopping list · shared with everyone'**
  String get listSharedSub;

  /// No description provided for @tickFirst.
  ///
  /// In en, this message translates to:
  /// **'Tick items off first'**
  String get tickFirst;

  /// No description provided for @namePriceFirst.
  ///
  /// In en, this message translates to:
  /// **'Give the item a name and price'**
  String get namePriceFirst;

  /// No description provided for @addToList.
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get addToList;

  /// No description provided for @spaceSetup.
  ///
  /// In en, this message translates to:
  /// **'Set up your family space'**
  String get spaceSetup;

  /// No description provided for @spaceSetupSub.
  ///
  /// In en, this message translates to:
  /// **'Create a space for your family, or join the one your partner created with their invite code. Everything you log then syncs between your phones.'**
  String get spaceSetupSub;

  /// No description provided for @createSpace.
  ///
  /// In en, this message translates to:
  /// **'Create space'**
  String get createSpace;

  /// No description provided for @joinWithCode.
  ///
  /// In en, this message translates to:
  /// **'Join with code'**
  String get joinWithCode;

  /// No description provided for @offlineRetry.
  ///
  /// In en, this message translates to:
  /// **'Offline — will retry automatically'**
  String get offlineRetry;

  /// No description provided for @syncProblem.
  ///
  /// In en, this message translates to:
  /// **'Sync problem'**
  String get syncProblem;

  /// No description provided for @signinExpired.
  ///
  /// In en, this message translates to:
  /// **'Sign-in expired — sign out and back in'**
  String get signinExpired;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @lastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {last}'**
  String lastSync(Object last);

  /// No description provided for @familySpace.
  ///
  /// In en, this message translates to:
  /// **'Family space'**
  String get familySpace;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @createFamilySpace.
  ///
  /// In en, this message translates to:
  /// **'Create family space'**
  String get createFamilySpace;

  /// No description provided for @familyName.
  ///
  /// In en, this message translates to:
  /// **'Family name'**
  String get familyName;

  /// No description provided for @localizedNote.
  ///
  /// In en, this message translates to:
  /// **'The whole app now speaks six languages — no more EN-only screens.'**
  String get localizedNote;

  /// No description provided for @nextCreateSpace.
  ///
  /// In en, this message translates to:
  /// **'Next: create your family space (or join with a code) from the Family tab.'**
  String get nextCreateSpace;

  /// No description provided for @reachedMove.
  ///
  /// In en, this message translates to:
  /// **'{on} of {total} envelopes still on track. Open the ones marked \"Reached\" and move money in — calm, not perfect.'**
  String reachedMove(Object on, Object total);

  /// No description provided for @cashTrace.
  ///
  /// In en, this message translates to:
  /// **'Cash is easy to spend and hard to trace. Paying a bit more by mobile money or bank card keeps the picture clearer.'**
  String get cashTrace;

  /// No description provided for @whereMoneyWent.
  ///
  /// In en, this message translates to:
  /// **'Where the money went'**
  String get whereMoneyWent;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed on this device'**
  String get exportFailed;

  /// No description provided for @csvSaved.
  ///
  /// In en, this message translates to:
  /// **'CSV saved: {path}'**
  String csvSaved(Object path);

  /// No description provided for @exportedPath.
  ///
  /// In en, this message translates to:
  /// **'Exported ✓ {path}'**
  String exportedPath(Object path);

  /// No description provided for @bringToMeeting.
  ///
  /// In en, this message translates to:
  /// **'Bring this to the monthly Family Meeting'**
  String get bringToMeeting;

  /// No description provided for @savingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get savingsTitle;

  /// No description provided for @markRound.
  ///
  /// In en, this message translates to:
  /// **'Mark this round collected'**
  String get markRound;

  /// No description provided for @recordsOnly.
  ///
  /// In en, this message translates to:
  /// **'Mhuri Hub never holds the money — records only.'**
  String get recordsOnly;

  /// No description provided for @saveContribution.
  ///
  /// In en, this message translates to:
  /// **'Save contribution'**
  String get saveContribution;

  /// No description provided for @sendTest.
  ///
  /// In en, this message translates to:
  /// **'Send a test notification'**
  String get sendTest;

  /// No description provided for @testOk.
  ///
  /// In en, this message translates to:
  /// **'Reminders are working on this device.'**
  String get testOk;

  /// No description provided for @monthCycle.
  ///
  /// In en, this message translates to:
  /// **'Month cycle'**
  String get monthCycle;

  /// No description provided for @paydayAlign.
  ///
  /// In en, this message translates to:
  /// **'Payday-aligned budgets — cycles reset on this day, and the family meeting reminder lands the evening before'**
  String get paydayAlign;

  /// No description provided for @backupComing.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore (coming)'**
  String get backupComing;

  /// No description provided for @fromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLabel;

  /// No description provided for @addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get addTransaction;

  /// No description provided for @logWhatAmount.
  ///
  /// In en, this message translates to:
  /// **'Add what you did and the amount'**
  String get logWhatAmount;

  /// No description provided for @logIt.
  ///
  /// In en, this message translates to:
  /// **'Log it'**
  String get logIt;

  /// No description provided for @fromEnvelope.
  ///
  /// In en, this message translates to:
  /// **'From envelope'**
  String get fromEnvelope;

  /// No description provided for @amountPurposeFirst.
  ///
  /// In en, this message translates to:
  /// **'Add an amount and what it is for'**
  String get amountPurposeFirst;

  /// No description provided for @sentApproval.
  ///
  /// In en, this message translates to:
  /// **'Sent to Mom & Dad for approval'**
  String get sentApproval;

  /// No description provided for @sendProposal.
  ///
  /// In en, this message translates to:
  /// **'Send proposal'**
  String get sendProposal;

  /// No description provided for @stWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting ⏳'**
  String get stWaiting;

  /// No description provided for @stApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved ✓'**
  String get stApproved;

  /// No description provided for @stDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get stDeclined;

  /// No description provided for @requestTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} requested {amount}'**
  String requestTitle(Object amount, Object name);

  /// No description provided for @proposalTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} proposes {amount}'**
  String proposalTitle(Object amount, Object name);

  /// No description provided for @proposalSub.
  ///
  /// In en, this message translates to:
  /// **'{reason} · from {env}'**
  String proposalSub(Object env, Object reason);

  /// No description provided for @recDueSub.
  ///
  /// In en, this message translates to:
  /// **'Recurring · comes due {when} · post it when you pay it'**
  String recDueSub(Object when);

  /// No description provided for @dueNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get dueNow;

  /// No description provided for @dueSoon.
  ///
  /// In en, this message translates to:
  /// **'soon'**
  String get dueSoon;

  /// No description provided for @choreDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" done — confirm?'**
  String choreDoneTitle(Object name);

  /// No description provided for @choreDoneSub.
  ///
  /// In en, this message translates to:
  /// **'{stars} stars — confirm to grow the jar'**
  String choreDoneSub(Object stars);

  /// No description provided for @circleSub.
  ///
  /// In en, this message translates to:
  /// **'{who} to collect {amount} · pot {pot} so far'**
  String circleSub(Object amount, Object pot, Object who);

  /// No description provided for @exportReal.
  ///
  /// In en, this message translates to:
  /// **'Export works on a real device'**
  String get exportReal;

  /// No description provided for @allSynced.
  ///
  /// In en, this message translates to:
  /// **'✓ All changes synced'**
  String get allSynced;

  /// No description provided for @familyCta.
  ///
  /// In en, this message translates to:
  /// **'Family ›'**
  String get familyCta;

  /// No description provided for @recentInEnv.
  ///
  /// In en, this message translates to:
  /// **'Recent in this envelope'**
  String get recentInEnv;

  /// No description provided for @nothingLogged.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged here yet.'**
  String get nothingLogged;

  /// No description provided for @dueBy.
  ///
  /// In en, this message translates to:
  /// **'overdue by {days}d'**
  String dueBy(Object days);

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'due today'**
  String get dueToday;

  /// No description provided for @dueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'due tomorrow'**
  String get dueTomorrow;

  /// No description provided for @dueIn.
  ///
  /// In en, this message translates to:
  /// **'due in {days}d'**
  String dueIn(Object days);

  /// No description provided for @circleTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings circle — Round {round} of {total}'**
  String circleTitle(Object round, Object total);

  /// No description provided for @postedSnack.
  ///
  /// In en, this message translates to:
  /// **'{name} posted ✓ — envelope updated'**
  String postedSnack(Object name);

  /// No description provided for @starsGiven.
  ///
  /// In en, this message translates to:
  /// **'{stars} stars given to the kids!'**
  String starsGiven(Object stars);

  /// No description provided for @approvedReq.
  ///
  /// In en, this message translates to:
  /// **'Approved ✓ — {amount} added to {name}'**
  String approvedReq(Object amount, Object name);

  /// No description provided for @declineBody.
  ///
  /// In en, this message translates to:
  /// **'{reason}\n\nFrom envelope: {env}'**
  String declineBody(Object env, Object reason);

  /// No description provided for @approvedProp.
  ///
  /// In en, this message translates to:
  /// **'Approved ✓ — {amount} logged to {env}'**
  String approvedProp(Object amount, Object env);

  /// No description provided for @sentKid.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" sent to Mom & Dad'**
  String sentKid(Object name);

  /// No description provided for @listEmptyAdd.
  ///
  /// In en, this message translates to:
  /// **'Nothing here — add an item with ＋'**
  String get listEmptyAdd;

  /// No description provided for @usesPct.
  ///
  /// In en, this message translates to:
  /// **'Uses {pct}% of the {name}'**
  String usesPct(Object name, Object pct);

  /// No description provided for @loggedTo.
  ///
  /// In en, this message translates to:
  /// **'Logged {amount} to {name} ✓ — envelope updated'**
  String loggedTo(Object amount, Object name);

  /// No description provided for @finishShop.
  ///
  /// In en, this message translates to:
  /// **'Finish shopping → log expense'**
  String get finishShop;

  /// No description provided for @estPrice.
  ///
  /// In en, this message translates to:
  /// **'Est. unit price ({symbol})'**
  String estPrice(Object symbol);

  /// No description provided for @myFamily.
  ///
  /// In en, this message translates to:
  /// **'My family'**
  String get myFamily;

  /// No description provided for @spaceCreated.
  ///
  /// In en, this message translates to:
  /// **'Family space created ✓ Invite code: {code}'**
  String spaceCreated(Object code);

  /// No description provided for @createFail.
  ///
  /// In en, this message translates to:
  /// **'Could not create the space — try again'**
  String get createFail;

  /// No description provided for @joinSpaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a family space'**
  String get joinSpaceTitle;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCode;

  /// No description provided for @joinedOk.
  ///
  /// In en, this message translates to:
  /// **'Joined ✓ — your family data is syncing'**
  String get joinedOk;

  /// No description provided for @joinFail.
  ///
  /// In en, this message translates to:
  /// **'Could not join — try again'**
  String get joinFail;

  /// No description provided for @kidsPin.
  ///
  /// In en, this message translates to:
  /// **'Kids Mode exit PIN'**
  String get kidsPin;

  /// No description provided for @kidsPinSub.
  ///
  /// In en, this message translates to:
  /// **'Required to leave Kids Mode — tap to change'**
  String get kidsPinSub;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in: {masked}'**
  String signedInAs(Object masked);

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @viewAs.
  ///
  /// In en, this message translates to:
  /// **'View as'**
  String get viewAs;

  /// No description provided for @cashShare.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of spending'**
  String cashShare(Object pct);

  /// No description provided for @donutA11y.
  ///
  /// In en, this message translates to:
  /// **'Spending by envelope, {name} selected, {share} percent'**
  String donutA11y(Object name, Object share);

  /// No description provided for @starsHome.
  ///
  /// In en, this message translates to:
  /// **'{stars} stars — confirm chores on Home to grow jars'**
  String starsHome(Object stars);

  /// No description provided for @circleMember.
  ///
  /// In en, this message translates to:
  /// **'Savings circle · {name}'**
  String circleMember(Object name);

  /// No description provided for @potSoFar.
  ///
  /// In en, this message translates to:
  /// **'Pot so far: {pot}'**
  String potSoFar(Object pot);

  /// No description provided for @roundOk.
  ///
  /// In en, this message translates to:
  /// **'Round recorded ✓ — records only, we never hold money'**
  String get roundOk;

  /// No description provided for @addToGoal.
  ///
  /// In en, this message translates to:
  /// **'Add to {name}'**
  String addToGoal(Object name);

  /// No description provided for @addedToGoal.
  ///
  /// In en, this message translates to:
  /// **'Added to {name}'**
  String addedToGoal(Object name);

  /// No description provided for @goalBase.
  ///
  /// In en, this message translates to:
  /// **'Goal base: {short}'**
  String goalBase(Object short);

  /// No description provided for @syncTime.
  ///
  /// In en, this message translates to:
  /// **'today at {t}'**
  String syncTime(Object t);

  /// No description provided for @watch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watch;

  /// No description provided for @spentLabel.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spentLabel;

  /// No description provided for @limitLabel.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get limitLabel;

  /// No description provided for @memberPot.
  ///
  /// In en, this message translates to:
  /// **'Pot so far: {pot} · {contribution} × {count} members'**
  String memberPot(Object contribution, Object count, Object pot);

  /// No description provided for @switchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch profile'**
  String get switchProfile;

  /// No description provided for @switchProfileSub.
  ///
  /// In en, this message translates to:
  /// **'Preview the app as another family member'**
  String get switchProfileSub;

  /// No description provided for @youTag.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youTag;

  /// No description provided for @pickCurrency.
  ///
  /// In en, this message translates to:
  /// **'Display currency'**
  String get pickCurrency;

  /// No description provided for @rateField.
  ///
  /// In en, this message translates to:
  /// **'ZiG per 1 USD'**
  String get rateField;

  /// No description provided for @rateSave.
  ///
  /// In en, this message translates to:
  /// **'Save rate'**
  String get rateSave;

  /// No description provided for @rateReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to RBZ snapshot'**
  String get rateReset;

  /// No description provided for @rateCustomNote.
  ///
  /// In en, this message translates to:
  /// **'Used for the ZiG view across the whole app. The bundled RBZ snapshot is 15.27.'**
  String get rateCustomNote;

  /// No description provided for @autoHide.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts when I leave the app'**
  String get autoHide;

  /// No description provided for @autoHideSub.
  ///
  /// In en, this message translates to:
  /// **'Balances hide automatically when the app goes to the background — turn off if you prefer.'**
  String get autoHideSub;

  /// No description provided for @hideNow.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts right now'**
  String get hideNow;

  /// No description provided for @exportCsvRow.
  ///
  /// In en, this message translates to:
  /// **'Export all transactions (CSV)'**
  String get exportCsvRow;

  /// No description provided for @copyInvite.
  ///
  /// In en, this message translates to:
  /// **'Copy invite code'**
  String get copyInvite;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied ✓'**
  String get copied;

  /// No description provided for @inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite a family member'**
  String get inviteTitle;

  /// No description provided for @inviteDemoNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode comes with a seeded family. In live mode your invite code lives here — share it and the family joins your space.'**
  String get inviteDemoNote;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @editProfileSub.
  ///
  /// In en, this message translates to:
  /// **'Name and avatar for this member'**
  String get editProfileSub;

  /// No description provided for @photoNote.
  ///
  /// In en, this message translates to:
  /// **'Profile photos arrive with family sync. Avatars are live now.'**
  String get photoNote;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'en',
        'es',
        'fr',
        'nd',
        'pt',
        'sn'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'nd':
      return AppLocalizationsNd();
    case 'pt':
      return AppLocalizationsPt();
    case 'sn':
      return AppLocalizationsSn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
