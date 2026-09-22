// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabHome => 'Home';

  @override
  String get tabBudgets => 'Budgets';

  @override
  String get tabSavings => 'Savings';

  @override
  String get tabLists => 'Lists';

  @override
  String get tabFamily => 'Family';

  @override
  String get tabActivity => 'Activity';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get familyPool => 'Family Pool';

  @override
  String safeToSpend(String amount) {
    return 'Safe to spend today: $amount';
  }

  @override
  String get seeAll => 'See all';

  @override
  String get add => 'Add';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get undo => 'Undo';

  @override
  String get post => 'Post';

  @override
  String get skip => 'Skip';

  @override
  String get approve => 'Approve';

  @override
  String get notThisWeek => 'Not this week';

  @override
  String get done => 'Done';

  @override
  String get export => 'Export';

  @override
  String get meeting => 'Meeting';

  @override
  String get newEnvelope => 'New envelope';

  @override
  String get recurringExpenses => 'Recurring expenses';

  @override
  String get shopping => 'Shopping';

  @override
  String get activityTitle => 'Activity';

  @override
  String get noActivityTitle => 'No activity yet';

  @override
  String get noActivityHint =>
      'Every expense, income and approval shows up here — add your first one with the + button.';

  @override
  String get noGoals => 'No goals yet';

  @override
  String get noGoalsHint =>
      'Start with an emergency fund — even a little each week changes how emergencies feel.';

  @override
  String get reportTitle => 'Report card';

  @override
  String get income => 'Income';

  @override
  String get spent => 'Spent';

  @override
  String get saved => 'Saved';

  @override
  String get safePerDay => 'Safe / day';

  @override
  String get envelopeHealth => 'Envelope health';

  @override
  String get cashLeak => 'Cash leak';

  @override
  String get shareReport => 'Share to family group';

  @override
  String get meetingCta => 'Start the family meeting';

  @override
  String get exportCsv => 'Export transactions (CSV)';

  @override
  String get family => 'Family';

  @override
  String get hi => 'Hi';

  @override
  String get mySavings => 'My savings';

  @override
  String get addToJar => 'Add to jar';

  @override
  String get savingsMatch => 'Savings match';

  @override
  String get savingsMatchNote => 'Parents match 50% of everything you save';

  @override
  String get earnings => 'Earnings';

  @override
  String get logEarning => 'Log earning';

  @override
  String get myProposals => 'My proposals';

  @override
  String get proposeExpense => 'Propose expense';

  @override
  String get proposeTitle => 'Propose an expense';

  @override
  String get peek => 'Parents let you see this envelope';

  @override
  String get plan => 'Spend · Save · Give plan';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get remindersOnDevice => 'Reminders on this device';

  @override
  String get remindersSubtitle =>
      'Bills, budgets, kids, goals, savings circles & meetings';

  @override
  String get quietHours => 'Quiet hours (no notifications inside this window)';

  @override
  String get monthStartsOn => 'Month starts on';

  @override
  String get language => 'Language';

  @override
  String get largeText => 'Large text (easier to read)';

  @override
  String get exportCsvSettings => 'Export transactions (CSV)';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String scheduledOn(String from, String to) {
    return 'Scheduled on this device · quiet hours $from–$to';
  }

  @override
  String get remindersOff => 'Reminders are off';

  @override
  String get nothingComing => 'Nothing coming up';

  @override
  String get ob1Title => 'Money, managed together';

  @override
  String get ob1Body =>
      'One calm place for everything your family earns, spends, saves and plans — in every currency you use, online or off.';

  @override
  String get ob2Title => 'Envelopes, not guilt';

  @override
  String get ob2Body =>
      'Give every dollar a job. Groceries, school fees, transport — see at a glance what is on track, what needs a top-up, and what is safe to spend today.';

  @override
  String get ob3Title => 'Built for the whole family';

  @override
  String get ob3Body =>
      'Partners share the plan. Kids grow jars and stars safely. Teens propose expenses and learn with savings matches. Grandparents keep the savings-circle record.';

  @override
  String get ob4Title => 'Gentle reminders';

  @override
  String syncPill(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes saved on this device — syncs when online',
      one: '1 change saved on this device — syncs when online',
    );
    return '$_temp0';
  }

  @override
  String get hideAmountsTip => 'Hide amounts';

  @override
  String get showAmountsTip => 'Show amounts';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get sixMonthNet => 'Six-month net (USD)';

  @override
  String get donutEmpty =>
      'No spending recorded yet this cycle — the donut fills as you add expenses.';

  @override
  String get ob4Body =>
      'Bill nags, budget watch and the weekly family digest — quiet hours respected, everything on your phone. You are in charge.';

  @override
  String get next => 'Next';

  @override
  String get loginWelcome => 'Welcome to Mhuri Hub';

  @override
  String get loginEnterCode => 'Enter the code';

  @override
  String loginSentCode(String phone) {
    return 'We sent a code by SMS to $phone';
  }

  @override
  String get loginSignInHint =>
      'Sign in with your email to open your family space.';

  @override
  String get loginSendCode => 'Send code';

  @override
  String get loginVerify => 'Verify & sign in';

  @override
  String get loginChangeNumber => 'Change number';

  @override
  String get loginBadPhone =>
      'Enter a valid phone number (e.g. +44 7700 900123).';

  @override
  String get quickAddTitle => 'Quick add';

  @override
  String get expense => 'Expense';

  @override
  String get envelopeLabel => 'Envelope';

  @override
  String get whoLabel => 'Who';

  @override
  String get paidWithLabel => 'Paid with';

  @override
  String get noteHint => 'Note (e.g. FreshMart)';

  @override
  String get enterAmountFirst => 'Enter an amount first';

  @override
  String get savedOffline => 'Saved ✓ — works offline, syncs when online';

  @override
  String kidsHi(String name) {
    return 'Hi $name!';
  }

  @override
  String get kidsMyJar => 'My Jar';

  @override
  String kidsGoalSaved(String goal, int pct) {
    return 'Goal: $goal — $pct% saved';
  }

  @override
  String get kidsMyChores => 'My Chores';

  @override
  String get kidsWishList => 'Wish List';

  @override
  String kidsWishItem(String amount) {
    return 'Soccer ball — US\$25 · saved $amount';
  }

  @override
  String get kidsAskMoney => 'Ask Mom/Dad\nfor money';

  @override
  String get kidsDoChore => 'Do a chore';

  @override
  String get kidsAllDone => 'All chores done!';

  @override
  String get kidsParents => 'Parents';

  @override
  String get kidsAskTitle => 'Ask Mom & Dad';

  @override
  String get kidsWhatFor => 'What for?';

  @override
  String get kidsDefaultReason => 'Pocket money';

  @override
  String get teenZoneTitle => 'Teen Zone · 13–17';

  @override
  String get teenNoEarnings => 'No earnings logged yet';

  @override
  String get teenEarnHint =>
      'Wash a car, help at the corner shop — log it and watch your jar grow.';

  @override
  String get teenSpend => 'Spend 50%';

  @override
  String get teenSave => 'Save 40%';

  @override
  String get teenGive => 'Give 10%';

  @override
  String teenSplitHint(String amount) {
    return 'Suggested split of $amount earned this month';
  }

  @override
  String get teenSavedJar => 'Saved to your jar — parents match 50%';

  @override
  String get teenWhatDid => 'What did you do?';

  @override
  String get familyTitle => 'Family';

  @override
  String get membersDesc => 'Couple + kids · month starts on the 1st';

  @override
  String get membersInviteHint =>
      'Share the code or scan to invite a family member';

  @override
  String get setCurrency => 'Currency & rates';

  @override
  String setCurrencySub(String rate) {
    return 'USD primary · ZiG secondary · $rate';
  }

  @override
  String get setPrivacy => 'Privacy';

  @override
  String get setPrivacySub => 'Private pockets: off — partner sees shared only';

  @override
  String get setMonthStart => 'Month start day';

  @override
  String get setMonthStartSub => '1st — aligns with salary cycle';

  @override
  String get setNotif => 'Notifications';

  @override
  String get setNotifSub => 'Budget 80% warning · bills · kid requests';

  @override
  String get setBackup => 'Backup & export';

  @override
  String get setBackupSub => 'Encrypted cloud backup · CSV export (owner)';

  @override
  String get meetingTitle => 'Family meeting';

  @override
  String get mFigures => 'Last month, in numbers';

  @override
  String get figureIncome => 'Income';

  @override
  String get figureSpent => 'Spent';

  @override
  String get figureSaved => 'Saved';

  @override
  String get mEnvelopeHealth => 'Envelope health';

  @override
  String get mReachedTalk =>
      'Talk about the envelopes marked \"Reached\". Top them up together — calmly.';

  @override
  String get mGoals => 'Savings goals';

  @override
  String get mChores => 'Chores, jars & requests';

  @override
  String get mImprove => 'One thing to improve';

  @override
  String recSkipped(String date) {
    return 'Skipped — next: $date';
  }

  @override
  String get recNew => 'New recurring expense';

  @override
  String get recReview =>
      'Nothing is charged automatically — you review and post everything.';

  @override
  String get recNoEnvelope => 'No envelope';

  @override
  String get recNextDue => 'Next due:';

  @override
  String get recNameAmount => 'Give it a name and an amount';

  @override
  String get recSaveRule => 'Save rule';

  @override
  String get recNameHint => 'Name (e.g. School fees levy)';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleAdult => 'Adult';

  @override
  String get roleTeen => 'Teen';

  @override
  String get roleKid => 'Kid';

  @override
  String get roleViewer => 'Elder · Viewer';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodMobile => 'Mobile money';

  @override
  String get methodCard => 'Bank card';

  @override
  String get methodTransfer => 'Bank transfer';

  @override
  String get methodAgent => 'Agent / cash point';

  @override
  String get methodOther => 'Other';

  @override
  String get stateToBuy => 'To buy';

  @override
  String get stateInCart => 'In cart';

  @override
  String get stateDone => 'Done';

  @override
  String get freqWeekly => 'Weekly';

  @override
  String get freqMonthly => 'Monthly';

  @override
  String get rollReset => 'Reset each month';

  @override
  String get rollRoll => 'Roll over what is left';

  @override
  String get rollAccum => 'Keep accumulating';

  @override
  String get freqTerm => 'Per term (~3 months)';

  @override
  String get budgetsTitle => 'Budgets';

  @override
  String get noEnvelopes => 'No envelopes yet';

  @override
  String get envelopesHint =>
      'Envelopes are budgets you can see: Groceries, School fees, Transport. Create your first one below.';

  @override
  String get newEnvStub => 'New envelope — coming in Phase 1';

  @override
  String get addRecurringTip => 'Add recurring expense';

  @override
  String get recReviewed =>
      'Reviewed before posting — nothing is charged silently.';

  @override
  String get noRecurring => 'No recurring expenses yet';

  @override
  String get recurringHint =>
      'Add school fees, rent or airtime rules — we remind you when each one comes due.';

  @override
  String get chipOnTrack => 'On track';

  @override
  String get chipReached => 'Reached';

  @override
  String get remaining => 'Remaining';

  @override
  String get moveMoney => 'Move money';

  @override
  String get pickFirst => 'Pick envelopes and an amount first';

  @override
  String get skipPeriod => 'Skip this period';

  @override
  String get pauseRule => 'Pause rule';

  @override
  String get resumeRule => 'Resume rule';

  @override
  String get meetingHint => '15 minutes, once a month.';

  @override
  String mChoresLine(Object proposals, Object requests, Object stars) {
    return '$stars stars earned · $requests request(s) waiting · $proposals teen proposal(s) waiting.';
  }

  @override
  String get meetingNoteHint =>
      'e.g. \"Cook more on Sundays — musika spending is creeping.\"';

  @override
  String get meetingSaveNote => 'Save our note';

  @override
  String get savedTick => 'Saved ✓';

  @override
  String get meetingDone => 'Done — see you next month';

  @override
  String get reportCard => 'Report card';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get swapCurrency => 'Swap display currency';

  @override
  String get yourChild => 'Your child';

  @override
  String get review => 'Review';

  @override
  String get confirm => 'Confirm';

  @override
  String get markCollected => 'Mark collected';

  @override
  String get decline => 'Decline';

  @override
  String get sentToParents => 'Sent to Mom & Dad';

  @override
  String get sendRequest => 'Send request';

  @override
  String get parentsOnly => 'Parents only';

  @override
  String get pinExitLine => 'Enter your PIN to leave Kids Mode.';

  @override
  String get wrongPin => 'Wrong PIN';

  @override
  String get unlock => 'Unlock';

  @override
  String get addItem => 'Add item';

  @override
  String get listSharedSub => 'Family shopping list · shared with everyone';

  @override
  String get tickFirst => 'Tick items off first';

  @override
  String get namePriceFirst => 'Give the item a name and price';

  @override
  String get addToList => 'Add to list';

  @override
  String get spaceSetup => 'Set up your family space';

  @override
  String get spaceSetupSub =>
      'Create a space for your family, or join the one your partner created with their invite code. Everything you log then syncs between your phones.';

  @override
  String get createSpace => 'Create space';

  @override
  String get joinWithCode => 'Join with code';

  @override
  String get offlineRetry => 'Offline — will retry automatically';

  @override
  String get syncProblem => 'Sync problem';

  @override
  String get signinExpired => 'Sign-in expired — sign out and back in';

  @override
  String get syncing => 'Syncing…';

  @override
  String lastSync(Object last) {
    return 'Last sync: $last';
  }

  @override
  String get familySpace => 'Family space';

  @override
  String get syncNow => 'Sync now';

  @override
  String get createFamilySpace => 'Create family space';

  @override
  String get familyName => 'Family name';

  @override
  String get localizedNote =>
      'The whole app now speaks six languages — no more EN-only screens.';

  @override
  String get nextCreateSpace =>
      'Next: create your family space (or join with a code) from the Family tab.';

  @override
  String reachedMove(Object on, Object total) {
    return '$on of $total envelopes still on track. Open the ones marked \"Reached\" and move money in — calm, not perfect.';
  }

  @override
  String get cashTrace =>
      'Cash is easy to spend and hard to trace. Paying a bit more by mobile money or bank card keeps the picture clearer.';

  @override
  String get whereMoneyWent => 'Where the money went';

  @override
  String get exportFailed => 'Export failed on this device';

  @override
  String csvSaved(Object path) {
    return 'CSV saved: $path';
  }

  @override
  String exportedPath(Object path) {
    return 'Exported ✓ $path';
  }

  @override
  String get bringToMeeting => 'Bring this to the monthly Family Meeting';

  @override
  String get savingsTitle => 'Savings';

  @override
  String get markRound => 'Mark this round collected';

  @override
  String get recordsOnly => 'Mhuri Hub never holds the money — records only.';

  @override
  String get saveContribution => 'Save contribution';

  @override
  String get sendTest => 'Send a test notification';

  @override
  String get testOk => 'Reminders are working on this device.';

  @override
  String get monthCycle => 'Month cycle';

  @override
  String get paydayAlign =>
      'Payday-aligned budgets — cycles reset on this day, and the family meeting reminder lands the evening before';

  @override
  String get backupComing => 'Backup & restore (coming)';

  @override
  String get fromLabel => 'From';

  @override
  String get addTransaction => 'Add transaction';

  @override
  String get logWhatAmount => 'Add what you did and the amount';

  @override
  String get logIt => 'Log it';

  @override
  String get fromEnvelope => 'From envelope';

  @override
  String get amountPurposeFirst => 'Add an amount and what it is for';

  @override
  String get sentApproval => 'Sent to Mom & Dad for approval';

  @override
  String get sendProposal => 'Send proposal';

  @override
  String get stWaiting => 'Waiting ⏳';

  @override
  String get stApproved => 'Approved ✓';

  @override
  String get stDeclined => 'Declined';

  @override
  String requestTitle(Object amount, Object name) {
    return '$name requested $amount';
  }

  @override
  String proposalTitle(Object amount, Object name) {
    return '$name proposes $amount';
  }

  @override
  String proposalSub(Object env, Object reason) {
    return '$reason · from $env';
  }

  @override
  String recDueSub(Object when) {
    return 'Recurring · comes due $when · post it when you pay it';
  }

  @override
  String get dueNow => 'now';

  @override
  String get dueSoon => 'soon';

  @override
  String choreDoneTitle(Object name) {
    return '\"$name\" done — confirm?';
  }

  @override
  String choreDoneSub(Object stars) {
    return '$stars stars — confirm to grow the jar';
  }

  @override
  String circleSub(Object amount, Object pot, Object who) {
    return '$who to collect $amount · pot $pot so far';
  }

  @override
  String get exportReal => 'Export works on a real device';

  @override
  String get allSynced => '✓ All changes synced';

  @override
  String get familyCta => 'Family ›';

  @override
  String get recentInEnv => 'Recent in this envelope';

  @override
  String get nothingLogged => 'Nothing logged here yet.';

  @override
  String dueBy(Object days) {
    return 'overdue by ${days}d';
  }

  @override
  String get dueToday => 'due today';

  @override
  String get dueTomorrow => 'due tomorrow';

  @override
  String dueIn(Object days) {
    return 'due in ${days}d';
  }

  @override
  String circleTitle(Object round, Object total) {
    return 'Savings circle — Round $round of $total';
  }

  @override
  String postedSnack(Object name) {
    return '$name posted ✓ — envelope updated';
  }

  @override
  String starsGiven(Object stars) {
    return '$stars stars given to the kids!';
  }

  @override
  String approvedReq(Object amount, Object name) {
    return 'Approved ✓ — $amount added to $name';
  }

  @override
  String declineBody(Object env, Object reason) {
    return '$reason\n\nFrom envelope: $env';
  }

  @override
  String approvedProp(Object amount, Object env) {
    return 'Approved ✓ — $amount logged to $env';
  }

  @override
  String sentKid(Object name) {
    return '\"$name\" sent to Mom & Dad';
  }

  @override
  String get listEmptyAdd => 'Nothing here — add an item with ＋';

  @override
  String usesPct(Object name, Object pct) {
    return 'Uses $pct% of the $name';
  }

  @override
  String loggedTo(Object amount, Object name) {
    return 'Logged $amount to $name ✓ — envelope updated';
  }

  @override
  String get finishShop => 'Finish shopping → log expense';

  @override
  String estPrice(Object symbol) {
    return 'Est. unit price ($symbol)';
  }

  @override
  String get myFamily => 'My family';

  @override
  String spaceCreated(Object code) {
    return 'Family space created ✓ Invite code: $code';
  }

  @override
  String get createFail => 'Could not create the space — try again';

  @override
  String get joinSpaceTitle => 'Join a family space';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get joinedOk => 'Joined ✓ — your family data is syncing';

  @override
  String get joinFail => 'Could not join — try again';

  @override
  String get kidsPin => 'Kids Mode exit PIN';

  @override
  String get kidsPinSub => 'Required to leave Kids Mode — tap to change';

  @override
  String signedInAs(Object masked) {
    return 'Signed in: $masked';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get viewAs => 'Preview as…';

  @override
  String cashShare(Object pct) {
    return '$pct% of spending';
  }

  @override
  String donutA11y(Object name, Object share) {
    return 'Spending by envelope, $name selected, $share percent';
  }

  @override
  String starsHome(Object stars) {
    return '$stars stars — confirm chores on Home to grow jars';
  }

  @override
  String circleMember(Object name) {
    return 'Savings circle · $name';
  }

  @override
  String potSoFar(Object pot) {
    return 'Pot so far: $pot';
  }

  @override
  String get roundOk => 'Round recorded ✓ — records only, we never hold money';

  @override
  String addToGoal(Object name) {
    return 'Add to $name';
  }

  @override
  String addedToGoal(Object name) {
    return 'Added to $name';
  }

  @override
  String goalBase(Object short) {
    return 'Goal base: $short';
  }

  @override
  String syncTime(Object t) {
    return 'today at $t';
  }

  @override
  String get watch => 'Watch';

  @override
  String get spentLabel => 'Spent';

  @override
  String get limitLabel => 'Limit';

  @override
  String envelopeRemaining(Object amount, Object name) {
    return '$name has $amount remaining';
  }

  @override
  String envelopeWillLeave(Object amount, Object name) {
    return 'This leaves $amount in $name';
  }

  @override
  String envelopeWillExceed(Object amount, Object name) {
    return 'This puts $name $amount over budget';
  }

  @override
  String get overBudgetTitle => 'This envelope will be over budget';

  @override
  String overBudgetBody(Object amount, Object name) {
    return '$name will be over by $amount. The expense can still be recorded.';
  }

  @override
  String get adjustAmount => 'Adjust amount';

  @override
  String get logAnyway => 'Log anyway';

  @override
  String overBy(Object amount) {
    return 'Over by $amount';
  }

  @override
  String get overBudgetLabel => 'Over budget';

  @override
  String memberPot(Object contribution, Object count, Object pot) {
    return 'Pot so far: $pot · $contribution × $count members';
  }

  @override
  String get switchProfile => 'Switch profile';

  @override
  String get switchProfileSub => 'Preview the app as another family member';

  @override
  String get youTag => 'You';

  @override
  String get pickCurrency => 'Display currency';

  @override
  String get rateField => 'ZiG per 1 USD';

  @override
  String get rateSave => 'Save rate';

  @override
  String get rateReset => 'Reset to RBZ snapshot';

  @override
  String get rateCustomNote =>
      'Used for the ZiG view across the whole app. The bundled RBZ snapshot is 15.27.';

  @override
  String get autoHide => 'Hide amounts when I leave the app';

  @override
  String get autoHideSub =>
      'Balances hide automatically when the app goes to the background — turn off if you prefer.';

  @override
  String get hideNow => 'Hide amounts right now';

  @override
  String get exportCsvRow => 'Export all transactions (CSV)';

  @override
  String get copyInvite => 'Copy invite code';

  @override
  String get copied => 'Copied ✓';

  @override
  String get inviteTitle => 'Invite a family member';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get editProfileSub => 'Name and avatar for this member';

  @override
  String get photoNote =>
      'Photos upload to your family\'s server and show across devices.';

  @override
  String get accountTitle => 'Account';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'This permanently deletes your sign-in and removes this device\'s saved financial data. This cannot be undone.';

  @override
  String get deleteAccountConfirm => 'Delete permanently';

  @override
  String get deleteAccountFailed =>
      'We couldn\'t delete your account. Check your connection and try again.';

  @override
  String get moreDetails => 'More details';

  @override
  String get lessDetails => 'Fewer details';

  @override
  String get discardTitle => 'Discard this entry?';

  @override
  String get discardBody => 'You entered details that are not saved yet.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discard => 'Discard';

  @override
  String get viewDetails => 'View balance details';

  @override
  String get fabTip => 'Tap + to record money in or out';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get loginCreateAccount => 'Create account';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get brandTagline => 'FAMILY MONEY, TOGETHER';

  @override
  String get createAccountTitle => 'Create your account';

  @override
  String get createAccountHint => 'Start your secure family money space.';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get sendingPasswordReset => 'Sending…';

  @override
  String get passwordResetSent =>
      'Password reset email sent — open the link on this phone and the app will finish it.';

  @override
  String get passwordResetFailed =>
      'We couldn\'t send the reset email. Check your connection and try again.';

  @override
  String get newToMhuri => 'New to Mhuri Hub?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get loginBadEmail => 'Enter a valid email address.';

  @override
  String get loginShortPassword => 'Password must be at least 6 characters.';

  @override
  String get checkYourEmail =>
      'Almost there — check your inbox and confirm your email, then sign in.';

  @override
  String get togglePassword => 'Show or hide password';

  @override
  String get inviteHowTo =>
      'They create an account with their email, then enter this code to join your family.';

  @override
  String get obDone => 'Let\'s get started';

  @override
  String get setupChoiceTitle => 'Set up your family';

  @override
  String get setupChoiceBody =>
      'Mhuri Hub works for one family, together. Create yours, or join the one you belong to.';

  @override
  String get setupCreateCard => 'Create a family';

  @override
  String get setupCreateCardBody =>
      'Name it, pick your household type, invite your people.';

  @override
  String get setupJoinCard => 'Join with a code';

  @override
  String get setupJoinCardBody =>
      'Someone invited you — enter their family code to join them.';

  @override
  String get createFamilyCta => 'Create family';

  @override
  String get joinFamilyCta => 'Join family';

  @override
  String get familyNameLabel => 'Family name';

  @override
  String get familyNameHint => 'e.g. The Marufu Family';

  @override
  String get householdLabel => 'What kind of family?';

  @override
  String get hhCouple => 'Couple with kids';

  @override
  String get hhSingle => 'Single parent';

  @override
  String get hhExtended => 'Extended family';

  @override
  String get hhBlended => 'Blended family';

  @override
  String get hhPartners => 'Partners, no kids';

  @override
  String get hhSolo => 'Just me for now';

  @override
  String get hhOther => 'Other';

  @override
  String get joinCodeLabel => 'Invite code';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get setupInviteTitle => 'Invite your people';

  @override
  String get setupWorking => 'Setting things up…';

  @override
  String get noEnvelopesYet =>
      'No envelopes yet — create your first one from the Budgets tab to start tracking spending.';

  @override
  String get noActivityYet =>
      'Nothing recorded yet. Tap + to add your first transaction.';

  @override
  String get setupBanner =>
      'Finish setting up: create your family or join with a code';

  @override
  String get setupBannerCta => 'Set up';

  @override
  String get deleteTypeHint => 'Type DELETE to confirm';

  @override
  String get deletePermanently => 'Delete permanently';

  @override
  String get errInviteCode =>
      'Enter the invite code from the family owner — it looks like MHRI-4F2A.';

  @override
  String get errFamilyNameTaken =>
      'That family name is already taken — try another name.';

  @override
  String get authErrEmailNotConfirmed =>
      'Check your inbox — tap the confirmation link first, then sign in.';

  @override
  String get authErrBadCredentials => 'Email or password is wrong.';

  @override
  String get authErrAlreadyRegistered =>
      'An account with this email already exists — sign in instead.';

  @override
  String get authErrRateLimited =>
      'Too many attempts — wait a minute and try again.';

  @override
  String get authErrNetwork =>
      'No connection — check your internet and try again.';

  @override
  String get authResend => 'Resend confirmation email';

  @override
  String get authResent => 'Confirmation email sent — check your inbox.';

  @override
  String get mukandoOn => 'Savings circle (mukando)';

  @override
  String get mukandoEnableTitle => 'Mukando — rotating savings';

  @override
  String get mukandoEnableSub =>
      'Save in turns with your family. Off by default — turn it on if your circle does rounds.';

  @override
  String get mukandoEnableCta => 'Turn on mukando';

  @override
  String get addPhoto => 'Use photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get photoUploading => 'Uploading photo…';

  @override
  String get photoFailed =>
      'Could not upload the photo — check your connection and try again.';

  @override
  String get photoSaved => 'Photo saved — your family will see it too.';

  @override
  String get newSavingsGoal => 'New savings goal';

  @override
  String get createSavingsGoal => 'Create savings goal';

  @override
  String get goalName => 'Goal name';

  @override
  String get goalNameHint => 'Emergency fund';

  @override
  String get targetAmount => 'Target amount';

  @override
  String get createGoal => 'Create goal';

  @override
  String get goalNameAmountFirst =>
      'Add a goal name and a target greater than zero.';

  @override
  String get shoppingLogged => 'Shopping logged';

  @override
  String get loggedItem => 'Logged';

  @override
  String get syncDataTitle => 'Sync & data';

  @override
  String get syncStateSyncing => 'Syncing…';

  @override
  String get syncStateError => 'Waiting to retry';

  @override
  String get syncStateOffline => 'Offline — changes save on this phone';

  @override
  String get syncStateNeedsSignIn => 'Sign in to sync';

  @override
  String get syncStateSaved => 'Saved on this phone';

  @override
  String get syncNowBtn => 'Sync now';

  @override
  String get syncLastSync => 'Last sync';

  @override
  String get syncNever => 'Not yet';

  @override
  String get syncPendingLabel => 'Waiting to sync';

  @override
  String get syncUpToDate => 'Everything is saved and up to date';

  @override
  String get syncErrorLabel => 'Last issue';

  @override
  String get syncWhereTitle => 'Where your data lives';

  @override
  String get syncConnectedTo => 'Family cloud:';

  @override
  String get syncNotConnected => 'This device only — no family cloud connected yet.';

  @override
  String get syncBackupNote => 'There is no separate backup to switch on. Every change is saved on this phone the moment you make it and syncs to the family cloud whenever you have data. Export a CSV below anytime for a copy you keep.';

  @override
  String get previewExit => 'Exit';

  @override
  String previewBanner(Object name) {
    return 'Previewing as $name';
  }

  @override
  String get resetTitle => 'Choose a new password';

  @override
  String get resetSubtitle => 'You are signed in from the reset link — now pick a new password.';

  @override
  String get resetNewLabel => 'New password';

  @override
  String get resetConfirmLabel => 'Confirm new password';

  @override
  String get resetMismatch => 'The two passwords do not match';

  @override
  String get resetRuleLength => 'At least 8 characters';

  @override
  String get resetRuleMix => 'Has a letter and a number';

  @override
  String get resetRuleHint => 'Use at least 8 characters, with a letter and a number.';

  @override
  String get resetCta => 'Change password';

  @override
  String get resetSuccess => 'Password changed — sign in with your new password';

  @override
  String get resetShow => 'Show or hide password';

  @override
  String get resetExpiredTitle => 'This link has expired';

  @override
  String get resetExpiredBody => 'Reset links work once and only for a short time. Send a fresh one and try again.';

  @override
  String get resetSendNew => 'Send a new reset link';

  @override
  String get listDelete => 'Delete item';

  @override
  String listDeleted(Object name) {
    return '"$name" removed from the list';
  }

  @override
  String get roleAdult => 'Adult';

  @override
  String get roleTeen => 'Teen';

  @override
  String get roleViewer => 'Viewer';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get inviteTitle => 'Invite family';

  @override
  String get inviteHowTo => 'They create an account with their email, then enter this code to join your family.';

  @override
  String get inviteNew => 'New invite';

  @override
  String get inviteEmailOptional => 'Their email (optional — only they can use it)';

  @override
  String get inviteCreate => 'Create invite';

  @override
  String get inviteCreated => 'Show this code or QR to them';

  @override
  String get inviteScanHint => 'They scan the QR with their camera, or tap the link — it opens this app ready to join.';

  @override
  String get inviteShare => 'Share';

  @override
  String get inviteShareText => 'Join our family on Mhuri Hub — your invite:';

  @override
  String get invitePending => 'Open invites';

  @override
  String get inviteNone => 'No open invites.';

  @override
  String get inviteHistory => 'Earlier invites';

  @override
  String get inviteRevoke => 'Revoke';

  @override
  String get inviteFailed => 'Could not create the invite — check your connection and try again.';

  @override
  String get inviteTooMany => 'There are already 5 open invites — revoke one first.';

  @override
  String get inviteOwnerOnly => 'Only the family owner manages invites.';

  @override
  String get inviteAlreadyInFamily => 'You are already in a family — invites are for joining a new one.';

  @override
  String get makeOwner => 'Make owner';

  @override
  String get makeOwnerFailed => 'Could not transfer ownership — check your connection and try again.';

  @override
  String get roleParent => 'Parent';

  @override
  String get roleChild => 'Child';

  @override
  String inviteAcceptedLabel(Object code, Object role) {
    return '$code — joined';
  }

  @override
  String makeOwnerBody(Object name) {
    return 'Make $name the family owner? You become a regular adult member and they manage invites and settings.';
  }

  @override
  String makeOwnerDone(Object name) {
    return '$name is now the family owner';
  }

  @override
  String inviteRevokeBody(Object code) {
    return 'Revoke invite $code? They will not be able to join with it.';
  }

  @override
  String inviteLinkReady(Object code) {
    return 'Invite $code is waiting — join the family below.';
  }

  @override
  String get syncProblemsTitle => 'Changes that need you';

  @override
  String get syncProblemsBody => 'These changes could not reach the family cloud after several tries. Retry them, or discard them — nothing is removed without your say-so.';

  @override
  String get syncRetryThis => 'Try again';

  @override
  String get syncDiscardThis => 'Discard';

  @override
  String get syncDiscardTitle => 'Discard this change?';

  @override
  String get syncKindTx => 'Expense';

  @override
  String get syncKindEnvelope => 'Budget';

  @override
  String get syncKindGoal => 'Savings goal';

  @override
  String get syncKindItem => 'List item';

  @override
  String get syncKindRequest => 'Request';

  @override
  String get syncKindOther => 'Change';

  @override
  String syncDiscardBody(Object what) {
    return '“$what” stays only on this phone and will never reach the family cloud. Discard it?';
  }

  @override
  String syncTries(Object tries) {
    return '$tries tries so far';
  }

  @override
  String get setupInviteCopied => 'Invite copied.';

  @override
  String get setupBadEmail => 'Enter a valid email address.';

  @override
  String get setupTagline => 'One family. One plan.';

  @override
  String get setupPhotoOptional => 'Add profile photo (optional)';

  @override
  String get setupHaveCode => 'I have an invite code';

  @override
  String get setupCreateInstead => 'Create a family instead';

  @override
  String get setupCopy => 'Copy';

  @override
  String get setupScanToJoin => 'Scan to join';

  @override
  String get setupCreateTitle => 'Create your family';

  @override
  String get setupCreateSub => 'Tell us what your family calls you.';

  @override
  String get setupPreferredName => 'Preferred name';

  @override
  String get setupFamilyNameField => 'Family name (for example, The Moyos)';

  @override
  String get setupCurrency => 'Primary currency';

  @override
  String get setupJoinTitle => 'Join your family';

  @override
  String get setupJoinSub => 'Use the code shared by a family member.';

  @override
  String get setupInviteTitle => 'Invite members';

  @override
  String get setupInviteSub => 'Bring everyone into the same family space.';

  @override
  String get setupRoleSuggestion => 'The role is included as a suggestion. Confirm it in Family settings after they join.';

  @override
  String get setupSendInvite => 'Send invite';

  @override
  String get setupContinue => 'Continue  →';

  @override
  String get setupInviteLater => 'Invite later';

  @override
  String get setupPermsTitle => 'Set permissions';

  @override
  String get setupPermsSub => 'Recommended access is ready. You can change it later in Family settings.';

  @override
  String get setupPermWallet => 'View own wallet';

  @override
  String get setupPermTx => 'Log transactions';

  @override
  String get setupPermBudget => 'View family budget';

  @override
  String get setupFinish => 'Finish setup';

  @override
  String get deleteWhatTitle => 'What happens when you delete';

  @override
  String get deleteWhatOwner => 'You are the family owner: the whole family space is deleted — every account, budget, transaction and list, for everyone. This cannot be undone.';

  @override
  String get deleteWhatMember => 'You leave the family. Your membership ends, your photo and email are removed, and your past transactions remain but show as “Former member”. Everyone else keeps their data.';

  @override
  String get deleteWhatSessions => 'Every sign-in on every device is signed out.';

  @override
  String get deleteStepLeave => 'Leaving the family…';

  @override
  String get deleteStepAnonymize => 'Removing your personal details…';

  @override
  String get deleteStepSessions => 'Revoking sign-ins…';

  @override
  String get deleteStepIdentity => 'Deleting your account…';

  @override
  String setupInviteText(Object family, Object code, Object role) {
    return 'Join $family on Mhuri Hub with invite code $code. Suggested role: $role.';
  }

  @override
  String setupInviteSubject(Object family) {
    return 'Join $family on Mhuri Hub';
  }

  @override
  String setupStepOf(Object n) {
    return 'Step $n of 3';
  }

  @override
  String kidsGoalSaved(Object goal, Object pct) {
    return 'Goal: $goal — $pct% saved';
  }

  @override
  String kidsHi(Object name) {
    return 'Hi $name!';
  }

  @override
  String kidsWishItem(Object amount) {
    return 'Soccer ball — US$25 · saved $amount';
  }

  @override
  String loginSentCode(Object phone) {
    return 'We sent a code by SMS to $phone';
  }

  @override
  String recSkipped(Object date) {
    return 'Skipped — next: $date';
  }

  @override
  String safeToSpend(Object amount) {
    return 'Safe to spend today: $amount';
  }

  @override
  String scheduledOn(Object from, Object to) {
    return 'Scheduled on this device · quiet hours $from–$to';
  }

  @override
  String setCurrencySub(Object rate) {
    return 'USD primary · ZiG secondary · $rate';
  }

  @override
  String syncPill(Object count) {
    return '{count, plural, =1{1 change saved on this device — syncs when online} other{$count changes saved on this device — syncs when online}}';
  }

  @override
  String teenSplitHint(Object amount) {
    return 'Suggested split of $amount earned this month';
  }

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesBody => 'You have not saved yet. Leave anyway?';

  @override
  String get stay => 'Keep editing';

  @override
  String get leave => 'Leave';

  @override
  String get btnCreate => 'Create';

  @override
  String get btnJoin => 'Join';

  @override
  String get hintFamilyExample => 'e.g. The Taylor Family';

  @override
  String get transferFrom => 'From';

  @override
  String get transferTo => 'To';

  @override
  String get transferWhy => 'Why?';

  @override
  String get listNameLabel => 'Item';

  @override
  String get listQtyLabel => 'Qty';

  @override
  String get kidsPinHint => 'New PIN (4–6 digits)';

  @override
  String get kidsPinUpdated => 'Kids Mode PIN updated ✓';

  @override
  String get setupEnterBoth => 'Enter your preferred name and family name.';

  @override
  String get setupNeedsConnection => 'A connection is required to create your family.';

  @override
  String get setupNameTaken => 'That family name is already taken. Try another.';

  @override
  String get setupEnterJoin => 'Enter your preferred name and invite code.';

  @override
  String get avatarError => 'Couldn\'t update that photo. Try another one.';

  @override
  String get invitesLoadFailed => 'Could not load invites. Pull to refresh.';

  @override
  String filterAll(Object n) {
    return 'All ($n)';
  }
}
