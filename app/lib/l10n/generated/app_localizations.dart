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
  /// **'Shopping'**
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

  /// No description provided for @availableToSpendLabel.
  ///
  /// In en, this message translates to:
  /// **'Available to spend'**
  String get availableToSpendLabel;

  /// No description provided for @savingsExceedsCashTitle.
  ///
  /// In en, this message translates to:
  /// **'Not enough available cash'**
  String get savingsExceedsCashTitle;

  /// No description provided for @savingsExceedsCashBody.
  ///
  /// In en, this message translates to:
  /// **'This contribution is {amount} more than the cash available to spend.'**
  String savingsExceedsCashBody(Object amount);

  /// No description provided for @goalOverfundTitle.
  ///
  /// In en, this message translates to:
  /// **'This exceeds the goal'**
  String get goalOverfundTitle;

  /// No description provided for @goalOverfundBody.
  ///
  /// In en, this message translates to:
  /// **'The contribution puts this goal {amount} above its target. Add it anyway?'**
  String goalOverfundBody(Object amount);

  /// No description provided for @addAnyway.
  ///
  /// In en, this message translates to:
  /// **'Add anyway'**
  String get addAnyway;

  /// No description provided for @safeToSpend.
  ///
  /// In en, this message translates to:
  /// **'Available today: {amount}'**
  String safeToSpend(Object amount);

  /// No description provided for @flexibleSpendTitle.
  ///
  /// In en, this message translates to:
  /// **'Available today'**
  String get flexibleSpendTitle;

  /// No description provided for @flexibleSpendExplanation.
  ///
  /// In en, this message translates to:
  /// **'What remains today after protecting savings and money reserved in your budgets.'**
  String get flexibleSpendExplanation;

  /// No description provided for @reservedForEnvelopes.
  ///
  /// In en, this message translates to:
  /// **'Reserved for budgets'**
  String get reservedForEnvelopes;

  /// No description provided for @freeAfterCommitments.
  ///
  /// In en, this message translates to:
  /// **'Free after commitments'**
  String get freeAfterCommitments;

  /// No description provided for @daysRemaining.
  ///
  /// In en, this message translates to:
  /// **'Days remaining: {count}'**
  String daysRemaining(int count);

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
  /// **'New budget'**
  String get newEnvelope;

  /// No description provided for @recurringExpenses.
  ///
  /// In en, this message translates to:
  /// **'Regular payments'**
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
  /// **'Every expense, income and approval shows up here - add your first one with the + button.'**
  String get noActivityHint;

  /// No description provided for @noGoals.
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get noGoals;

  /// No description provided for @noGoalsHint.
  ///
  /// In en, this message translates to:
  /// **'Start with an emergency fund - even a little each week changes how emergencies feel.'**
  String get noGoalsHint;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly summary'**
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
  /// **'Available per day'**
  String get safePerDay;

  /// No description provided for @envelopeHealth.
  ///
  /// In en, this message translates to:
  /// **'Budget progress'**
  String get envelopeHealth;

  /// No description provided for @cashLeak.
  ///
  /// In en, this message translates to:
  /// **'Cash spending'**
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
  /// **'Parents let you see this budget'**
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
  /// **'Quiet hours'**
  String get quietHours;

  /// No description provided for @monthStartsOn.
  ///
  /// In en, this message translates to:
  /// **'Starts on'**
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
  String scheduledOn(Object from, Object to);

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
  /// **'One calm place for everything your family earns, spends, saves and plans - in every currency you use, online or off.'**
  String get ob1Body;

  /// No description provided for @ob2Title.
  ///
  /// In en, this message translates to:
  /// **'Plan without the guilt'**
  String get ob2Title;

  /// No description provided for @ob2Body.
  ///
  /// In en, this message translates to:
  /// **'Give every dollar a job. Groceries, school fees, transport - see what is on track, what needs attention, and what remains today.'**
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
  /// **'{count, plural, =1{1 change saved on this device - syncs when online} other{{count} changes saved on this device - syncs when online}}'**
  String syncPill(num count);

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
  /// **'Money left each month (USD)'**
  String get sixMonthNet;

  /// No description provided for @donutEmpty.
  ///
  /// In en, this message translates to:
  /// **'No spending recorded yet this cycle - the donut fills as you add expenses.'**
  String get donutEmpty;

  /// No description provided for @ob4Body.
  ///
  /// In en, this message translates to:
  /// **'Bill nags, budget watch and the weekly family digest - quiet hours respected, everything on your phone. You are in charge.'**
  String get ob4Body;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Mhuri'**
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
  String loginSentCode(Object phone);

  /// No description provided for @loginSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your email to open your family space.'**
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
  /// **'Budget'**
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
  /// **'Saved ✓ - works offline, syncs when online'**
  String get savedOffline;

  /// No description provided for @kidsHi.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}!'**
  String kidsHi(Object name);

  /// No description provided for @kidsMyJar.
  ///
  /// In en, this message translates to:
  /// **'My Jar'**
  String get kidsMyJar;

  /// No description provided for @kidsGoalSaved.
  ///
  /// In en, this message translates to:
  /// **'Goal: {goal} - {pct}% saved'**
  String kidsGoalSaved(Object goal, Object pct);

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
  /// **'Soccer ball - US\$25 · saved {amount}'**
  String kidsWishItem(Object amount);

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

  /// No description provided for @kidsNoChores.
  ///
  /// In en, this message translates to:
  /// **'No chores are waiting. Ask a parent to add one when you are ready.'**
  String get kidsNoChores;

  /// No description provided for @kidsParentArea.
  ///
  /// In en, this message translates to:
  /// **'Parent area'**
  String get kidsParentArea;

  /// No description provided for @kidsAndChores.
  ///
  /// In en, this message translates to:
  /// **'Kids & chores'**
  String get kidsAndChores;

  /// No description provided for @addChore.
  ///
  /// In en, this message translates to:
  /// **'Add chore'**
  String get addChore;

  /// No description provided for @addChoreHint.
  ///
  /// In en, this message translates to:
  /// **'Create a family chore and choose its star reward.'**
  String get addChoreHint;

  /// No description provided for @choreName.
  ///
  /// In en, this message translates to:
  /// **'Chore name'**
  String get choreName;

  /// No description provided for @starReward.
  ///
  /// In en, this message translates to:
  /// **'Star reward'**
  String get starReward;

  /// No description provided for @choreFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a chore name and at least 1 star.'**
  String get choreFieldsRequired;

  /// No description provided for @choreAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} added for the kids.'**
  String choreAdded(Object name);

  /// No description provided for @noFamilyChores.
  ///
  /// In en, this message translates to:
  /// **'No chores yet. Add the first one for the kids.'**
  String get noFamilyChores;

  /// No description provided for @choreStars.
  ///
  /// In en, this message translates to:
  /// **'{stars} stars'**
  String choreStars(Object stars);

  /// No description provided for @kidsNoWish.
  ///
  /// In en, this message translates to:
  /// **'No wish selected yet'**
  String get kidsNoWish;

  /// No description provided for @kidsWishProgress.
  ///
  /// In en, this message translates to:
  /// **'{name} · {target} goal · {saved} saved'**
  String kidsWishProgress(Object name, Object target, Object saved);

  /// No description provided for @kidsJars.
  ///
  /// In en, this message translates to:
  /// **'Kids\' savings'**
  String get kidsJars;

  /// No description provided for @addKidWish.
  ///
  /// In en, this message translates to:
  /// **'Add a kid\'s wish'**
  String get addKidWish;

  /// No description provided for @childLabel.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get childLabel;

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
  /// **'Wash a car, help at the corner shop - log it and watch your jar grow.'**
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
  String teenSplitHint(Object amount);

  /// No description provided for @teenSavedJar.
  ///
  /// In en, this message translates to:
  /// **'Saved to your jar - parents match 50%'**
  String get teenSavedJar;

  /// No description provided for @teenJarCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare your savings jar. Check your connection and try again.'**
  String get teenJarCreateFailed;

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

  /// No description provided for @membersCycleDesc.
  ///
  /// In en, this message translates to:
  /// **'Budget cycle starts on day {day}'**
  String membersCycleDesc(int day);

  /// No description provided for @membersInviteHint.
  ///
  /// In en, this message translates to:
  /// **'Create a secure, role-based invitation for each family member'**
  String get membersInviteHint;

  /// No description provided for @setCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency & rates'**
  String get setCurrency;

  /// No description provided for @setCurrencySub.
  ///
  /// In en, this message translates to:
  /// **'USD primary · ZiG secondary · {rate}'**
  String setCurrencySub(Object rate);

  /// No description provided for @setPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get setPrivacy;

  /// No description provided for @setPrivacySub.
  ///
  /// In en, this message translates to:
  /// **'Private pockets: off - partner sees shared only'**
  String get setPrivacySub;

  /// No description provided for @setMonthStart.
  ///
  /// In en, this message translates to:
  /// **'Month start day'**
  String get setMonthStart;

  /// No description provided for @setMonthStartSub.
  ///
  /// In en, this message translates to:
  /// **'1st - aligns with salary cycle'**
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
  /// **'Budget progress'**
  String get mEnvelopeHealth;

  /// No description provided for @mReachedTalk.
  ///
  /// In en, this message translates to:
  /// **'Talk about the budgets that need attention and adjust them together.'**
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
  /// **'Skipped - next: {date}'**
  String recSkipped(Object date);

  /// No description provided for @recNew.
  ///
  /// In en, this message translates to:
  /// **'New regular payment'**
  String get recNew;

  /// No description provided for @recReview.
  ///
  /// In en, this message translates to:
  /// **'Nothing is charged automatically - you review and post everything.'**
  String get recReview;

  /// No description provided for @recNoEnvelope.
  ///
  /// In en, this message translates to:
  /// **'No budget'**
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
  /// **'Viewer'**
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
  /// **'No budgets yet'**
  String get noEnvelopes;

  /// No description provided for @envelopesHint.
  ///
  /// In en, this message translates to:
  /// **'Create a budget for groceries, school, transport or anything your family plans for.'**
  String get envelopesHint;

  /// No description provided for @newEnvStub.
  ///
  /// In en, this message translates to:
  /// **'New budget'**
  String get newEnvStub;

  /// No description provided for @addRecurringTip.
  ///
  /// In en, this message translates to:
  /// **'Add regular payment'**
  String get addRecurringTip;

  /// No description provided for @recReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed before posting - nothing is charged silently.'**
  String get recReviewed;

  /// No description provided for @noRecurring.
  ///
  /// In en, this message translates to:
  /// **'No regular payments yet'**
  String get noRecurring;

  /// No description provided for @recurringHint.
  ///
  /// In en, this message translates to:
  /// **'Add school fees, rent, netflix or airtime rules - we remind you when each one comes due.'**
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
  /// **'Choose budgets and an amount first'**
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
  String mChoresLine(Object stars, Object requests, Object proposals);

  /// No description provided for @meetingNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Cook more on Sundays - musika spending is creeping.\"'**
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
  /// **'Done - see you next month'**
  String get meetingDone;

  /// No description provided for @reportCard.
  ///
  /// In en, this message translates to:
  /// **'Monthly summary'**
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
  /// **'Your family\'s shared shopping list'**
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
  /// **'Offline - will retry automatically'**
  String get offlineRetry;

  /// No description provided for @syncProblem.
  ///
  /// In en, this message translates to:
  /// **'Sync problem'**
  String get syncProblem;

  /// No description provided for @signinExpired.
  ///
  /// In en, this message translates to:
  /// **'Sign-in expired - sign out and back in'**
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
  /// **'The whole app now speaks six languages - no more EN-only screens.'**
  String get localizedNote;

  /// No description provided for @nextCreateSpace.
  ///
  /// In en, this message translates to:
  /// **'Next: create your family space (or join with a code) from the Family tab.'**
  String get nextCreateSpace;

  /// No description provided for @reachedMove.
  ///
  /// In en, this message translates to:
  /// **'{on} of {total} budgets are on track. Open a budget to review or move money.'**
  String reachedMove(Object on, Object total);

  /// No description provided for @cashTrace.
  ///
  /// In en, this message translates to:
  /// **'Cash is easy to spend and hard to trace. Paying a bit more by mobile money or bank card keeps the picture clearer.'**
  String get cashTrace;

  /// No description provided for @whereMoneyWent.
  ///
  /// In en, this message translates to:
  /// **'Your spending'**
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
  /// **'Mhuri never holds the money - records only.'**
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
  /// **'Budget month'**
  String get monthCycle;

  /// No description provided for @paydayAlign.
  ///
  /// In en, this message translates to:
  /// **'Payday-aligned budgets - cycles reset on this day, and the family meeting reminder lands the evening before'**
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
  /// **'From budget'**
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
  String requestTitle(Object name, Object amount);

  /// No description provided for @proposalTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} proposes {amount}'**
  String proposalTitle(Object name, Object amount);

  /// No description provided for @proposalSub.
  ///
  /// In en, this message translates to:
  /// **'{reason} · from {env}'**
  String proposalSub(Object reason, Object env);

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
  /// **'\"{name}\" done - confirm?'**
  String choreDoneTitle(Object name);

  /// No description provided for @choreDoneSub.
  ///
  /// In en, this message translates to:
  /// **'{stars} stars - confirm to grow the jar'**
  String choreDoneSub(Object stars);

  /// No description provided for @circleSub.
  ///
  /// In en, this message translates to:
  /// **'{who} to collect {amount} · pot {pot} so far'**
  String circleSub(Object who, Object amount, Object pot);

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
  /// **'Recent activity in this budget'**
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
  /// **'Savings circle - Round {round} of {total}'**
  String circleTitle(Object round, Object total);

  /// No description provided for @postedSnack.
  ///
  /// In en, this message translates to:
  /// **'{name} posted ✓ - budget updated'**
  String postedSnack(Object name);

  /// No description provided for @starsGiven.
  ///
  /// In en, this message translates to:
  /// **'{stars} stars given to the kids!'**
  String starsGiven(Object stars);

  /// No description provided for @approvedReq.
  ///
  /// In en, this message translates to:
  /// **'Approved ✓ - {amount} added to {name}'**
  String approvedReq(Object amount, Object name);

  /// No description provided for @declineBody.
  ///
  /// In en, this message translates to:
  /// **'{reason}\n\nFrom budget: {env}'**
  String declineBody(Object reason, Object env);

  /// No description provided for @approvedProp.
  ///
  /// In en, this message translates to:
  /// **'Approved ✓ - {amount} logged to {env}'**
  String approvedProp(Object amount, Object env);

  /// No description provided for @sentKid.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" sent to Mom & Dad'**
  String sentKid(Object name);

  /// No description provided for @listEmptyAdd.
  ///
  /// In en, this message translates to:
  /// **'Nothing here - add an item with ＋'**
  String get listEmptyAdd;

  /// No description provided for @usesPct.
  ///
  /// In en, this message translates to:
  /// **'Uses {pct}% of the {name}'**
  String usesPct(Object pct, Object name);

  /// No description provided for @loggedTo.
  ///
  /// In en, this message translates to:
  /// **'Recorded {amount} in {name} ✓ - budget updated'**
  String loggedTo(Object amount, Object name);

  /// No description provided for @finishShop.
  ///
  /// In en, this message translates to:
  /// **'Record shopping expense'**
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
  /// **'Could not create the space - try again'**
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
  /// **'Joined ✓ - your family data is syncing'**
  String get joinedOk;

  /// No description provided for @joinFail.
  ///
  /// In en, this message translates to:
  /// **'Could not join - try again'**
  String get joinFail;

  /// No description provided for @kidsPin.
  ///
  /// In en, this message translates to:
  /// **'Kids Mode exit PIN'**
  String get kidsPin;

  /// No description provided for @kidsPinSub.
  ///
  /// In en, this message translates to:
  /// **'Required to leave Kids Mode - tap to change'**
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
  /// **'Preview as…'**
  String get viewAs;

  /// No description provided for @cashShare.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of spending'**
  String cashShare(Object pct);

  /// No description provided for @donutA11y.
  ///
  /// In en, this message translates to:
  /// **'Spending by budget, {name} selected, {share} percent'**
  String donutA11y(Object name, Object share);

  /// No description provided for @starsHome.
  ///
  /// In en, this message translates to:
  /// **'{stars} stars - confirm chores on Home to grow jars'**
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
  /// **'Round recorded ✓ - records only, we never hold money'**
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

  /// No description provided for @envelopeRemaining.
  ///
  /// In en, this message translates to:
  /// **'{name} has {amount} remaining'**
  String envelopeRemaining(Object name, Object amount);

  /// No description provided for @envelopeWillLeave.
  ///
  /// In en, this message translates to:
  /// **'This leaves {amount} in {name}'**
  String envelopeWillLeave(Object amount, Object name);

  /// No description provided for @envelopeWillExceed.
  ///
  /// In en, this message translates to:
  /// **'This puts {name} {amount} over budget'**
  String envelopeWillExceed(Object name, Object amount);

  /// No description provided for @overBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'This budget will be over its limit'**
  String get overBudgetTitle;

  /// No description provided for @overBudgetBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be over by {amount}. The expense can still be recorded.'**
  String overBudgetBody(Object name, Object amount);

  /// No description provided for @adjustAmount.
  ///
  /// In en, this message translates to:
  /// **'Adjust amount'**
  String get adjustAmount;

  /// No description provided for @logAnyway.
  ///
  /// In en, this message translates to:
  /// **'Log anyway'**
  String get logAnyway;

  /// No description provided for @overBy.
  ///
  /// In en, this message translates to:
  /// **'Over by {amount}'**
  String overBy(Object amount);

  /// No description provided for @overBudgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get overBudgetLabel;

  /// No description provided for @memberPot.
  ///
  /// In en, this message translates to:
  /// **'Pot so far: {pot} · {contribution} × {count} members'**
  String memberPot(Object pot, Object contribution, Object count);

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
  /// **'Exchange rate'**
  String get rateField;

  /// No description provided for @rateSave.
  ///
  /// In en, this message translates to:
  /// **'Save rate'**
  String get rateSave;

  /// No description provided for @rateReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default rate'**
  String get rateReset;

  /// No description provided for @rateCustomNote.
  ///
  /// In en, this message translates to:
  /// **'Used for currency conversion across the whole app.'**
  String get rateCustomNote;

  /// No description provided for @autoHide.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts when I leave the app'**
  String get autoHide;

  /// No description provided for @autoHideSub.
  ///
  /// In en, this message translates to:
  /// **'Balances hide automatically when the app goes to the background - turn off if you prefer.'**
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
  /// **'Invite family member'**
  String get inviteTitle;

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
  /// **'Photos upload to your family\'s server and show across devices.'**
  String get photoNote;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your sign-in and removes this device\'s saved financial data. This cannot be undone.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t delete your account. Check your connection and try again.'**
  String get deleteAccountFailed;

  /// No description provided for @moreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get moreDetails;

  /// No description provided for @lessDetails.
  ///
  /// In en, this message translates to:
  /// **'Fewer details'**
  String get lessDetails;

  /// No description provided for @discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this entry?'**
  String get discardTitle;

  /// No description provided for @discardBody.
  ///
  /// In en, this message translates to:
  /// **'You entered details that are not saved yet.'**
  String get discardBody;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View balance details'**
  String get viewDetails;

  /// No description provided for @fabTip.
  ///
  /// In en, this message translates to:
  /// **'Tap + to record money in or out'**
  String get fabTip;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @loginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSignIn;

  /// No description provided for @loginCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get loginCreateAccount;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @brandTagline.
  ///
  /// In en, this message translates to:
  /// **'FAMILY MONEY, TOGETHER'**
  String get brandTagline;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createAccountTitle;

  /// No description provided for @createAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Start your secure family money space.'**
  String get createAccountHint;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @sendingPasswordReset.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sendingPasswordReset;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent - open the link on this phone and the app will finish it.'**
  String get passwordResetSent;

  /// No description provided for @passwordResetFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t send the reset email. Check your connection and try again.'**
  String get passwordResetFailed;

  /// No description provided for @newToMhuri.
  ///
  /// In en, this message translates to:
  /// **'New to Mhuri?'**
  String get newToMhuri;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @loginBadEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get loginBadEmail;

  /// No description provided for @loginShortPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get loginShortPassword;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Almost there - check your inbox and confirm your email, then sign in.'**
  String get checkYourEmail;

  /// No description provided for @togglePassword.
  ///
  /// In en, this message translates to:
  /// **'Show or hide password'**
  String get togglePassword;

  /// No description provided for @inviteHowTo.
  ///
  /// In en, this message translates to:
  /// **'They create an account with their email, then enter this code to join your family.'**
  String get inviteHowTo;

  /// No description provided for @obDone.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get started'**
  String get obDone;

  /// No description provided for @setupChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your family'**
  String get setupChoiceTitle;

  /// No description provided for @setupChoiceBody.
  ///
  /// In en, this message translates to:
  /// **'Mhuri works for one family, together. Create yours, or join the one you belong to.'**
  String get setupChoiceBody;

  /// No description provided for @setupCreateCard.
  ///
  /// In en, this message translates to:
  /// **'Create a family'**
  String get setupCreateCard;

  /// No description provided for @setupCreateCardBody.
  ///
  /// In en, this message translates to:
  /// **'Name it, pick your household type, invite your people.'**
  String get setupCreateCardBody;

  /// No description provided for @setupJoinCard.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get setupJoinCard;

  /// No description provided for @setupJoinCardBody.
  ///
  /// In en, this message translates to:
  /// **'Someone invited you - enter their family code to join them.'**
  String get setupJoinCardBody;

  /// No description provided for @createFamilyCta.
  ///
  /// In en, this message translates to:
  /// **'Create family'**
  String get createFamilyCta;

  /// No description provided for @joinFamilyCta.
  ///
  /// In en, this message translates to:
  /// **'Join family'**
  String get joinFamilyCta;

  /// No description provided for @familyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Family name'**
  String get familyNameLabel;

  /// No description provided for @familyNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. The Marufu Family'**
  String get familyNameHint;

  /// No description provided for @householdLabel.
  ///
  /// In en, this message translates to:
  /// **'What kind of family?'**
  String get householdLabel;

  /// No description provided for @hhCouple.
  ///
  /// In en, this message translates to:
  /// **'Couple with kids'**
  String get hhCouple;

  /// No description provided for @hhSingle.
  ///
  /// In en, this message translates to:
  /// **'Single parent'**
  String get hhSingle;

  /// No description provided for @hhExtended.
  ///
  /// In en, this message translates to:
  /// **'Extended family'**
  String get hhExtended;

  /// No description provided for @hhBlended.
  ///
  /// In en, this message translates to:
  /// **'Blended family'**
  String get hhBlended;

  /// No description provided for @hhPartners.
  ///
  /// In en, this message translates to:
  /// **'Partners, no kids'**
  String get hhPartners;

  /// No description provided for @hhSolo.
  ///
  /// In en, this message translates to:
  /// **'Just me for now'**
  String get hhSolo;

  /// No description provided for @hhOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get hhOther;

  /// No description provided for @joinCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get joinCodeLabel;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @setupInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite members'**
  String get setupInviteTitle;

  /// No description provided for @setupWorking.
  ///
  /// In en, this message translates to:
  /// **'Setting things up…'**
  String get setupWorking;

  /// No description provided for @noEnvelopesYet.
  ///
  /// In en, this message translates to:
  /// **'No budgets yet - create one from the Budgets tab to start planning your spending.'**
  String get noEnvelopesYet;

  /// No description provided for @noActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No activity yet. Tap + to record money coming in or spending.'**
  String get noActivityYet;

  /// No description provided for @setupBanner.
  ///
  /// In en, this message translates to:
  /// **'Finish setting up: create your family or join with a code'**
  String get setupBanner;

  /// No description provided for @setupBannerCta.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get setupBannerCta;

  /// No description provided for @deleteTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get deleteTypeHint;

  /// No description provided for @deletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get deletePermanently;

  /// No description provided for @errInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the invite code from the family owner - it looks like MHRI-4F2A.'**
  String get errInviteCode;

  /// No description provided for @errFamilyNameTaken.
  ///
  /// In en, this message translates to:
  /// **'That family name is already taken - try another name.'**
  String get errFamilyNameTaken;

  /// No description provided for @authErrEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox - tap the confirmation link first, then sign in.'**
  String get authErrEmailNotConfirmed;

  /// No description provided for @authErrBadCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is wrong.'**
  String get authErrBadCredentials;

  /// No description provided for @authErrAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists - sign in instead.'**
  String get authErrAlreadyRegistered;

  /// No description provided for @authErrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts - wait a minute and try again.'**
  String get authErrRateLimited;

  /// No description provided for @authErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection - check your internet and try again.'**
  String get authErrNetwork;

  /// No description provided for @authResend.
  ///
  /// In en, this message translates to:
  /// **'Resend confirmation email'**
  String get authResend;

  /// No description provided for @authResent.
  ///
  /// In en, this message translates to:
  /// **'Confirmation email sent - check your inbox.'**
  String get authResent;

  /// No description provided for @mukandoOn.
  ///
  /// In en, this message translates to:
  /// **'Savings circle (mukando)'**
  String get mukandoOn;

  /// No description provided for @mukandoEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Mukando - rotating savings'**
  String get mukandoEnableTitle;

  /// No description provided for @mukandoEnableSub.
  ///
  /// In en, this message translates to:
  /// **'Save in turns with your family. Off by default - turn it on if your circle does rounds.'**
  String get mukandoEnableSub;

  /// No description provided for @mukandoEnableCta.
  ///
  /// In en, this message translates to:
  /// **'Turn on mukando'**
  String get mukandoEnableCta;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Use photo'**
  String get addPhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @photoUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo…'**
  String get photoUploading;

  /// No description provided for @photoFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not upload the photo - check your connection and try again.'**
  String get photoFailed;

  /// No description provided for @photoSaved.
  ///
  /// In en, this message translates to:
  /// **'Photo saved - your family will see it too.'**
  String get photoSaved;

  /// No description provided for @newSavingsGoal.
  ///
  /// In en, this message translates to:
  /// **'New savings goal'**
  String get newSavingsGoal;

  /// No description provided for @createSavingsGoal.
  ///
  /// In en, this message translates to:
  /// **'Create savings goal'**
  String get createSavingsGoal;

  /// No description provided for @goalName.
  ///
  /// In en, this message translates to:
  /// **'Goal name'**
  String get goalName;

  /// No description provided for @goalNameHint.
  ///
  /// In en, this message translates to:
  /// **'Emergency fund'**
  String get goalNameHint;

  /// No description provided for @targetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get targetAmount;

  /// No description provided for @createGoal.
  ///
  /// In en, this message translates to:
  /// **'Create goal'**
  String get createGoal;

  /// No description provided for @goalNameAmountFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a goal name and a target greater than zero.'**
  String get goalNameAmountFirst;

  /// No description provided for @shoppingLogged.
  ///
  /// In en, this message translates to:
  /// **'No shopping to record'**
  String get shoppingLogged;

  /// No description provided for @loggedItem.
  ///
  /// In en, this message translates to:
  /// **'Logged'**
  String get loggedItem;

  /// No description provided for @syncDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync & data'**
  String get syncDataTitle;

  /// No description provided for @syncStateSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncStateSyncing;

  /// No description provided for @syncStateError.
  ///
  /// In en, this message translates to:
  /// **'Waiting to retry'**
  String get syncStateError;

  /// No description provided for @syncStateOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline - changes save on this phone'**
  String get syncStateOffline;

  /// No description provided for @syncStateNeedsSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync'**
  String get syncStateNeedsSignIn;

  /// No description provided for @syncStateSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone'**
  String get syncStateSaved;

  /// No description provided for @syncNowBtn.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNowBtn;

  /// No description provided for @syncLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get syncLastSync;

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get syncNever;

  /// No description provided for @syncPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get syncPendingLabel;

  /// No description provided for @syncUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Everything is saved and up to date'**
  String get syncUpToDate;

  /// No description provided for @syncErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Last issue'**
  String get syncErrorLabel;

  /// No description provided for @syncWhereTitle.
  ///
  /// In en, this message translates to:
  /// **'Where your data lives'**
  String get syncWhereTitle;

  /// No description provided for @syncConnectedTo.
  ///
  /// In en, this message translates to:
  /// **'Family cloud:'**
  String get syncConnectedTo;

  /// No description provided for @syncNotConnected.
  ///
  /// In en, this message translates to:
  /// **'This device only - no family cloud connected yet.'**
  String get syncNotConnected;

  /// No description provided for @syncBackupNote.
  ///
  /// In en, this message translates to:
  /// **'There is no separate backup to switch on. Every change is saved on this phone the moment you make it and syncs to the family cloud whenever you have data. Export a CSV below anytime for a copy you keep.'**
  String get syncBackupNote;

  /// No description provided for @previewBanner.
  ///
  /// In en, this message translates to:
  /// **'Previewing as {name}'**
  String previewBanner(Object name);

  /// No description provided for @previewExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get previewExit;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get resetTitle;

  /// No description provided for @resetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You are signed in from the reset link - now pick a new password.'**
  String get resetSubtitle;

  /// No description provided for @resetNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetNewLabel;

  /// No description provided for @resetConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get resetConfirmLabel;

  /// No description provided for @resetMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passwords do not match'**
  String get resetMismatch;

  /// No description provided for @resetRuleLength.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get resetRuleLength;

  /// No description provided for @resetRuleMix.
  ///
  /// In en, this message translates to:
  /// **'Has a letter and a number'**
  String get resetRuleMix;

  /// No description provided for @resetRuleHint.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters, with a letter and a number.'**
  String get resetRuleHint;

  /// No description provided for @resetCta.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get resetCta;

  /// No description provided for @resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed - sign in with your new password'**
  String get resetSuccess;

  /// No description provided for @resetShow.
  ///
  /// In en, this message translates to:
  /// **'Show or hide password'**
  String get resetShow;

  /// No description provided for @resetExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'This link has expired'**
  String get resetExpiredTitle;

  /// No description provided for @resetExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'Reset links work once and only for a short time. Send a fresh one and try again.'**
  String get resetExpiredBody;

  /// No description provided for @resetSendNew.
  ///
  /// In en, this message translates to:
  /// **'Send a new reset link'**
  String get resetSendNew;

  /// No description provided for @listDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete item'**
  String get listDelete;

  /// No description provided for @listDeleted.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" removed from the list'**
  String listDeleted(Object name);

  /// No description provided for @memberAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create member account'**
  String get memberAccountTitle;

  /// No description provided for @memberAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up an account for someone who should join this family immediately.'**
  String get memberAccountSubtitle;

  /// No description provided for @memberAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Create account for member'**
  String get memberAccountAction;

  /// No description provided for @memberAccountSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'They can sign in immediately without using an invite code.'**
  String get memberAccountSheetSubtitle;

  /// No description provided for @memberAccountName.
  ///
  /// In en, this message translates to:
  /// **'Preferred name'**
  String get memberAccountName;

  /// No description provided for @memberAccountEmail.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get memberAccountEmail;

  /// No description provided for @memberAccountTemporaryPassword.
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get memberAccountTemporaryPassword;

  /// No description provided for @memberAccountPasswordRule.
  ///
  /// In en, this message translates to:
  /// **'At least 10 characters, with a letter and a number'**
  String get memberAccountPasswordRule;

  /// No description provided for @memberAccountRole.
  ///
  /// In en, this message translates to:
  /// **'Family role'**
  String get memberAccountRole;

  /// No description provided for @memberAccountSecurityNote.
  ///
  /// In en, this message translates to:
  /// **'Share the temporary password privately. Ask them to use Forgot password to choose their own password after signing in.'**
  String get memberAccountSecurityNote;

  /// No description provided for @memberAccountCreate.
  ///
  /// In en, this message translates to:
  /// **'Create member account'**
  String get memberAccountCreate;

  /// No description provided for @memberAccountCreated.
  ///
  /// In en, this message translates to:
  /// **'Member account created and added to your family.'**
  String get memberAccountCreated;

  /// No description provided for @memberAccountBadName.
  ///
  /// In en, this message translates to:
  /// **'Enter their preferred name.'**
  String get memberAccountBadName;

  /// No description provided for @memberAccountEmailExists.
  ///
  /// In en, this message translates to:
  /// **'That email already has an account. Use the regular invite flow instead.'**
  String get memberAccountEmailExists;

  /// No description provided for @memberAccountOwnerRole.
  ///
  /// In en, this message translates to:
  /// **'Only the family owner can create another parent or adult account.'**
  String get memberAccountOwnerRole;

  /// No description provided for @memberAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the member account. Check your connection and try again.'**
  String get memberAccountFailed;

  /// No description provided for @inviteNew.
  ///
  /// In en, this message translates to:
  /// **'New invite'**
  String get inviteNew;

  /// No description provided for @inviteEmailOptional.
  ///
  /// In en, this message translates to:
  /// **'Their email (optional - only they can use it)'**
  String get inviteEmailOptional;

  /// No description provided for @inviteCreate.
  ///
  /// In en, this message translates to:
  /// **'Create invite'**
  String get inviteCreate;

  /// No description provided for @inviteCreated.
  ///
  /// In en, this message translates to:
  /// **'Show this code or QR to them'**
  String get inviteCreated;

  /// No description provided for @inviteScanHint.
  ///
  /// In en, this message translates to:
  /// **'They scan the QR with their camera, or tap the link - it opens this app ready to join.'**
  String get inviteScanHint;

  /// No description provided for @inviteShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get inviteShare;

  /// No description provided for @inviteShareText.
  ///
  /// In en, this message translates to:
  /// **'Join our family on Mhuri - your invite:'**
  String get inviteShareText;

  /// No description provided for @invitePending.
  ///
  /// In en, this message translates to:
  /// **'Open invites'**
  String get invitePending;

  /// No description provided for @inviteNone.
  ///
  /// In en, this message translates to:
  /// **'No open invites.'**
  String get inviteNone;

  /// No description provided for @inviteHistory.
  ///
  /// In en, this message translates to:
  /// **'Earlier invites'**
  String get inviteHistory;

  /// No description provided for @inviteAcceptedLabel.
  ///
  /// In en, this message translates to:
  /// **'{code} - joined ({role})'**
  String inviteAcceptedLabel(Object code, Object role);

  /// No description provided for @inviteRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get inviteRevoke;

  /// No description provided for @inviteRevokeBody.
  ///
  /// In en, this message translates to:
  /// **'Revoke invite {code}? They will not be able to join with it.'**
  String inviteRevokeBody(Object code);

  /// No description provided for @inviteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the invite - check your connection and try again.'**
  String get inviteFailed;

  /// No description provided for @inviteTooMany.
  ///
  /// In en, this message translates to:
  /// **'There are already 5 open invites - revoke one first.'**
  String get inviteTooMany;

  /// No description provided for @inviteOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the family owner manages invites.'**
  String get inviteOwnerOnly;

  /// No description provided for @inviteLinkReady.
  ///
  /// In en, this message translates to:
  /// **'Invite {code} is waiting - join the family below.'**
  String inviteLinkReady(Object code);

  /// No description provided for @inviteAlreadyInFamily.
  ///
  /// In en, this message translates to:
  /// **'You are already in a family - invites are for joining a new one.'**
  String get inviteAlreadyInFamily;

  /// No description provided for @makeOwner.
  ///
  /// In en, this message translates to:
  /// **'Make owner'**
  String get makeOwner;

  /// No description provided for @makeOwnerBody.
  ///
  /// In en, this message translates to:
  /// **'Make {name} the family owner? You become a regular adult member and they manage invites and settings.'**
  String makeOwnerBody(Object name);

  /// No description provided for @makeOwnerDone.
  ///
  /// In en, this message translates to:
  /// **'{name} is now the family owner'**
  String makeOwnerDone(Object name);

  /// No description provided for @makeOwnerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not transfer ownership - check your connection and try again.'**
  String get makeOwnerFailed;

  /// No description provided for @roleParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get roleParent;

  /// No description provided for @roleChild.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get roleChild;

  /// No description provided for @syncProblemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Changes that need you'**
  String get syncProblemsTitle;

  /// No description provided for @syncProblemsBody.
  ///
  /// In en, this message translates to:
  /// **'These changes could not reach the family cloud after several tries. Retry them, or discard them - nothing is removed without your say-so.'**
  String get syncProblemsBody;

  /// No description provided for @syncRetryThis.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get syncRetryThis;

  /// No description provided for @syncDiscardThis.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get syncDiscardThis;

  /// No description provided for @syncDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this change?'**
  String get syncDiscardTitle;

  /// No description provided for @syncDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'“{what}” stays only on this phone and will never reach the family cloud. Discard it?'**
  String syncDiscardBody(Object what);

  /// No description provided for @syncTries.
  ///
  /// In en, this message translates to:
  /// **'{tries} tries so far'**
  String syncTries(Object tries);

  /// No description provided for @syncKindTx.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get syncKindTx;

  /// No description provided for @syncKindEnvelope.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get syncKindEnvelope;

  /// No description provided for @syncKindGoal.
  ///
  /// In en, this message translates to:
  /// **'Savings goal'**
  String get syncKindGoal;

  /// No description provided for @syncKindItem.
  ///
  /// In en, this message translates to:
  /// **'List item'**
  String get syncKindItem;

  /// No description provided for @syncKindRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get syncKindRequest;

  /// No description provided for @syncKindOther.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get syncKindOther;

  /// No description provided for @setupInviteCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite copied.'**
  String get setupInviteCopied;

  /// No description provided for @setupBadEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get setupBadEmail;

  /// No description provided for @setupInviteText.
  ///
  /// In en, this message translates to:
  /// **'Join {family} on Mhuri with invite code {code}. Suggested role: {role}.'**
  String setupInviteText(Object family, Object code, Object role);

  /// No description provided for @setupInviteSubject.
  ///
  /// In en, this message translates to:
  /// **'Join {family} on Mhuri'**
  String setupInviteSubject(Object family);

  /// No description provided for @setupTagline.
  ///
  /// In en, this message translates to:
  /// **'One family. One plan.'**
  String get setupTagline;

  /// No description provided for @setupPhotoOptional.
  ///
  /// In en, this message translates to:
  /// **'Add profile photo (optional)'**
  String get setupPhotoOptional;

  /// No description provided for @setupHaveCode.
  ///
  /// In en, this message translates to:
  /// **'I have an invite code'**
  String get setupHaveCode;

  /// No description provided for @setupCreateInstead.
  ///
  /// In en, this message translates to:
  /// **'Create a family instead'**
  String get setupCreateInstead;

  /// No description provided for @setupCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get setupCopy;

  /// No description provided for @setupScanToJoin.
  ///
  /// In en, this message translates to:
  /// **'Scan to join'**
  String get setupScanToJoin;

  /// No description provided for @setupCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your family'**
  String get setupCreateTitle;

  /// No description provided for @setupCreateSub.
  ///
  /// In en, this message translates to:
  /// **'Tell us what your family calls you.'**
  String get setupCreateSub;

  /// No description provided for @setupPreferredName.
  ///
  /// In en, this message translates to:
  /// **'Preferred name'**
  String get setupPreferredName;

  /// No description provided for @setupFamilyNameField.
  ///
  /// In en, this message translates to:
  /// **'Family name (for example, The Moyos)'**
  String get setupFamilyNameField;

  /// No description provided for @setupCurrency.
  ///
  /// In en, this message translates to:
  /// **'Primary currency'**
  String get setupCurrency;

  /// No description provided for @setupJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join your family'**
  String get setupJoinTitle;

  /// No description provided for @setupJoinSub.
  ///
  /// In en, this message translates to:
  /// **'Use the code shared by a family member.'**
  String get setupJoinSub;

  /// No description provided for @setupInviteSub.
  ///
  /// In en, this message translates to:
  /// **'Bring everyone into the same family space.'**
  String get setupInviteSub;

  /// No description provided for @setupRoleSuggestion.
  ///
  /// In en, this message translates to:
  /// **'The role is included as a suggestion. Confirm it in Family settings after they join.'**
  String get setupRoleSuggestion;

  /// No description provided for @setupSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get setupSendInvite;

  /// No description provided for @setupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue  →'**
  String get setupContinue;

  /// No description provided for @setupInviteLater.
  ///
  /// In en, this message translates to:
  /// **'Invite later'**
  String get setupInviteLater;

  /// No description provided for @setupPermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Set permissions'**
  String get setupPermsTitle;

  /// No description provided for @setupPermsSub.
  ///
  /// In en, this message translates to:
  /// **'Recommended access is ready. You can change it later in Family settings.'**
  String get setupPermsSub;

  /// No description provided for @setupPermWallet.
  ///
  /// In en, this message translates to:
  /// **'View own wallet'**
  String get setupPermWallet;

  /// No description provided for @setupPermTx.
  ///
  /// In en, this message translates to:
  /// **'Log transactions'**
  String get setupPermTx;

  /// No description provided for @setupPermBudget.
  ///
  /// In en, this message translates to:
  /// **'View family budget'**
  String get setupPermBudget;

  /// No description provided for @setupFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get setupFinish;

  /// No description provided for @setupStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {n} of 3'**
  String setupStepOf(Object n);

  /// No description provided for @deleteWhatTitle.
  ///
  /// In en, this message translates to:
  /// **'What happens when you delete'**
  String get deleteWhatTitle;

  /// No description provided for @deleteWhatOwner.
  ///
  /// In en, this message translates to:
  /// **'You are the family owner: the whole family space is deleted - every account, budget, transaction and list, for everyone. This cannot be undone.'**
  String get deleteWhatOwner;

  /// No description provided for @deleteWhatMember.
  ///
  /// In en, this message translates to:
  /// **'You leave the family. Your membership ends, your photo and email are removed, and your past transactions remain but show as “Former member”. Everyone else keeps their data.'**
  String get deleteWhatMember;

  /// No description provided for @deleteWhatSessions.
  ///
  /// In en, this message translates to:
  /// **'Every sign-in on every device is signed out.'**
  String get deleteWhatSessions;

  /// No description provided for @deleteStepLeave.
  ///
  /// In en, this message translates to:
  /// **'Leaving the family…'**
  String get deleteStepLeave;

  /// No description provided for @deleteStepAnonymize.
  ///
  /// In en, this message translates to:
  /// **'Removing your personal details…'**
  String get deleteStepAnonymize;

  /// No description provided for @deleteStepSessions.
  ///
  /// In en, this message translates to:
  /// **'Revoking sign-ins…'**
  String get deleteStepSessions;

  /// No description provided for @deleteStepIdentity.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account…'**
  String get deleteStepIdentity;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesBody.
  ///
  /// In en, this message translates to:
  /// **'You have not saved yet. Leave anyway?'**
  String get discardChangesBody;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get stay;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @btnCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get btnCreate;

  /// No description provided for @btnJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get btnJoin;

  /// No description provided for @hintFamilyExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. The Taylor Family'**
  String get hintFamilyExample;

  /// No description provided for @transferFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get transferFrom;

  /// No description provided for @transferTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get transferTo;

  /// No description provided for @transferWhy.
  ///
  /// In en, this message translates to:
  /// **'Why?'**
  String get transferWhy;

  /// No description provided for @listNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get listNameLabel;

  /// No description provided for @listQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get listQtyLabel;

  /// No description provided for @kidsPinHint.
  ///
  /// In en, this message translates to:
  /// **'New PIN (4–6 digits)'**
  String get kidsPinHint;

  /// No description provided for @kidsPinUpdated.
  ///
  /// In en, this message translates to:
  /// **'Kids Mode PIN updated ✓'**
  String get kidsPinUpdated;

  /// No description provided for @setupEnterBoth.
  ///
  /// In en, this message translates to:
  /// **'Enter your preferred name and family name.'**
  String get setupEnterBoth;

  /// No description provided for @setupNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'A connection is required to create your family.'**
  String get setupNeedsConnection;

  /// No description provided for @setupNameTaken.
  ///
  /// In en, this message translates to:
  /// **'That family name is already taken. Try another.'**
  String get setupNameTaken;

  /// No description provided for @setupEnterJoin.
  ///
  /// In en, this message translates to:
  /// **'Enter your preferred name and invite code.'**
  String get setupEnterJoin;

  /// No description provided for @avatarError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update that photo. Try another one.'**
  String get avatarError;

  /// No description provided for @invitesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load invites. Pull to refresh.'**
  String get invitesLoadFailed;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All ({n})'**
  String filterAll(Object n);

  /// No description provided for @envLabel.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get envLabel;

  /// No description provided for @syncStateNeedsSetup.
  ///
  /// In en, this message translates to:
  /// **'Set up your family to sync'**
  String get syncStateNeedsSetup;

  /// No description provided for @tourTitle.
  ///
  /// In en, this message translates to:
  /// **'A quick tour'**
  String get tourTitle;

  /// No description provided for @tourPoolTitle.
  ///
  /// In en, this message translates to:
  /// **'Know what is available'**
  String get tourPoolTitle;

  /// No description provided for @tourPoolBody.
  ///
  /// In en, this message translates to:
  /// **'Home shows your family pool, recent activity and the budgets that need attention.'**
  String get tourPoolBody;

  /// No description provided for @tourPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Give every dollar a job'**
  String get tourPlanTitle;

  /// No description provided for @tourPlanBody.
  ///
  /// In en, this message translates to:
  /// **'Use Budgets to plan spending, Savings for goals, and Shopping for the shared family list.'**
  String get tourPlanBody;

  /// No description provided for @tourAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add money in seconds'**
  String get tourAddTitle;

  /// No description provided for @tourAddBody.
  ///
  /// In en, this message translates to:
  /// **'Start here. Add money you\'ve spent or received.'**
  String get tourAddBody;

  /// No description provided for @reminderBills.
  ///
  /// In en, this message translates to:
  /// **'Bills due (3 days before)'**
  String get reminderBills;

  /// No description provided for @reminderBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget running low'**
  String get reminderBudget;

  /// No description provided for @reminderKids.
  ///
  /// In en, this message translates to:
  /// **'Kids: requests & chore approvals'**
  String get reminderKids;

  /// No description provided for @reminderCircle.
  ///
  /// In en, this message translates to:
  /// **'Savings group reminder (Sunday)'**
  String get reminderCircle;

  /// No description provided for @reminderGoals.
  ///
  /// In en, this message translates to:
  /// **'Goal milestones'**
  String get reminderGoals;

  /// No description provided for @reminderMeeting.
  ///
  /// In en, this message translates to:
  /// **'Family meeting day'**
  String get reminderMeeting;

  /// No description provided for @reminderDigest.
  ///
  /// In en, this message translates to:
  /// **'Weekly digest (Sunday 6pm)'**
  String get reminderDigest;

  /// No description provided for @notificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are disabled for Mhuri. Enable them in your device settings.'**
  String get notificationsDenied;

  /// No description provided for @testNotificationSent.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent.'**
  String get testNotificationSent;

  /// No description provided for @testNotificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the test notification.'**
  String get testNotificationFailed;
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
