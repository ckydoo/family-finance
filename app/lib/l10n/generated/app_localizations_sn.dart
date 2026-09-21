// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Shona (`sn`).
class AppLocalizationsSn extends AppLocalizations {
  AppLocalizationsSn([String locale = 'sn']) : super(locale);

  @override
  String get tabHome => 'Musha';

  @override
  String get tabBudgets => 'Bhajeti';

  @override
  String get tabSavings => 'Kuchengeta';

  @override
  String get tabLists => 'Rondedzero';

  @override
  String get tabFamily => 'Mhuri';

  @override
  String get tabActivity => 'Zviitwa';

  @override
  String get greetingMorning => 'Mangwani';

  @override
  String get greetingAfternoon => 'Makadii';

  @override
  String get greetingEvening => 'Manheru';

  @override
  String get familyPool => 'Mari yemhuri yese';

  @override
  String safeToSpend(String amount) {
    return 'Zvakanaka kushandisa nhasi: $amount';
  }

  @override
  String get seeAll => 'Ona zvese';

  @override
  String get add => 'Wedzera';

  @override
  String get save => 'Chengeta';

  @override
  String get cancel => 'Dzimisa';

  @override
  String get undo => 'Dzimisa';

  @override
  String get post => 'Isa';

  @override
  String get skip => 'Kurega';

  @override
  String get approve => 'Bvumira';

  @override
  String get notThisWeek => 'Kwete vhiki iri';

  @override
  String get done => 'Zvaita';

  @override
  String get export => 'Buritsa';

  @override
  String get meeting => 'Musangano';

  @override
  String get newEnvelope => 'Bhajeti itsva';

  @override
  String get recurringExpenses => 'Mari inodzorera';

  @override
  String get shopping => 'Kutengesa';

  @override
  String get activityTitle => 'Zviitwa';

  @override
  String get noActivityTitle => 'Hapana zviitwa zviri nani';

  @override
  String get noActivityHint =>
      'Mari yese inobuda, inopinda uye inovumirwa inowanikwa pano — tangira ne + bhatani.';

  @override
  String get noGoals => 'Hapana zvinangwa';

  @override
  String get noGoalsHint =>
      'Tangira nefundi yenguva dzakaoma — kak zvishoma choga chinoshandura zvaunonzwa.';

  @override
  String get reportTitle => 'Bhuku rimwe';

  @override
  String get income => 'Kuwana';

  @override
  String get spent => 'Mari yashandiswa';

  @override
  String get saved => 'Mari yachengetwa';

  @override
  String get safePerDay => 'Zvakanaka pazuva';

  @override
  String get envelopeHealth => 'Utano hwebajeti';

  @override
  String get cashLeak => 'Mari yeresandla';

  @override
  String get shareReport => 'Govera nemhuri';

  @override
  String get meetingCta => 'Tangira musangano wemhuri';

  @override
  String get exportCsv => 'Buritsa zvose muna CSV';

  @override
  String get family => 'Mhuri';

  @override
  String get hi => 'Mhoro';

  @override
  String get mySavings => 'Mari dzangu';

  @override
  String get addToJar => 'Wekira mari';

  @override
  String get savingsMatch => 'Kufanana chengeto';

  @override
  String get savingsMatchNote => 'Vabereki vanoisa 50% paunochengeta';

  @override
  String get earnings => 'Mibairo';

  @override
  String get logEarning => 'Nyora mubairo';

  @override
  String get myProposals => 'Zvandatumira';

  @override
  String get proposeExpense => 'Tumira mari yainobuda';

  @override
  String get proposeTitle => 'Kumbira mari yainobuda';

  @override
  String get peek => 'Vabereki vakakubvumira kuona iyi';

  @override
  String get plan => 'Hurongwa: shandisa · chengeta · pa';

  @override
  String get settingsTitle => 'Zvirongwa';

  @override
  String get remindersOnDevice => 'Yeuchidzo pane iri foni';

  @override
  String get remindersSubtitle =>
      'Mari inodzorera, bhajeti, vana, zvinangwa, mukando & misangano';

  @override
  String get quietHours => 'Nguva yerudo (hapana yeuchidzo mukati meiyi nguva)';

  @override
  String get monthStartsOn => 'Mwedzi unotangira zuva';

  @override
  String get language => 'Mutauro';

  @override
  String get largeText => 'Mavara makuru (kunyanya kuona)';

  @override
  String get exportCsvSettings => 'Buritsa zvose muna CSV';

  @override
  String get comingSoon => 'Zvichauya';

  @override
  String get remindersTitle => 'Yeuchidzo';

  @override
  String scheduledOn(String from, String to) {
    return 'Zvakarongwa pane iri foni · nguva yerudo $from–$to';
  }

  @override
  String get remindersOff => 'Yeuchidzo dzavharwa';

  @override
  String get nothingComing => 'Hapana chiri kuuya';

  @override
  String get ob1Title => 'Mari, inotungamirwa pamwe chete';

  @override
  String get ob1Body =>
      'Nzvimbo imwe inodziya kune zvinhu zvose zvemhuri inowana, inoshandisa, inochengeta uye inoronga — nemari dzose dzinoshandiswa, online kana pasina.';

  @override
  String get ob2Title => 'Mabhajeti, kwete kukudzvanyirira';

  @override
  String get ob2Body =>
      'Pa)dolla rimwe basa rayo. Kotaidzi, mafephya, kutakura — ona pakarepo chiri kunaka, chiri kuda kuzadzwa, uye chakanaka kushandisa nhasi.';

  @override
  String get ob3Title => 'Yakavakirwa kune mhuri yose';

  @override
  String get ob3Body =>
      'Vakoma vanogovana hurongwa. Vana kukura mabhodhoro nenyu. Vajaidzasi vanotumira mari yainobuda vanodzidza nekuwanisa. Gogo anochengeta mukando.';

  @override
  String get ob4Title => 'Yeuchidzo ine tsitsi';

  @override
  String syncPill(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count zvichinjika zvakachengetedzwa pane yambuyariro — zvinoenderana paunenge une internet',
    );
    return '$_temp0';
  }

  @override
  String get hideAmountsTip => 'Vanzahuwa mari';

  @override
  String get showAmountsTip => 'Ratidza mari';

  @override
  String get themeLabel => 'Maitiro';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Vachena';

  @override
  String get themeDark => 'Vatema';

  @override
  String get sixMonthNet => 'Mwedzi 6 mharidzo (USD)';

  @override
  String get donutEmpty =>
      'Hapana zvave kutorwa mwedzi iyi — donuti rinazvo paunowedzera zvinotora.';

  @override
  String get ob4Body =>
      'Zvikumbiro zvemari, tarisiro yebhajeti nemusangano wesvondo — zvinoremekedza nguva dzekuzvipira, zviri pamufoni wako. Iwe unotonga.';

  @override
  String get next => 'Zvinotevera';

  @override
  String get loginWelcome => 'Svika kuMhuri Hub';

  @override
  String get loginEnterCode => 'Pinda iyo kodhi';

  @override
  String loginSentCode(String phone) {
    return 'Takatumira kodhi neSMS ku$phone';
  }

  @override
  String get loginSignInHint =>
      'Pinda nefoni yako kuvhura nzvimbo yemhuri yako.';

  @override
  String get loginSendCode => 'Tumira kodhi';

  @override
  String get loginVerify => 'Simbirurira & pinda';

  @override
  String get loginChangeNumber => 'Chinja nhare';

  @override
  String get loginBadPhone =>
      'Pinda nhare inoshanda (somuenzaniso +44 7700 900123).';

  @override
  String get loginFooter =>
      'Demo: chero nhare uye pinda 1234.\nLive inotumira kodhi yeSMS chaiyo.';

  @override
  String get quickAddTitle => 'Wedzera nyore';

  @override
  String get expense => 'Kubhadhara';

  @override
  String get envelopeLabel => 'Mabhuku';

  @override
  String get whoLabel => 'Niani';

  @override
  String get paidWithLabel => 'Yabhadhara nayo';

  @override
  String get noteHint => 'Cherechedza (somuenzaniso FreshMart)';

  @override
  String get enterAmountFirst => 'Pinda nhamba yemari kutanga';

  @override
  String get savedOffline =>
      'Yachengetedzwa ✓ — inoshanda pasina internet, inoenderana pazviripo';

  @override
  String kidsHi(String name) {
    return 'Mhoro $name!';
  }

  @override
  String get kidsMyJar => 'Bhasira rangu';

  @override
  String kidsGoalSaved(String goal, int pct) {
    return 'Chinangwa: $goal — $pct% zvakachengetedzwa';
  }

  @override
  String get kidsMyChores => 'Basa rangu';

  @override
  String get kidsWishList => 'Zvinodiwa';

  @override
  String kidsWishItem(String amount) {
    return 'Bhora — US\$25 · zvakachengetedzwa $amount';
  }

  @override
  String get kidsAskMoney => 'Bvunza\nmhamha na babha';

  @override
  String get kidsDoChore => 'Ita basa';

  @override
  String get kidsAllDone => 'Zvapera zvose!';

  @override
  String get kidsParents => 'Vabereki';

  @override
  String get kidsAskTitle => 'Bvunza mhamha na babha';

  @override
  String get kidsWhatFor => 'Nechii?';

  @override
  String get kidsDefaultReason => 'Mari yekutanga';

  @override
  String get teenZoneTitle => 'Nzvimbo yeVanya · 13–17';

  @override
  String get teenNoEarnings => 'Kusati kwaye mari yanyorwa';

  @override
  String get teenEarnHint =>
      'Ora mota, batsira muchitoro — nyora uye uone bhasira rakura.';

  @override
  String get teenSpend => 'Shandisa 50%';

  @override
  String get teenSave => 'Chengetedza 40%';

  @override
  String get teenGive => 'Kupa 10%';

  @override
  String teenSplitHint(String amount) {
    return 'Kukamurwa kwe$amount zvakawanikwa mwedzi iyi';
  }

  @override
  String get teenSavedJar => 'Yachengetedzwa mubhasira — vabereki vanoisa 50%';

  @override
  String get teenWhatDid => 'Waita sei?';

  @override
  String get familyTitle => 'Mhuri';

  @override
  String get membersDesc => 'Vabereki nevana · mwedzi unotanga musi wekutanga';

  @override
  String get membersInviteHint =>
      'Govaneka kodhi kana scan kuvaka muridzi wemhuri';

  @override
  String get membersDemoTip =>
      'Demo: shandisa \"View as\" kushandura profile. Vana vanopinda munzvimbo yakavharwa.';

  @override
  String get setCurrency => 'Mari & mitauro';

  @override
  String setCurrencySub(String rate) {
    return 'USD utungamiri · ZiG chipiri · $rate';
  }

  @override
  String get setPrivacy => 'Kuvanzika';

  @override
  String get setPrivacySub =>
      'Mabhuku emunhu: kwete — muridzi anongovana zvakagovaniswa';

  @override
  String get setMonthStart => 'Kutanga kwevwedzi';

  @override
  String get setMonthStartSub => 'Zuva 1 — rwendo rwevhiki remubhadharo';

  @override
  String get setNotif => 'Zvikumbiro';

  @override
  String get setNotifSub =>
      'Yambiro 80% yebhajeti · mari inopihwa · zvikumbiro zvevana';

  @override
  String get setBackup => 'Backup & kuburitsa';

  @override
  String get setBackupSub => 'Backup yakavanzika · CSV kuburitsa (muridzi)';

  @override
  String get meetingTitle => 'Sangano remhuri';

  @override
  String get mFigures => 'Mwedzi upfuura, muma nharba';

  @override
  String get figureIncome => 'Kuwana';

  @override
  String get figureSpent => 'Kubhadhara';

  @override
  String get figureSaved => 'Kuchengetedza';

  @override
  String get mEnvelopeHealth => 'Hutano hwemabhuku';

  @override
  String get mReachedTalk =>
      'Taurawo nemabhuku akanzi \"Asvika\". Zadzazvo pamwe chete, zvine runyararo.';

  @override
  String get mGoals => 'Zvinangwa zvekuchengetedza';

  @override
  String get mChores => 'Zvinotora, mabhasira & zvikumbiro';

  @override
  String get mImprove => 'Chinhu chimwe chokuvandudza';

  @override
  String recSkipped(String date) {
    return 'Damburwa — inotevera: $date';
  }

  @override
  String get recNew => 'Mari inopinda zvakare';

  @override
  String get recReview =>
      'Hapana chinotorwa otomatiki — iwe unotarisa uye unonyora zvose.';

  @override
  String get recNoEnvelope => 'Hapana bhuku';

  @override
  String get recNextDue => 'Inotevera:';

  @override
  String get recNameAmount => 'Ipa zita nemari';

  @override
  String get recSaveRule => 'Chengetedza mutemo';

  @override
  String get recNameHint => 'Zita (somuenzaniso Mari yechikoro)';

  @override
  String get roleOwner => 'Muridzi';

  @override
  String get roleAdult => 'Mukuru';

  @override
  String get roleTeen => 'Mukomana/Musikana';

  @override
  String get roleKid => 'Mwana';

  @override
  String get roleViewer => 'Sekuru · Anotarisa';

  @override
  String get methodCash => 'Mari inotora';

  @override
  String get methodMobile => 'Mari yefoni';

  @override
  String get methodCard => 'Kadhi';

  @override
  String get methodTransfer => 'Kutamisa';

  @override
  String get methodAgent => 'Nyanzvi / mari point';

  @override
  String get methodOther => 'Chimwe';

  @override
  String get stateToBuy => 'Zvinotengwa';

  @override
  String get stateInCart => 'Mugoketi';

  @override
  String get stateDone => 'Zvaita';

  @override
  String get freqWeekly => 'Vhiki rega';

  @override
  String get freqMonthly => 'Mwedzi rega';

  @override
  String get rollReset => 'Tangidza mwedzi wese';

  @override
  String get rollRoll => 'Endesa zvinosara';

  @override
  String get rollAccum => 'Wedzera zvinosara';

  @override
  String get freqTerm => 'Pakutanga (~mwedzi 3)';

  @override
  String get budgetsTitle => 'Mabhajeti';

  @override
  String get noEnvelopes => 'Hapana mabhuku zvino';

  @override
  String get envelopesHint =>
      'Mabhuku ibhajeti dzaunoona: chikafu, chikoro, fhudzi. Gada yekutanga pazasi.';

  @override
  String get newEnvStub => 'Bhuku idzva — richauya (chikamu 1)';

  @override
  String get addRecurringTip => 'Wedzera mari inopinda zvakare';

  @override
  String get recReviewed =>
      'Unotariswa usati unyore — hapana chinotorwa nyema.';

  @override
  String get noRecurring => 'Hapana mari inopinda zvakare zvino';

  @override
  String get recurringHint =>
      'Wedzera mutemo wechikoro, rhovera kana airtime — tinokuyambira panguva yayo.';

  @override
  String get chipOnTrack => 'Zvakanaka';

  @override
  String get chipReached => 'Zvasvika';

  @override
  String get remaining => 'Zvinosara';

  @override
  String get moveMoney => 'Fambisa mari';

  @override
  String get pickFirst => 'Sarudza mabhuku nemari kutanga';

  @override
  String get skipPeriod => 'Dambura mwedzi uyu';

  @override
  String get pauseRule => 'Misa mutemo';

  @override
  String get resumeRule => 'Endesa mutemo';

  @override
  String get meetingHint => 'Maminitsi 15, kamwe pamwedzi.';

  @override
  String mChoresLine(Object proposals, Object requests, Object stars) {
    return '$stars zvinotora zvaitwa · $requests zvikumbiro zvakamirira · $proposals zvikumbiro zvevanya zvakamirira.';
  }

  @override
  String get meetingNoteHint =>
      'somuenzaniso \"Bikawo mazuva ese — mari ye musika iri kuwanda.\"';

  @override
  String get meetingSaveNote => 'Chengetedza chinyorwa chedu';

  @override
  String get savedTick => 'Zvachengetedzwa ✓';

  @override
  String get meetingDone => 'Zvaita — tichaonana mwedzi unouya';

  @override
  String get reportCard => 'Ripozo';

  @override
  String get recentActivity => 'Zviitiko zvichangobva';

  @override
  String get swapCurrency => 'Chinja mari inoratidzwa';

  @override
  String get yourChild => 'Mwana wako';

  @override
  String get review => 'Tarisa';

  @override
  String get confirm => 'Simbirurira';

  @override
  String get markCollected => 'Ratidza yakatorwa';

  @override
  String get decline => 'Ramba';

  @override
  String get sentToParents => 'Zvatumirwa kumhamha na babha';

  @override
  String get sendRequest => 'Tumira chikumbiro';

  @override
  String get parentsOnly => 'Vabereki chete';

  @override
  String get pinExitLine => 'Pinda PIN yako kubuda munzvimbo yeVana.';

  @override
  String get wrongPin => 'PIN harichokwadi';

  @override
  String get unlock => 'Vhura';

  @override
  String get addItem => 'Wedzera chinhu';

  @override
  String get listSharedSub =>
      'Rondedzero yekutenga yemhuri · inogovaniswa nese';

  @override
  String get tickFirst => 'Nanga zviri kutengwa kutanga';

  @override
  String get namePriceFirst => 'Ipa zita nemutengo chinhu';

  @override
  String get addToList => 'Wedzera kurondedzero';

  @override
  String get spaceSetup => 'Gadzirira nzvimbo yemhuri yako';

  @override
  String get spaceSetupSub =>
      'Gada nzvimbo yemhuri yako, kana pinda iyo vamwe vako vakagadzira nekodi yavo. Zvese zvaunonyora zvinoendanisa pakati pemafoni enyu.';

  @override
  String get createSpace => 'Gada nzvimbo';

  @override
  String get joinWithCode => 'Pinda nekodi';

  @override
  String get offlineRetry => 'Pasina internet — inoedza zoga';

  @override
  String get syncProblem => 'Dambudziko rekuendanisa';

  @override
  String get signinExpired => 'Kupinda kwapera — bubuka zvakare';

  @override
  String get syncing => 'Kuendanisa…';

  @override
  String lastSync(Object last) {
    return 'Kuendaniswa kwapfuura: $last';
  }

  @override
  String get familySpace => 'Nzvimbo yemhuri';

  @override
  String get syncNow => 'Endanisa zvino';

  @override
  String get createFamilySpace => 'Gada nzvimbo yemhuri';

  @override
  String get familyName => 'Zita remhuri';

  @override
  String get localizedNote =>
      'App yese inotaura mitauro mihanhi — hapana chinhu chasara chiEnglish choga.';

  @override
  String get nextCreateSpace =>
      'Zvinotevera: gada nzvimbo yemhuri (kana pinda nekodi) kubva muFamily tebhu.';

  @override
  String reachedMove(Object on, Object total) {
    return '$on pa$total mabhuku zvakanaka. Vhura ayo anonzi \"Zvasvika\" uye fambisa mari — zvakanaka, kwete zvakakwana.';
  }

  @override
  String get cashTrace =>
      'Mari inotora inonyore kushandisa, inorema kuteedzera. Kubhadhara mari yefoni kana kadhi kunochengetedza mifananidzo icherechedzwa.';

  @override
  String get whereMoneyWent => 'Mari yakapinda kupi';

  @override
  String get exportFailed => 'Kuburitswa kundikana pane dzimwe nzvimbo';

  @override
  String csvSaved(Object path) {
    return 'CSV yachengetedzwa: $path';
  }

  @override
  String exportedPath(Object path) {
    return 'Yaburitswa ✓ $path';
  }

  @override
  String get bringToMeeting => 'Unza izvi kusangano remhuri remwedzi';

  @override
  String get savingsTitle => 'Kuchengetedza';

  @override
  String get markRound => 'Ratidza zvaatorwa';

  @override
  String get recordsOnly => 'Mhuri Hub haimbori mari — inonyora chete.';

  @override
  String get saveContribution => 'Chengetedza mupi';

  @override
  String get sendTest => 'Tumira muyedzo weyeuchidzo';

  @override
  String get testOk => 'Yeuchidzo dzinoshanda panharembozha iyi.';

  @override
  String get monthCycle => 'Mwedzi wendangariro';

  @override
  String get paydayAlign =>
      'Mabhajeti anoenderana nemubhadharo — zvinotangidzwa zuva iri, uye yeuchidzo wesangano rinouya masikati machangotanga';

  @override
  String get backupComing => 'Backup & kudzosa (richauya)';

  @override
  String get fromLabel => 'Kubva';

  @override
  String get addTransaction => 'Wedzera mutengesaniso';

  @override
  String get logWhatAmount => 'Nyora waita nemari';

  @override
  String get logIt => 'Nyora';

  @override
  String get fromEnvelope => 'Kubva mubhuku';

  @override
  String get amountPurposeFirst => 'Isa mari nokudii';

  @override
  String get sentApproval => 'Zvatumirwa kumhamha na babha kuvhara';

  @override
  String get sendProposal => 'Tumira chikumbiro';

  @override
  String get stWaiting => 'Kumirira ⏳';

  @override
  String get stApproved => 'Zvabvumirwa ✓';

  @override
  String get stDeclined => 'Zvarambwa';

  @override
  String requestTitle(Object amount, Object name) {
    return '$name akumbira $amount';
  }

  @override
  String proposalTitle(Object amount, Object name) {
    return '$name anokumbira $amount';
  }

  @override
  String proposalSub(Object env, Object reason) {
    return '$reason · kubva mubhuku $env';
  }

  @override
  String recDueSub(Object when) {
    return 'Inopinda zvakare · inosvika $when · nyora paunobhadhara';
  }

  @override
  String get dueNow => 'izvozvi';

  @override
  String get dueSoon => 'pedyo';

  @override
  String choreDoneTitle(Object name) {
    return '\"$name\" zvapiwa — simbirurira?';
  }

  @override
  String choreDoneSub(Object stars) {
    return '$stars zvinotora — simbirurira bhasira rikure';
  }

  @override
  String circleSub(Object amount, Object pot, Object who) {
    return '$who ndiye anotora $amount · mari $pot zvino';
  }

  @override
  String get exportReal => 'Kuburitswa kunoshanda pane dhiraivho chaiyo';

  @override
  String get allSynced => '✓ Zvose zvaendaniswa';

  @override
  String get familyCta => 'Mhuri ›';

  @override
  String get recentInEnv => 'Changobva mubhuku rino';

  @override
  String get nothingLogged => 'Hapana chanyorwa pano parizvino.';

  @override
  String dueBy(Object days) {
    return ' Yapera nguva ${days}zuva';
  }

  @override
  String get dueToday => 'inofanira nhasi';

  @override
  String get dueTomorrow => 'inofanira mangwana';

  @override
  String dueIn(Object days) {
    return 'inofanira mazuva $days masikati';
  }

  @override
  String circleTitle(Object round, Object total) {
    return 'Denderedzwa rekuchengetedza — Kutenderera $round pa$total';
  }

  @override
  String postedSnack(Object name) {
    return '$name yanyorwa ✓ — bhuku ravandudzwa';
  }

  @override
  String starsGiven(Object stars) {
    return '$stars zvinotora zvapihwa vana!';
  }

  @override
  String approvedReq(Object amount, Object name) {
    return 'Zvabvumirwa ✓ — zvedzerwa ku$name';
  }

  @override
  String declineBody(Object env, Object reason) {
    return '$reason\n\nKubva mubhuku: $env';
  }

  @override
  String approvedProp(Object amount, Object env) {
    return 'Zvabvumirwa ✓ — $amount zvanyorwa mu$env';
  }

  @override
  String sentKid(Object name) {
    return '\"$name\" zvatumirwa kumhamha na babha';
  }

  @override
  String get listEmptyAdd => 'Hapana pano — wedzera chinhu ne ＋';

  @override
  String usesPct(Object name, Object pct) {
    return 'Inoshandisa $pct% yebhuku re$name';
  }

  @override
  String loggedTo(Object amount, Object name) {
    return 'Yanyorwa $amount ku$name ✓ — bhuku ravandudzwa';
  }

  @override
  String get finishShop => 'Pedza kutenga → nyora mari';

  @override
  String estPrice(Object symbol) {
    return 'Mutengo unofungidzirwa ($symbol)';
  }

  @override
  String get myFamily => 'Mhuri yangu';

  @override
  String spaceCreated(Object code) {
    return 'Nzvimbo yagadzirwa ✓ Kodi yekukoka: $code';
  }

  @override
  String get createFail => 'Zvikundikana kugadzira nzvimbo — edza zvakare';

  @override
  String get joinSpaceTitle => 'Pinda munzvimbo yemhuri';

  @override
  String get inviteCode => 'Kodi yekukoka';

  @override
  String get joinedOk => 'Vapinda ✓ — zvinhu zvenyu zviri kuendaniswa';

  @override
  String get joinFail => 'Zvikundikana kupinda — edza zvakare';

  @override
  String get kidsPin => 'PIN yekubuda muNzvimbo yeVana';

  @override
  String get kidsPinSub => 'Inodiwa kubuda muNzvimbo yeVana — bhatani richinja';

  @override
  String signedInAs(Object masked) {
    return 'Vapinda: $masked';
  }

  @override
  String get signOut => 'Buda';

  @override
  String get viewAs => 'Tarisa se';

  @override
  String cashShare(Object pct) {
    return '$pct% yekushandiswa';
  }

  @override
  String donutA11y(Object name, Object share) {
    return 'Mari inopinda zvikamu, $name yasaratidzwa, $share muzana';
  }

  @override
  String starsHome(Object stars) {
    return '$stars zvinotora — simbirurira zvinotora paKumba kuti mabhasira akure';
  }

  @override
  String circleMember(Object name) {
    return 'Denderedzwa rekuchengetedza · $name';
  }

  @override
  String potSoFar(Object pot) {
    return 'Mari yausvika: $pot';
  }

  @override
  String get roundOk =>
      'Kutenderera kwanyorwa ✓ — kunyora chete, hatigari mari';

  @override
  String addToGoal(Object name) {
    return 'Wedzera ku$name';
  }

  @override
  String addedToGoal(Object name) {
    return 'Zvawedzerwa ku$name';
  }

  @override
  String goalBase(Object short) {
    return 'Chinangwa chokutanga: $short';
  }

  @override
  String syncTime(Object t) {
    return 'nhasi pa$t';
  }

  @override
  String get watch => 'Tarisa';

  @override
  String get spentLabel => 'Kushandiswa';

  @override
  String get limitLabel => 'Mulingo';

  @override
  String memberPot(Object contribution, Object count, Object pot) {
    return 'Mari yausvika: $pot · $contribution × $count vanhu';
  }

  @override
  String get switchProfile => 'Chinja profile';

  @override
  String get switchProfileSub => 'Tarisa app semhuri yemumwe';

  @override
  String get youTag => 'Iwe';

  @override
  String get pickCurrency => 'Mari inoratidzwa';

  @override
  String get rateField => 'ZiG pa1 USD';

  @override
  String get rateSave => 'Chengetedza mutengo';

  @override
  String get rateReset => 'Dzokera kuRBZ yekutanga';

  @override
  String get rateCustomNote =>
      'Inoshandiswa kuona maZiG muapp yese. RBZ inotanga ndeye 15,27.';

  @override
  String get autoHide => 'Vanza mari ndisabuda muapp';

  @override
  String get autoHideSub =>
      'Mari inovanzika app yasara kumashure — dzima usati ude.';

  @override
  String get hideNow => 'Vanza mari izvozvi';

  @override
  String get exportCsvRow => 'Buritsa zvose zvaitika (CSV)';

  @override
  String get copyInvite => 'Kopkodhi yekukoka';

  @override
  String get copied => 'Yakopiwa ✓';

  @override
  String get inviteTitle => 'Koka muridzi wemhuri';

  @override
  String get inviteDemoNote =>
      'Demo inouya nemhuri yemuenzaniso. Mulive kodhi yekukoka inogara pano — igovane nemhuri ipinde munzvimbo yako.';

  @override
  String get editProfile => 'Chinja profile';

  @override
  String get editProfileSub => 'Zita nemufananidzo weuyu member';

  @override
  String get photoNote =>
      'Mifananidzo yeprofile inouya nekuendanisa kwemhuri. Zvivanhu zviri po zvino.';
}
