// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for North Ndebele (`nd`).
class AppLocalizationsNd extends AppLocalizations {
  AppLocalizationsNd([String locale = 'nd']) : super(locale);

  @override
  String get tabHome => 'Ikhaya';

  @override
  String get tabBudgets => 'Ibhajeti';

  @override
  String get tabSavings => 'Ukugcina';

  @override
  String get tabLists => 'Uhlu';

  @override
  String get tabFamily => 'Umndeni';

  @override
  String get tabActivity => 'Izenzo';

  @override
  String get greetingMorning => 'Salibonane';

  @override
  String get greetingAfternoon => 'Salibonane';

  @override
  String get greetingEvening => 'Salibonane';

  @override
  String get familyPool => 'imali yomndeni wonke';

  @override
  String safeToSpend(String amount) {
    return 'Kuphephile ukusebenzisa namhlanje: $amount';
  }

  @override
  String get seeAll => 'Bonke okubonile';

  @override
  String get add => 'Engeza';

  @override
  String get save => 'Gcina';

  @override
  String get cancel => 'Hlehlisa';

  @override
  String get undo => 'Hlehlisa';

  @override
  String get post => 'Faka';

  @override
  String get skip => 'Yekela';

  @override
  String get approve => 'Yamukela';

  @override
  String get notThisWeek => 'Cha lesonto leli';

  @override
  String get done => 'Kwenziwe';

  @override
  String get export => 'Khipha';

  @override
  String get meeting => 'Umhlangano';

  @override
  String get newEnvelope => 'Ibhajeti entsha';

  @override
  String get recurringExpenses => 'imali ephindaphindayo';

  @override
  String get shopping => 'Ukuthenga';

  @override
  String get activityTitle => 'Izenzo';

  @override
  String get noActivityTitle => 'Asikho isenzo';

  @override
  String get noActivityHint =>
      'imali yonke ephuma, engenayo nesivumelwano sivezwa lapha — qala nge+.';

  @override
  String get noGoals => 'Asikho inhloso';

  @override
  String get noGoalsHint =>
      'Qala ngomkhombe wezimbeleko — ncane njalo njalo kushintja indlela ozizwa ngayo.';

  @override
  String get reportTitle => 'Ikadi lembiko';

  @override
  String get income => 'Imali engenayo';

  @override
  String get spent => 'okuchithiwe';

  @override
  String get saved => 'okugciniwe';

  @override
  String get safePerDay => 'okuphephile / usuku';

  @override
  String get envelopeHealth => 'impilo yebhajethi';

  @override
  String get cashLeak => 'imali yesandla';

  @override
  String get shareReport => 'Yabelana nomndeni';

  @override
  String get meetingCta => 'Qala umhlangano womndeni';

  @override
  String get exportCsv => 'Khipha konke nge-CSV';

  @override
  String get family => 'Umndeni';

  @override
  String get hi => 'Sawubona';

  @override
  String get mySavings => 'imali yami';

  @override
  String get addToJar => 'Faka kumali';

  @override
  String get savingsMatch => 'Ukufanisa okugciniwe';

  @override
  String get savingsMatchNote => 'Abazali bafaka i-50% yokhu ozigciniyela';

  @override
  String get earnings => 'imvuzo';

  @override
  String get logEarning => 'Bhala imvuzo';

  @override
  String get myProposals => 'iziphakamiso zami';

  @override
  String get proposeExpense => 'Phakamisa isondlo';

  @override
  String get proposeTitle => 'Cela imali esondweni';

  @override
  String get peek => 'Abazali bakuvumele ukhu ubone lokhu';

  @override
  String get plan => 'Uhlelo: sebenzisa · gcina · nikela';

  @override
  String get settingsTitle => 'Izilungiselelo';

  @override
  String get remindersOnDevice => 'Izikhumbuzo kule foni';

  @override
  String get remindersSubtitle =>
      'imali ephindaphindayo, ibhajeti, izingane, izinhloso, umkhando & omhlangano';

  @override
  String get quietHours =>
      'Amahla okuthula (azikho izikhumbuzo phakathi kwawo)';

  @override
  String get monthStartsOn => 'Inyanga iqala ngosuku';

  @override
  String get language => 'Ulimi';

  @override
  String get largeText => 'Umbhalo omkhulu (ukufunda okulula)';

  @override
  String get exportCsvSettings => 'Khipha konke nge-CSV';

  @override
  String get comingSoon => 'Kuza kungekudala';

  @override
  String get remindersTitle => 'Izikhumbuzo';

  @override
  String scheduledOn(String from, String to) {
    return 'Kulungisiwe kule foni · amahla okuthula $from–$to';
  }

  @override
  String get remindersOff => 'Izikhumbuzo zivaliwe';

  @override
  String get nothingComing => 'Akukho okuzayo';

  @override
  String get ob1Title => 'imali, siphethe sonke';

  @override
  String get ob1Body =>
      'Indawo eyodwa ethethekayo yazo zonke izinto umndeni ozuzayo, ezichithayo, ezigcinayo nezahlela — ngazo zonke izimali ozisebenzisayo, online noma cha.';

  @override
  String get ob2Title => 'Amabhajethi, cha ukuzilahla';

  @override
  String get ob2Body =>
      'Nika idola ngalinye umsebenzi walo. Okutya, imali yesikolo, ezokuthutha — bona ngeso lesibhamu okuhamba kahle, okudinga ukugcwaliswa, nokuphephile ukusebenzisa namhlanje.';

  @override
  String get ob3Title => 'Yakhiwe yonke imndeni';

  @override
  String get ob3Body =>
      'Abazali bangabhani bahlela ndawonye. Izingane zikhulela emalenini nasezinkwenkweni. Abasha baphakamisa izondlo bafunda ngokufananisa ukugcina. Ugogo ugcina ibhuku lomkhando.';

  @override
  String get ob4Title => 'Okukhumbuza okuthambile';

  @override
  String syncPill(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count utshintsho olugciniwele kwesi sixhobo — kuhlanganiswa xa kukho internet',
    );
    return '$_temp0';
  }

  @override
  String get hideAmountsTip => 'Fihla amanani';

  @override
  String get showAmountsTip => 'Bonisa amanani';

  @override
  String get themeLabel => 'Uhlolojikelezo';

  @override
  String get themeSystem => 'Isistim';

  @override
  String get themeLight => 'Okumhlophe';

  @override
  String get themeDark => 'Okumnyama';

  @override
  String get sixMonthNet => 'Isango seinyanga 6 (USD)';

  @override
  String get donutEmpty =>
      'Akukho zitchitho zirekhodiweyo kule nyanga — idonuti ialala kudityaniswa.';

  @override
  String get ob4Body =>
      'Izikhumbuzo zezimali, ukubukelelwa kwesabelomali nomhlangano wesonto — kuhlonishwa amahora okuthula, kukhofoni yakho. Wena ulawula.';

  @override
  String get next => 'Okulandelayo';

  @override
  String get loginWelcome => 'Wamukeleke kuMhuri Hub';

  @override
  String get loginEnterCode => 'Faka ikhodi';

  @override
  String loginSentCode(String phone) {
    return 'Sithumele ikhodi ngeSMS ku$phone';
  }

  @override
  String get loginSignInHint =>
      'Ngena ngofono yakho ukuvula isikhala somndeni wakho.';

  @override
  String get loginSendCode => 'Thumela ikhodi';

  @override
  String get loginVerify => 'Qinisekisa & ngena';

  @override
  String get loginChangeNumber => 'Shintsha inombolo';

  @override
  String get loginBadPhone =>
      'Faka inombolo esebenzayo (isb. +44 7700 900123).';

  @override
  String get loginFooter =>
      'I-demo: noma yimuphi umfanekiso, ikhodi 1234.\nI-live ithumela ikhodi yeSMS yangempela.';

  @override
  String get quickAddTitle => 'Engeza okusheshayo';

  @override
  String get expense => 'Isabelomali';

  @override
  String get envelopeLabel => 'Ikhava';

  @override
  String get whoLabel => 'Ubani';

  @override
  String get paidWithLabel => 'Khokhiwe nge';

  @override
  String get noteHint => 'Ithiphu (isb. FreshMart)';

  @override
  String get enterAmountFirst => 'Faka isabelomali kuqala';

  @override
  String get savedOffline =>
      'Kulondoloziwe ✓ — isebenza ngaphandle kwe-inthanethi, ihlangana kusasa';

  @override
  String kidsHi(String name) {
    return 'Sawubona $name!';
  }

  @override
  String get kidsMyJar => 'Isigqi sami';

  @override
  String kidsGoalSaved(String goal, int pct) {
    return 'Inhloso: $goal — $pct% kilondoloziwe';
  }

  @override
  String get kidsMyChores => 'Izimpahla zami';

  @override
  String get kidsWishList => 'Uhlu zifiso';

  @override
  String kidsWishItem(String amount) {
    return 'Ibhola — US\$25 · kilondoloziwe $amount';
  }

  @override
  String get kidsAskMoney => 'Cela ku\nmama nobaba';

  @override
  String get kidsDoChore => 'Yenza umsebenzi';

  @override
  String get kidsAllDone => 'Konke kwenziwe!';

  @override
  String get kidsParents => 'Abazali';

  @override
  String get kidsAskTitle => 'Cela ku mama no baba';

  @override
  String get kidsWhatFor => 'Ngenzeni?';

  @override
  String get kidsDefaultReason => 'Imali yesandla';

  @override
  String get teenZoneTitle => 'Indawo yabantwana · 13–17';

  @override
  String get teenNoEarnings => 'Akukho malari kurekhodiwe';

  @override
  String get teenEarnHint =>
      'Gezaimoto, siza emaveni — bhala ubone isigqi sikhula.';

  @override
  String get teenSpend => 'Chitha 50%';

  @override
  String get teenSave => 'Londoloza 40%';

  @override
  String get teenGive => 'Nika 10%';

  @override
  String teenSplitHint(String amount) {
    return 'Ukwahlukaniswa kwe$amount okutholakele kule nyanga';
  }

  @override
  String get teenSavedJar => 'Kulondoloziwe esigqini — abazali balingana 50%';

  @override
  String get teenWhatDid => 'Wenzani?';

  @override
  String get familyTitle => 'Umndeni';

  @override
  String get membersDesc => 'Abazali nezingane · inyanga iqala ngo-1';

  @override
  String get membersInviteHint =>
      'Yabelana ngekhodi noma skanela ubize umndeni';

  @override
  String get membersDemoTip =>
      'Icebo: sebenzisa \"View as\" ukushintsha iphrofayili. Izingane zingena endaweni evalwe.';

  @override
  String get setCurrency => 'Imali & izinga';

  @override
  String setCurrencySub(String rate) {
    return 'USD eyinhloko · ZiG yesibili · $rate';
  }

  @override
  String get setPrivacy => 'Okuyimfihlo';

  @override
  String get setPrivacySub =>
      'Amakhava siqu: cha — umlingani ubona okwabiwe kuphela';

  @override
  String get setMonthStart => 'Ukuqala kwenyanga';

  @override
  String get setMonthStartSub => 'Usuku 1 — kuhambisana nomjikelezo wemholo';

  @override
  String get setNotif => 'Izaziso';

  @override
  String get setNotifSub => 'Isexwayiso 80% · amabhandleri · izicelo zezingane';

  @override
  String get setBackup => 'Ibackup & ukukhipha';

  @override
  String get setBackupSub =>
      'Ibackup efihlakele · ukukhipha kwe-CSV (umnikazi)';

  @override
  String get meetingTitle => 'Umhlangano womndeni';

  @override
  String get mFigures => 'Inyanga edlule, ngamanani';

  @override
  String get figureIncome => 'Okungenayo';

  @override
  String get figureSpent => 'Okuchithiwe';

  @override
  String get figureSaved => 'Okulondoloziwe';

  @override
  String get mEnvelopeHealth => 'Umpilakahle wezikhava';

  @override
  String get mReachedTalk =>
      'Khuluma ngezikhava ezithi \"Kufinyelele\". Zigcwaliseni ndawonye, ngokuthula.';

  @override
  String get mGoals => 'Izinhloso zokulondoloza';

  @override
  String get mChores => 'Izimpahla, izigqi & izicelo';

  @override
  String get mImprove => 'Into eyodwa yokuthuthukisa';

  @override
  String recSkipped(String date) {
    return 'Kweyekiwe — elandelayo: $date';
  }

  @override
  String get recNew => 'Isabelomali esiphindaphindayo';

  @override
  String get recReview =>
      'Akukho okuthathiwa ngokuzenzakalela — wena uhlole ubhale konke.';

  @override
  String get recNoEnvelope => 'Ayikho ikhava';

  @override
  String get recNextDue => 'Elandelayo:';

  @override
  String get recNameAmount => 'Nika igama nesabelomali';

  @override
  String get recSaveRule => 'Londoloza umthetho';

  @override
  String get recNameHint => 'Igama (isb. Imali yesikole)';

  @override
  String get roleOwner => 'Umnikazi';

  @override
  String get roleAdult => 'Omdala';

  @override
  String get roleTeen => 'Intsha';

  @override
  String get roleKid => 'Ingane';

  @override
  String get roleViewer => 'UGogo · Obukelayo';

  @override
  String get methodCash => 'Imali eqinile';

  @override
  String get methodMobile => 'Imali yeselula';

  @override
  String get methodCard => 'Ikhadi';

  @override
  String get methodTransfer => 'Ukudlulisa';

  @override
  String get methodAgent => 'I-ejenti / iphoyinti leimali';

  @override
  String get methodOther => 'Okunye';

  @override
  String get stateToBuy => 'Okuzothengwa';

  @override
  String get stateInCart => 'Ekota';

  @override
  String get stateDone => 'Kwenziwe';

  @override
  String get freqWeekly => 'Ngesonto';

  @override
  String get freqMonthly => 'Ngenyanga';

  @override
  String get rollReset => 'Qala kabusha ngenyanga';

  @override
  String get rollRoll => 'Dlulisela okusele';

  @override
  String get rollAccum => 'Yonga okusele';

  @override
  String get freqTerm => 'Ngesikhashana (~inyanga 3)';

  @override
  String get budgetsTitle => 'Izabelomali';

  @override
  String get noEnvelopes => 'Azikho izikhava okusalayo';

  @override
  String get envelopesHint =>
      'Izikhava yizabelomali ozibonayo: ukudla, isikole, ezokuthutha. Yenza eyokuqala ngezansi.';

  @override
  String get newEnvStub => 'Ikhava entsha — izayo (isigaba 1)';

  @override
  String get addRecurringTip => 'Engeza isabelomali ephindaphindayo';

  @override
  String get recReviewed =>
      'Ihlolwa ngaphambi kokubhala — akukho okuthathiwa thula.';

  @override
  String get noRecurring => 'Azikho izabelomali eziphindaphindayo okuqala';

  @override
  String get recurringHint =>
      'Engeza imithetho yesikole, carenselo noma airtime — sikukhumbuza uma sekufike isikhathi.';

  @override
  String get chipOnTrack => 'Kulungile';

  @override
  String get chipReached => 'Kufikelelwe';

  @override
  String get remaining => 'Okusele';

  @override
  String get moveMoney => 'Hambisa imali';

  @override
  String get pickFirst => 'Khetha amakhava nesabelomali kuqala';

  @override
  String get skipPeriod => 'Yeqa lesi sikhathi';

  @override
  String get pauseRule => 'Misa umthetho';

  @override
  String get resumeRule => 'Qalisa kabusha umthetho';

  @override
  String get meetingHint => 'Amaminithi 15, kanye ngenyanga.';

  @override
  String mChoresLine(Object proposals, Object requests, Object stars) {
    return '$stars izigqi ezitholiwe · $requests izicelo ezilindile · $proposals iziphakamiso zentsha ezilindile.';
  }

  @override
  String get meetingNoteHint =>
      'isb. \"Pheka ngemihlobo — imali yemakethe iyakhuphuka.\"';

  @override
  String get meetingSaveNote => 'Gcina ithiphu lethu';

  @override
  String get savedTick => 'Kugcinwe ✓';

  @override
  String get meetingDone => 'Kwenziwe — sobonana ngenyanga ezayo';

  @override
  String get reportCard => 'Ikhardi lembiko';

  @override
  String get recentActivity => 'Okwenzile usanda';

  @override
  String get swapCurrency => 'Shintsha imali eboniswayo';

  @override
  String get yourChild => 'Ingane yakho';

  @override
  String get review => 'Bheka';

  @override
  String get confirm => 'Qinisekisa';

  @override
  String get markCollected => 'Phawula uthathiwe';

  @override
  String get decline => 'Yala';

  @override
  String get sentToParents => 'Kuthunyelwe ku mama no baba';

  @override
  String get sendRequest => 'Thumela isicelo';

  @override
  String get parentsOnly => 'Abazali kuphela';

  @override
  String get pinExitLine =>
      'Faka iphinikhodi yakho ukuphuma endaweni yezingane.';

  @override
  String get wrongPin => 'Iphinikhodi ayilona';

  @override
  String get unlock => 'Vula';

  @override
  String get addItem => 'Engeza into';

  @override
  String get listSharedSub => 'Uhle lokuthenga lomndeni · lwabiwe nabo bonke';

  @override
  String get tickFirst => 'Qala uphawule izinto';

  @override
  String get namePriceFirst => 'Nika into igama nentengo';

  @override
  String get addToList => 'Engeza kuhlu';

  @override
  String get spaceSetup => 'Hlela isikhala somndeni wakho';

  @override
  String get spaceSetupSub =>
      'Yenza isikhala somndeni wakho, noma ngena kulowo owadala umlingani ngekhodi yakhe. Konke okubhala kuhlangana phakathi kwezofoni zenu.';

  @override
  String get createSpace => 'Yenza isikhala';

  @override
  String get joinWithCode => 'Ngena ngekhodi';

  @override
  String get offlineRetry => 'Nge-inthanethi — izazama yodwa';

  @override
  String get syncProblem => 'Inkinga yokuhlanganisa';

  @override
  String get signinExpired => 'Ukungena kuphelelwe — phuma ubuyele';

  @override
  String get syncing => 'Iyahlanganisa…';

  @override
  String lastSync(Object last) {
    return 'Ukuhlanganisa kwokugcina: $last';
  }

  @override
  String get familySpace => 'Isikhala somndeni';

  @override
  String get syncNow => 'Hlanganisa manje';

  @override
  String get createFamilySpace => 'Yenza isikhala somndeni';

  @override
  String get familyName => 'Igama lomndeni';

  @override
  String get localizedNote =>
      'I-app yonke manje ikhuluma izilimi eziyisithupha — azisalayo izinkomba zesiNgisi.';

  @override
  String get nextCreateSpace =>
      'Okulandelayo: yenza isikhala somndeni (noma ngena ngekhodi) kuthabhu lomndeni.';

  @override
  String reachedMove(Object on, Object total) {
    return '$on kwezikhava ezingu$total zisakulungile. Vula ezithi \"Kufikelelwe\" uhambise imali — ngokuthula, hhayi ngokuphelele.';
  }

  @override
  String get cashTrace =>
      'Imali eqinile ilula ukuyichitha,inzima ukuyilandela. Ukukhokha ngemali yeselula noma ikhadi kugcina isithombe sicacile.';

  @override
  String get whereMoneyWent => 'Imali yahamba ngaphi';

  @override
  String get exportFailed => 'Ukukhipha kwehluleke ocansini';

  @override
  String csvSaved(Object path) {
    return 'I-CSV igcinwe: $path';
  }

  @override
  String exportedPath(Object path) {
    return 'Kukhishiwe ✓ $path';
  }

  @override
  String get bringToMeeting => 'Leza lokhu kumhlangano womndeni wonyaka';

  @override
  String get savingsTitle => 'Ukulondoloza';

  @override
  String get markRound => 'Phawula uthathiwe';

  @override
  String get recordsOnly =>
      'I-Mhuri Hub ayisoze yagcina imali — ibhala kuphela.';

  @override
  String get saveContribution => 'Gcina isabelo';

  @override
  String get sendTest => 'Thumela isaziso sokuhlolwa';

  @override
  String get testOk => 'Izikhumbuzo zisebenza ocansini.';

  @override
  String get monthCycle => 'Umjikelezo wenyanga';

  @override
  String get paydayAlign =>
      'Izabelomali zihambisana nomholo — umjikelezo uqala ngalolusuku futhi isikhumbuzo somhlangano sifika ngobusuku ngaphambili';

  @override
  String get backupComing => 'Ibackup & ukubuyisa (izayo)';

  @override
  String get fromLabel => 'Kusuka';

  @override
  String get addTransaction => 'Engeza umsebenziswano';

  @override
  String get logWhatAmount => 'Engeza okwenzile nesabelomali';

  @override
  String get logIt => 'Bhala';

  @override
  String get fromEnvelope => 'Esikhaveni';

  @override
  String get amountPurposeFirst => 'Faka isabelomali nokuyenzelwe';

  @override
  String get sentApproval => 'Kuthunyelwe ku mama no baba ukuyamukelwa';

  @override
  String get sendProposal => 'Thumela isiphakamiso';

  @override
  String get stWaiting => 'Silinde ⏳';

  @override
  String get stApproved => 'Kuvunyelwe ✓';

  @override
  String get stDeclined => 'Kwenqatshiwe';

  @override
  String requestTitle(Object amount, Object name) {
    return '$name ucele $amount';
  }

  @override
  String proposalTitle(Object amount, Object name) {
    return '$name uphakamisa $amount';
  }

  @override
  String proposalSub(Object env, Object reason) {
    return '$reason · esikhaveni $env';
  }

  @override
  String recDueSub(Object when) {
    return 'Ephindaphindayo · ifika $when · bhala usukhokhile';
  }

  @override
  String get dueNow => 'manje';

  @override
  String get dueSoon => 'masinyane';

  @override
  String choreDoneTitle(Object name) {
    return '\"$name\" kwenziwe — qinisekisa?';
  }

  @override
  String choreDoneSub(Object stars) {
    return '$stars izigqi — qinisekisa isigqi sikhule';
  }

  @override
  String circleSub(Object amount, Object pot, Object who) {
    return '$who uzothatha $amount · isigqi $pot okwamanje';
  }

  @override
  String get exportReal => 'Ukukhipha kusebenza ocansini wangempela';

  @override
  String get allSynced => '✓ Konke kuhlanganisiwe';

  @override
  String get familyCta => 'Umndeni ›';

  @override
  String get recentInEnv => 'Okusanda kulekhava';

  @override
  String get nothingLogged => 'Akukho okubhaliwe lapha okuqala.';

  @override
  String dueBy(Object days) {
    return 'Sephuthe $days izinsuku';
  }

  @override
  String get dueToday => 'ifika namuhla';

  @override
  String get dueTomorrow => 'ifika kusasa';

  @override
  String dueIn(Object days) {
    return 'ifika ezinsukwini ezingu$days';
  }

  @override
  String circleTitle(Object round, Object total) {
    return 'Isigqi sokulondoloza — Isigaba $round esi$total';
  }

  @override
  String postedSnack(Object name) {
    return '$name kubhaliwe ✓ — ikhava ivuselelwe';
  }

  @override
  String starsGiven(Object stars) {
    return '$stars izigqi zinikezwe izingane!';
  }

  @override
  String approvedReq(Object amount, Object name) {
    return 'Kuvunyelwe ✓ — kengezwe ku$name';
  }

  @override
  String declineBody(Object env, Object reason) {
    return '$reason\n\nEsikhaveni: $env';
  }

  @override
  String approvedProp(Object amount, Object env) {
    return 'Kuvunyelwe ✓ — $amount kubhaliwe ku$env';
  }

  @override
  String sentKid(Object name) {
    return '\"$name\" kuthunyelwe ku mama no baba';
  }

  @override
  String get listEmptyAdd => 'Akukho lapha — engeza into nge ＋';

  @override
  String usesPct(Object name, Object pct) {
    return 'Isebenzisa $pct% yekhava ye$name';
  }

  @override
  String loggedTo(Object amount, Object name) {
    return 'Kubhaliwe $amount ku$name ✓ — ikhava ivuselelwe';
  }

  @override
  String get finishShop => 'Qedea ukuthenga → bhala isabelomali';

  @override
  String estPrice(Object symbol) {
    return 'Intengo eyilinganiselwe ($symbol)';
  }

  @override
  String get myFamily => 'Umndeni wami';

  @override
  String spaceCreated(Object code) {
    return 'Isikhala senziwe ✓ Ikhodi yesimemo: $code';
  }

  @override
  String get createFail => 'Ayikwazi ukudala isikhala — zama futhi';

  @override
  String get joinSpaceTitle => 'Ngena isikhala somndeni';

  @override
  String get inviteCode => 'Ikhodi yesimemo';

  @override
  String get joinedOk => 'Kungeniwe ✓ — idatha yakho iyahlangana';

  @override
  String get joinFail => 'Ayikwazi ukungena — zama futhi';

  @override
  String get kidsPin => 'Iphinikhodi yokuphuma endaweni yezingane';

  @override
  String get kidsPinSub =>
      'Idingekha ukuphuma endaweni yezingane — thepha ukushintsha';

  @override
  String signedInAs(Object masked) {
    return 'Kungeniwe: $masked';
  }

  @override
  String get signOut => 'Phuma';

  @override
  String get viewAs => 'Bheka nje';

  @override
  String cashShare(Object pct) {
    return '$pct% yokuchithwa';
  }

  @override
  String donutA11y(Object name, Object share) {
    return 'Okuchithiwe ngekhava, $name ekhethiwe, $share iphesenti';
  }

  @override
  String starsHome(Object stars) {
    return '$stars izigqi — qinisekisa izimpahla ekhaya ukhazigqi zikhule';
  }

  @override
  String circleMember(Object name) {
    return 'Isigqi sokulondoloza · $name';
  }

  @override
  String potSoFar(Object pot) {
    return 'Isigqi okwamanje: $pot';
  }

  @override
  String get roundOk => 'Isigaba sibhaliwe ✓ — sibhala kuphela, asigcini imali';

  @override
  String addToGoal(Object name) {
    return 'Engeza ku$name';
  }

  @override
  String addedToGoal(Object name) {
    return 'Kengeziwe ku$name';
  }

  @override
  String goalBase(Object short) {
    return 'Isisekelo senhloso: $short';
  }

  @override
  String syncTime(Object t) {
    return 'namuhla nga$t';
  }

  @override
  String get watch => 'Bheka';

  @override
  String get spentLabel => 'Okuchithiwe';

  @override
  String get limitLabel => 'Umkhawulo';

  @override
  String memberPot(Object contribution, Object count, Object pot) {
    return 'Isigqi okwamanje: $pot · $contribution × $count abantu';
  }

  @override
  String get switchProfile => 'Shintsha iphrofayili';

  @override
  String get switchProfileSub => 'Bona i-app njengelinye lilunga lomndeni';

  @override
  String get youTag => 'Wena';

  @override
  String get pickCurrency => 'Imali eboniswayo';

  @override
  String get rateField => 'ZiG ngo-1 USD';

  @override
  String get rateSave => 'Gcina izinga';

  @override
  String get rateReset => 'Buyela kuRBZ yokuqala';

  @override
  String get rateCustomNote =>
      'Isetshenziselwa ukubuka amaZiG ku-app yonke. EyRBZ yokuqala ngu-15,27.';

  @override
  String get autoHide => 'Fihla imali ngapha ngiphuma';

  @override
  String get autoHideSub =>
      'Izibalo ziyafihlana i-app iya ngasemuva — yivala ungathanda.';

  @override
  String get hideNow => 'Fihla imali manje';

  @override
  String get exportCsvRow => 'Khipha wonke umsebenziswano (CSV)';

  @override
  String get copyInvite => 'Kopisha ikhodi yesimemo';

  @override
  String get copied => 'Kukopishiwe ✓';

  @override
  String get inviteTitle => 'Memela ilunga lomndeni';

  @override
  String get inviteDemoNote =>
      'I-demo iza nomndeni omkhombiselwe. Ku-live ikhodi yakho yesimemo ihlala lapha — yabelana ngayo umndeni unge esikhaleni sakho.';

  @override
  String get editProfile => 'Hlela iphrofayili';

  @override
  String get editProfileSub => 'Igama nesithombe salendlu';

  @override
  String get photoNote =>
      'Izithombe zephrofayili ziza nohlanganiselo lomndeni. Ama-avatar asekwilapha.';

  @override
  String get accountTitle => 'I-akhawunti';

  @override
  String get deleteAccount => 'Susa i-akhawunti';

  @override
  String get deleteAccountTitle => 'Ususe i-akhawunti yakho?';

  @override
  String get deleteAccountBody =>
      'Lokhu kususa ngokupheleleyo ukungena kwakho ledatha yemali egcinwe kule divayisi. Akubuyiseki.';

  @override
  String get deleteAccountConfirm => 'Susa ngokupheleleyo';

  @override
  String get deleteAccountFailed =>
      'Asikwazanga ukususa i-akhawunti. Hlola inthanethi uzame futhi.';
}
