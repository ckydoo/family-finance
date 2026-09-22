// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get tabHome => 'Accueil';

  @override
  String get tabBudgets => 'Budgets';

  @override
  String get tabSavings => 'Épargne';

  @override
  String get tabLists => 'Listes';

  @override
  String get tabFamily => 'Famille';

  @override
  String get tabActivity => 'Activité';

  @override
  String get greetingMorning => 'Bonjour';

  @override
  String get greetingAfternoon => 'Bon après-midi';

  @override
  String get greetingEvening => 'Bonsoir';

  @override
  String get familyPool => 'Cagnotte familiale';

  @override
  String safeToSpend(String amount) {
    return 'Sûr à dépenser aujourd\'hui : $amount';
  }

  @override
  String get seeAll => 'Tout voir';

  @override
  String get add => 'Ajouter';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get undo => 'Annuler';

  @override
  String get post => 'Valider';

  @override
  String get skip => 'Passer';

  @override
  String get approve => 'Approuver';

  @override
  String get notThisWeek => 'Pas cette semaine';

  @override
  String get done => 'Terminé';

  @override
  String get export => 'Exporter';

  @override
  String get meeting => 'Réunion';

  @override
  String get newEnvelope => 'Nouvelle enveloppe';

  @override
  String get recurringExpenses => 'Dépenses récurrentes';

  @override
  String get shopping => 'Courses';

  @override
  String get activityTitle => 'Activité';

  @override
  String get noActivityTitle => 'Pas encore d\'activité';

  @override
  String get noActivityHint =>
      'Chaque dépense, revenu et approbation apparaît ici — ajoutez le premier avec le bouton +.';

  @override
  String get noGoals => 'Pas encore d\'objectifs';

  @override
  String get noGoalsHint =>
      'Commencez par un fonds d\'urgence — même un peu chaque semaine change la manière de vivre les imprévus.';

  @override
  String get reportTitle => 'Bulletin familial';

  @override
  String get income => 'Revenu';

  @override
  String get spent => 'Dépensé';

  @override
  String get saved => 'Économisé';

  @override
  String get safePerDay => 'Sûr / jour';

  @override
  String get envelopeHealth => 'Santé des enveloppes';

  @override
  String get cashLeak => 'Fuites en espèces';

  @override
  String get shareReport => 'Partager avec la famille';

  @override
  String get meetingCta => 'Lancer la réunion de famille';

  @override
  String get exportCsv => 'Exporter les transactions (CSV)';

  @override
  String get family => 'Famille';

  @override
  String get hi => 'Salut';

  @override
  String get mySavings => 'Mon épargne';

  @override
  String get addToJar => 'Ajouter au bocal';

  @override
  String get savingsMatch => 'Épargne jumelée';

  @override
  String get savingsMatchNote =>
      'Les parents égalent 50% de tout ce que tu épargnes';

  @override
  String get earnings => 'Gains';

  @override
  String get logEarning => 'Noter un gain';

  @override
  String get myProposals => 'Mes propositions';

  @override
  String get proposeExpense => 'Proposer une dépense';

  @override
  String get proposeTitle => 'Proposer une dépense';

  @override
  String get peek => 'Tes parents te laissent voir cette enveloppe';

  @override
  String get plan => 'Plan : Dépenser · Épargner · Donner';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get remindersOnDevice => 'Rappels sur cet appareil';

  @override
  String get remindersSubtitle =>
      'Factures, budgets, enfants, objectifs, cercles d\'épargne et réunions';

  @override
  String get quietHours =>
      'Heures calmes (pas de notifications pendant cette plage)';

  @override
  String get monthStartsOn => 'Le mois commence le';

  @override
  String get language => 'Langue';

  @override
  String get largeText => 'Texte agrandi (plus facile à lire)';

  @override
  String get exportCsvSettings => 'Exporter les transactions (CSV)';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get remindersTitle => 'Rappels';

  @override
  String scheduledOn(String from, String to) {
    return 'Programmé sur cet appareil · heures calmes $from–$to';
  }

  @override
  String get remindersOff => 'Rappels désactivés';

  @override
  String get nothingComing => 'Rien à l\'horizon';

  @override
  String get ob1Title => 'L\'argent, géré ensemble';

  @override
  String get ob1Body =>
      'Un endroit paisible pour tout ce que votre famille gagne, dépense, épargne et planifie — dans toutes vos monnaies, en ligne ou hors ligne.';

  @override
  String get ob2Title => 'Des enveloppes, pas de culpabilité';

  @override
  String get ob2Body =>
      'Donnez un rôle à chaque dollar. Courses, école, transport — voyez d\'un coup d\'œil ce qui va bien, ce qui a besoin d\'un coup de pouce, et ce qui est sûr à dépenser aujourd\'hui.';

  @override
  String get ob3Title => 'Conçu pour toute la famille';

  @override
  String get ob3Body =>
      'Les partenaires partagent le plan. Les enfants remplissent des bocaux et gagnent des étoiles. Les ados proposent des dépenses et apprennent avec l\'épargne jumelée. La grand-mère tient le registre du cercle d\'épargne.';

  @override
  String get ob4Title => 'Des rappels doux';

  @override
  String syncPill(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count modifications enregistrées sur cet appareil — synchronisation une fois en ligne',
      one:
          '1 modification enregistrée sur cet appareil — synchronisation une fois en ligne',
    );
    return '$_temp0';
  }

  @override
  String get hideAmountsTip => 'Masquer les montants';

  @override
  String get showAmountsTip => 'Afficher les montants';

  @override
  String get themeLabel => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get sixMonthNet => 'Solde sur 6 mois (USD)';

  @override
  String get donutEmpty =>
      'Aucune dépense ce cycle — le anneau se remplit à chaque dépense ajoutée.';

  @override
  String get ob4Body =>
      'Factures, budget et le résumé familial hebdomadaire — heures calmes respectées, sur votre téléphone. Vous gardez le contrôle.';

  @override
  String get next => 'Suivant';

  @override
  String get loginWelcome => 'Bienvenue sur Mhuri Hub';

  @override
  String get loginEnterCode => 'Saisissez le code';

  @override
  String loginSentCode(String phone) {
    return 'Nous avons envoyé un code par SMS au $phone';
  }

  @override
  String get loginSignInHint =>
      'Connectez-vous avec votre e-mail pour ouvrir votre espace familial.';

  @override
  String get loginSendCode => 'Envoyer le code';

  @override
  String get loginVerify => 'Vérifier et se connecter';

  @override
  String get loginChangeNumber => 'Changer de numéro';

  @override
  String get loginBadPhone => 'Entrez un numéro valide (ex. +44 7700 900123).';

  @override
  String get quickAddTitle => 'Ajout rapide';

  @override
  String get expense => 'Dépense';

  @override
  String get envelopeLabel => 'Enveloppe';

  @override
  String get whoLabel => 'Qui';

  @override
  String get paidWithLabel => 'Payé avec';

  @override
  String get noteHint => 'Note (ex. FreshMart)';

  @override
  String get enterAmountFirst => 'Entrez d\'abord un montant';

  @override
  String get savedOffline =>
      'Enregistré ✓ — fonctionne hors ligne, se synchronise dès que possible';

  @override
  String kidsHi(String name) {
    return 'Salut $name !';
  }

  @override
  String get kidsMyJar => 'Mon pot';

  @override
  String kidsGoalSaved(String goal, int pct) {
    return 'Objectif : $goal — $pct% épargné';
  }

  @override
  String get kidsMyChores => 'Mes tâches';

  @override
  String get kidsWishList => 'Liste d\'envies';

  @override
  String kidsWishItem(String amount) {
    return 'Ballon — US\$25 · épargné $amount';
  }

  @override
  String get kidsAskMoney => 'Demande\nà papa/maman';

  @override
  String get kidsDoChore => 'Faire une tâche';

  @override
  String get kidsAllDone => 'Tâches terminées !';

  @override
  String get kidsParents => 'Parents';

  @override
  String get kidsAskTitle => 'Demander à papa & maman';

  @override
  String get kidsWhatFor => 'Pour quoi ?';

  @override
  String get kidsDefaultReason => 'Argent de poche';

  @override
  String get teenZoneTitle => 'Zone ados · 13–17';

  @override
  String get teenNoEarnings => 'Aucun gain enregistré';

  @override
  String get teenEarnHint =>
      'Lave une voiture, rends service — note-le et regarde ton pot grandir.';

  @override
  String get teenSpend => 'Dépenser 50%';

  @override
  String get teenSave => 'Épargner 40%';

  @override
  String get teenGive => 'Donner 10%';

  @override
  String teenSplitHint(String amount) {
    return 'Répartition suggérée des $amount gagnés ce mois';
  }

  @override
  String get teenSavedJar =>
      'Épargné dans ton pot — les parents complètent 50%';

  @override
  String get teenWhatDid => 'Qu\'as-tu fait ?';

  @override
  String get familyTitle => 'Famille';

  @override
  String get membersDesc => 'Couple + enfants · le mois commence le 1er';

  @override
  String get membersInviteHint =>
      'Partagez le code ou scannez pour inviter un proche';

  @override
  String get setCurrency => 'Devise et taux';

  @override
  String setCurrencySub(String rate) {
    return 'USD principal · ZiG secondaire · $rate';
  }

  @override
  String get setPrivacy => 'Confidentialité';

  @override
  String get setPrivacySub =>
      'Pochettes privées : non — le partenaire ne voit que le partagé';

  @override
  String get setMonthStart => 'Début du mois';

  @override
  String get setMonthStartSub => 'Le 1er — aligné sur le cycle de salaire';

  @override
  String get setNotif => 'Notifications';

  @override
  String get setNotifSub =>
      'Alerte budget 80% · factures · demandes des enfants';

  @override
  String get setBackup => 'Sauvegarde et export';

  @override
  String get setBackupSub => 'Sauvegarde chiffrée · export CSV (propriétaire)';

  @override
  String get meetingTitle => 'Réunion de famille';

  @override
  String get mFigures => 'Le mois dernier, en chiffres';

  @override
  String get figureIncome => 'Revenus';

  @override
  String get figureSpent => 'Dépensé';

  @override
  String get figureSaved => 'Épargné';

  @override
  String get mEnvelopeHealth => 'Santé des enveloppes';

  @override
  String get mReachedTalk =>
      'Parlez des enveloppes « Atteintes ». Complétez-les ensemble, sereinement.';

  @override
  String get mGoals => 'Objectifs d\'épargne';

  @override
  String get mChores => 'Tâches, pots et demandes';

  @override
  String get mImprove => 'Une chose à améliorer';

  @override
  String recSkipped(String date) {
    return 'Ignoré — prochain : $date';
  }

  @override
  String get recNew => 'Nouvelle dépense récurrente';

  @override
  String get recReview =>
      'Rien n\'est débité automatiquement — vous validez tout.';

  @override
  String get recNoEnvelope => 'Sans enveloppe';

  @override
  String get recNextDue => 'Prochaine échéance :';

  @override
  String get recNameAmount => 'Donnez un nom et un montant';

  @override
  String get recSaveRule => 'Enregistrer la règle';

  @override
  String get recNameHint => 'Nom (ex. Frais scolaires)';

  @override
  String get roleOwner => 'Propriétaire';

  @override
  String get roleAdult => 'Adulte';

  @override
  String get roleTeen => 'Ado';

  @override
  String get roleKid => 'Enfant';

  @override
  String get roleViewer => 'Aîné · Observateur';

  @override
  String get methodCash => 'Espèces';

  @override
  String get methodMobile => 'Mobile money';

  @override
  String get methodCard => 'Carte bancaire';

  @override
  String get methodTransfer => 'Virement';

  @override
  String get methodAgent => 'Agent / point espèces';

  @override
  String get methodOther => 'Autre';

  @override
  String get stateToBuy => 'À acheter';

  @override
  String get stateInCart => 'Dans le panier';

  @override
  String get stateDone => 'Fait';

  @override
  String get freqWeekly => 'Hebdo';

  @override
  String get freqMonthly => 'Mensuel';

  @override
  String get rollReset => 'Réinitialiser chaque mois';

  @override
  String get rollRoll => 'Reporter le reste';

  @override
  String get rollAccum => 'Cumuler';

  @override
  String get freqTerm => 'Par trimestre (~3 mois)';

  @override
  String get budgetsTitle => 'Budgets';

  @override
  String get noEnvelopes => 'Pas encore d\'enveloppes';

  @override
  String get envelopesHint =>
      'Les enveloppes sont des budgets visibles : courses, école, transport. Créez la première ci-dessous.';

  @override
  String get newEnvStub => 'Nouvelle enveloppe — bientôt (phase 1)';

  @override
  String get addRecurringTip => 'Ajouter une dépense récurrente';

  @override
  String get recReviewed =>
      'Vérifiée avant validation — rien n\'est débité en silence.';

  @override
  String get noRecurring => 'Pas encore de dépenses récurrentes';

  @override
  String get recurringHint =>
      'Ajoutez écolage, loyer ou crédit — nous vous rappelons à chaque échéance.';

  @override
  String get chipOnTrack => 'Sur la bonne voie';

  @override
  String get chipReached => 'Atteint';

  @override
  String get remaining => 'Restant';

  @override
  String get moveMoney => 'Déplacer de l\'argent';

  @override
  String get pickFirst => 'Choisissez d\'abord des enveloppes et un montant';

  @override
  String get skipPeriod => 'Ignorer cette période';

  @override
  String get pauseRule => 'Mettre en pause';

  @override
  String get resumeRule => 'Reprendre';

  @override
  String get meetingHint => '15 minutes, une fois par mois.';

  @override
  String mChoresLine(Object stars, Object requests, Object proposals) {
    return '$stars étoiles gagnées · $requests demandes en attente · $proposals propositions ado en attente.';
  }

  @override
  String get meetingNoteHint =>
      'ex. « Cuisiner plus le dimanche — les dépenses du marché grimpent. »';

  @override
  String get meetingSaveNote => 'Enregistrer notre note';

  @override
  String get savedTick => 'Enregistré ✓';

  @override
  String get meetingDone => 'Fini — le mois prochain';

  @override
  String get reportCard => 'Bulletin';

  @override
  String get recentActivity => 'Activité récente';

  @override
  String get swapCurrency => 'Changer la devise d\'affichage';

  @override
  String get yourChild => 'Votre enfant';

  @override
  String get review => 'Vérifier';

  @override
  String get confirm => 'Confirmer';

  @override
  String get markCollected => 'Marquer collecté';

  @override
  String get decline => 'Refuser';

  @override
  String get sentToParents => 'Envoyé à papa et maman';

  @override
  String get sendRequest => 'Envoyer la demande';

  @override
  String get parentsOnly => 'Parents seulement';

  @override
  String get pinExitLine =>
      'Saisissez votre code pour quitter le Mode Enfants.';

  @override
  String get wrongPin => 'Code incorrect';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String get addItem => 'Ajouter un article';

  @override
  String get listSharedSub => 'Liste de courses familiale · partagée avec tous';

  @override
  String get tickFirst => 'Cochez d\'abord les articles';

  @override
  String get namePriceFirst => 'Donnez un nom et un prix à l\'article';

  @override
  String get addToList => 'Ajouter à la liste';

  @override
  String get spaceSetup => 'Configurez votre espace familial';

  @override
  String get spaceSetupSub =>
      'Créez un espace pour votre famille ou rejoignez celui de votre partenaire avec son code. Tout ce que vous notez se synchronise entre vos téléphones.';

  @override
  String get createSpace => 'Créer un espace';

  @override
  String get joinWithCode => 'Rejoindre avec un code';

  @override
  String get offlineRetry => 'Hors ligne — nouvelle tentative auto';

  @override
  String get syncProblem => 'Problème de synchronisation';

  @override
  String get signinExpired =>
      'Session expirée — déconnectez-vous puis reconnectez-vous';

  @override
  String get syncing => 'Synchronisation…';

  @override
  String lastSync(Object last) {
    return 'Dernière synchro : $last';
  }

  @override
  String get familySpace => 'Espace familial';

  @override
  String get syncNow => 'Synchroniser';

  @override
  String get createFamilySpace => 'Créer l\'espace familial';

  @override
  String get familyName => 'Nom de la famille';

  @override
  String get localizedNote =>
      'Toute l\'app parle désormais six langues — plus aucun écran en anglais seul.';

  @override
  String get nextCreateSpace =>
      'Ensuite : créez votre espace familial (ou rejoignez avec un code) depuis l\'onglet Famille.';

  @override
  String reachedMove(Object on, Object total) {
    return '$on enveloppes sur $total encore sur la bonne voie. Ouvrez celles marquées « Atteint » et déplacez de l\'argent — sereinement, pas parfaitement.';
  }

  @override
  String get cashTrace =>
      'Les espèces sont faciles à dépenser et difficiles à tracer. Payer un peu plus par mobile money ou carte garde une image plus claire.';

  @override
  String get whereMoneyWent => 'Où est passé l\'argent';

  @override
  String get exportFailed => 'L\'export a échoué sur cet appareil';

  @override
  String csvSaved(Object path) {
    return 'CSV enregistré : $path';
  }

  @override
  String exportedPath(Object path) {
    return 'Exporté ✓ $path';
  }

  @override
  String get bringToMeeting =>
      'Apportez ceci à la Réunion de Famille mensuelle';

  @override
  String get savingsTitle => 'Épargne';

  @override
  String get markRound => 'Marquer la tour collectée';

  @override
  String get recordsOnly =>
      'Mhuri Hub ne garde jamais l\'argent — il ne fait que noter.';

  @override
  String get saveContribution => 'Enregistrer la cotisation';

  @override
  String get sendTest => 'Envoyer une notification de test';

  @override
  String get testOk => 'Les rappels fonctionnent sur cet appareil.';

  @override
  String get monthCycle => 'Cycle du mois';

  @override
  String get paydayAlign =>
      'Budgets alignés sur le salaire — les cycles repartent ce jour-là et le rappel de réunion arrive la veille au soir';

  @override
  String get backupComing => 'Sauvegarde et restauration (bientôt)';

  @override
  String get fromLabel => 'De';

  @override
  String get addTransaction => 'Ajouter une transaction';

  @override
  String get logWhatAmount => 'Ajoute ce que tu as fait et le montant';

  @override
  String get logIt => 'Noter';

  @override
  String get fromEnvelope => 'Depuis l\'enveloppe';

  @override
  String get amountPurposeFirst => 'Ajoute un montant et sa destination';

  @override
  String get sentApproval => 'Envoyé à papa et maman pour approbation';

  @override
  String get sendProposal => 'Envoyer la proposition';

  @override
  String get stWaiting => 'En attente ⏳';

  @override
  String get stApproved => 'Approuvé ✓';

  @override
  String get stDeclined => 'Refusé';

  @override
  String requestTitle(Object name, Object amount) {
    return '$name a demandé $amount';
  }

  @override
  String proposalTitle(Object name, Object amount) {
    return '$name propose $amount';
  }

  @override
  String proposalSub(Object reason, Object env) {
    return '$reason · depuis l\'enveloppe $env';
  }

  @override
  String recDueSub(Object when) {
    return 'Récurrent · échéance $when · validez quand vous le payez';
  }

  @override
  String get dueNow => 'maintenant';

  @override
  String get dueSoon => 'bientôt';

  @override
  String choreDoneTitle(Object name) {
    return '« $name » fait — confirmer ?';
  }

  @override
  String choreDoneSub(Object stars) {
    return '$stars étoiles — confirme pour faire grandir le pot';
  }

  @override
  String circleSub(Object who, Object amount, Object pot) {
    return 'À $who de collecter $amount · cagnotte $pot à ce jour';
  }

  @override
  String get exportReal => 'L\'export fonctionne sur un vrai appareil';

  @override
  String get allSynced => '✓ Tout est synchronisé';

  @override
  String get familyCta => 'Famille ›';

  @override
  String get recentInEnv => 'Récent dans cette enveloppe';

  @override
  String get nothingLogged => 'Rien d\'enregistré ici pour l\'instant.';

  @override
  String dueBy(Object days) {
    return 'en retard de ${days}j';
  }

  @override
  String get dueToday => 'échéance aujourd\'hui';

  @override
  String get dueTomorrow => 'échéance demain';

  @override
  String dueIn(Object days) {
    return 'échéance dans ${days}j';
  }

  @override
  String circleTitle(Object round, Object total) {
    return 'Cercle d\'épargne — Tour $round sur $total';
  }

  @override
  String postedSnack(Object name) {
    return '$name validé ✓ — enveloppe mise à jour';
  }

  @override
  String starsGiven(Object stars) {
    return '$stars étoiles offertes aux enfants !';
  }

  @override
  String approvedReq(Object amount, Object name) {
    return 'Approuvé ✓ — $amount ajouté à $name';
  }

  @override
  String declineBody(Object reason, Object env) {
    return '$reason\n\nDepuis l\'enveloppe : $env';
  }

  @override
  String approvedProp(Object amount, Object env) {
    return 'Approuvé ✓ — $amount noté dans $env';
  }

  @override
  String sentKid(Object name) {
    return '« $name » envoyé à papa et maman';
  }

  @override
  String get listEmptyAdd => 'Rien ici — ajoute un article avec ＋';

  @override
  String usesPct(Object pct, Object name) {
    return 'Utilise $pct% de l\'enveloppe $name';
  }

  @override
  String loggedTo(Object amount, Object name) {
    return '$amount notés dans $name ✓ — enveloppe mise à jour';
  }

  @override
  String get finishShop => 'Finir les courses → noter la dépense';

  @override
  String estPrice(Object symbol) {
    return 'Prix unitaire estimé ($symbol)';
  }

  @override
  String get myFamily => 'Ma famille';

  @override
  String spaceCreated(Object code) {
    return 'Espace créé ✓ Code d\'invitation : $code';
  }

  @override
  String get createFail => 'Impossible de créer l\'espace — réessayez';

  @override
  String get joinSpaceTitle => 'Rejoindre un espace familial';

  @override
  String get inviteCode => 'Code d\'invitation';

  @override
  String get joinedOk => 'Rejoint ✓ — tes données se synchronisent';

  @override
  String get joinFail => 'Impossible de rejoindre — réessaie';

  @override
  String get kidsPin => 'Code de sortie du Mode Enfants';

  @override
  String get kidsPinSub =>
      'Requis pour quitter le Mode Enfants — touche pour changer';

  @override
  String signedInAs(Object masked) {
    return 'Connecté : $masked';
  }

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get viewAs => 'Voir comme…';

  @override
  String cashShare(Object pct) {
    return '$pct% des dépenses';
  }

  @override
  String donutA11y(Object name, Object share) {
    return 'Dépenses par enveloppe, $name sélectionnée, $share pour cent';
  }

  @override
  String starsHome(Object stars) {
    return '$stars étoiles — confirme les tâches sur l\'accueil pour remplir les pots';
  }

  @override
  String circleMember(Object name) {
    return 'Cercle d\'épargne · $name';
  }

  @override
  String potSoFar(Object pot) {
    return 'Cagnotte à ce jour : $pot';
  }

  @override
  String get roundOk =>
      'Tour enregistré ✓ — registre seulement, jamais d\'argent gardé';

  @override
  String addToGoal(Object name) {
    return 'Ajouter à $name';
  }

  @override
  String addedToGoal(Object name) {
    return 'Ajouté à $name';
  }

  @override
  String goalBase(Object short) {
    return 'Base de l\'objectif : $short';
  }

  @override
  String syncTime(Object t) {
    return 'aujourd\'hui à $t';
  }

  @override
  String get watch => 'Attention';

  @override
  String get spentLabel => 'Dépensé';

  @override
  String get limitLabel => 'Plafond';

  @override
  String envelopeRemaining(Object name, Object amount) {
    return 'Il reste $amount dans $name';
  }

  @override
  String envelopeWillLeave(Object amount, Object name) {
    return 'Il restera $amount dans $name';
  }

  @override
  String envelopeWillExceed(Object name, Object amount) {
    return 'Cela dépasse le budget de $name de $amount';
  }

  @override
  String get overBudgetTitle => 'Cette enveloppe dépassera le budget';

  @override
  String overBudgetBody(Object name, Object amount) {
    return '$name dépassera le budget de $amount. Tu peux quand même enregistrer la dépense.';
  }

  @override
  String get adjustAmount => 'Modifier le montant';

  @override
  String get logAnyway => 'Enregistrer quand même';

  @override
  String overBy(Object amount) {
    return 'Dépassé de $amount';
  }

  @override
  String get overBudgetLabel => 'Budget dépassé';

  @override
  String memberPot(Object pot, Object contribution, Object count) {
    return 'Cagnotte : $pot · $contribution × $count membres';
  }

  @override
  String get switchProfile => 'Changer de profil';

  @override
  String get switchProfileSub =>
      'Voir l\'app comme un autre membre de la famille';

  @override
  String get youTag => 'Vous';

  @override
  String get pickCurrency => 'Devise affichée';

  @override
  String get rateField => 'ZiG pour 1 USD';

  @override
  String get rateSave => 'Enregistrer le taux';

  @override
  String get rateReset => 'Revenir à la référence RBZ';

  @override
  String get rateCustomNote =>
      'Utilisée pour la vue ZiG dans toute l\'app. La référence RBZ incluse est 15,27.';

  @override
  String get autoHide => 'Masquer les montants en quittant l\'app';

  @override
  String get autoHideSub =>
      'Les soldes se masquent quand l\'app passe en arrière-plan — désactivez si vous préférez.';

  @override
  String get hideNow => 'Masquer les montants maintenant';

  @override
  String get exportCsvRow => 'Exporter toutes les transactions (CSV)';

  @override
  String get copyInvite => 'Copier le code d\'invitation';

  @override
  String get copied => 'Copié ✓';

  @override
  String get inviteTitle => 'Inviter un membre de la famille';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get editProfileSub => 'Nom et avatar de ce membre';

  @override
  String get photoNote =>
      'Les photos sont envoyées au serveur familial et s\'affichent sur tous les appareils.';

  @override
  String get accountTitle => 'Compte';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountTitle => 'Supprimer votre compte ?';

  @override
  String get deleteAccountBody =>
      'Cette action supprime définitivement votre connexion et les données financières enregistrées sur cet appareil. Elle est irréversible.';

  @override
  String get deleteAccountConfirm => 'Supprimer définitivement';

  @override
  String get deleteAccountFailed =>
      'Impossible de supprimer votre compte. Vérifiez votre connexion et réessayez.';

  @override
  String get moreDetails => 'Plus de détails';

  @override
  String get lessDetails => 'Moins de détails';

  @override
  String get discardTitle => 'Abandonner cette saisie ?';

  @override
  String get discardBody =>
      'Vous avez saisi des détails qui ne sont pas encore enregistrés.';

  @override
  String get keepEditing => 'Continuer la saisie';

  @override
  String get discard => 'Abandonner';

  @override
  String get viewDetails => 'Voir les détails du solde';

  @override
  String get fabTip => 'Touchez + pour noter une entrée ou une sortie';

  @override
  String get emailLabel => 'Adresse e-mail';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get loginSignIn => 'Se connecter';

  @override
  String get loginCreateAccount => 'Créer un compte';

  @override
  String get welcomeBack => 'Bon retour';

  @override
  String get brandTagline => 'L\'ARGENT EN FAMILLE, ENSEMBLE';

  @override
  String get createAccountTitle => 'Crée ton compte';

  @override
  String get createAccountHint =>
      'Crée l\'espace financier sécurisé de ta famille.';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get sendingPasswordReset => 'Envoi…';

  @override
  String get passwordResetSent =>
      'E-mail de réinitialisation envoyé — ouvrez le lien sur ce téléphone et l\'application terminera la réinitialisation.';

  @override
  String get passwordResetFailed =>
      'Impossible d\'envoyer l\'e-mail. Vérifie ta connexion et réessaie.';

  @override
  String get newToMhuri => 'Nouveau sur Mhuri Hub ?';

  @override
  String get alreadyHaveAccount => 'Tu as déjà un compte ?';

  @override
  String get loginBadEmail => 'Saisissez une adresse e-mail valide.';

  @override
  String get loginShortPassword =>
      'Le mot de passe doit contenir au moins 6 caractères.';

  @override
  String get checkYourEmail =>
      'Presque fini — vérifie ta boîte mail et confirme ton e-mail, puis connecte-toi.';

  @override
  String get togglePassword => 'Afficher ou masquer le mot de passe';

  @override
  String get inviteHowTo =>
      'Il crée un compte avec son e-mail, puis saisit ce code pour rejoindre ta famille.';

  @override
  String get obDone => 'C’est parti';

  @override
  String get setupChoiceTitle => 'Configure ta famille';

  @override
  String get setupChoiceBody =>
      'Mhuri Hub marche pour une famille, ensemble. Crée la tienne ou rejoins celle à laquelle tu appartiens.';

  @override
  String get setupCreateCard => 'Créer une famille';

  @override
  String get setupCreateCardBody =>
      'Nomme-la, choisis ton type de foyer et invite les tiens.';

  @override
  String get setupJoinCard => 'Rejoindre avec un code';

  @override
  String get setupJoinCardBody =>
      'Quelqu’un t’a invité — saisis son code famille pour le rejoindre.';

  @override
  String get createFamilyCta => 'Créer la famille';

  @override
  String get joinFamilyCta => 'Rejoindre la famille';

  @override
  String get familyNameLabel => 'Nom de la famille';

  @override
  String get familyNameHint => 'ex. La famille Marufu';

  @override
  String get householdLabel => 'Quel type de famille ?';

  @override
  String get hhCouple => 'Couple avec enfants';

  @override
  String get hhSingle => 'Parent seul';

  @override
  String get hhExtended => 'Famille élargie';

  @override
  String get hhBlended => 'Famille recomposée';

  @override
  String get hhPartners => 'Couple sans enfants';

  @override
  String get hhSolo => 'Juste moi pour l’instant';

  @override
  String get hhOther => 'Autre';

  @override
  String get joinCodeLabel => 'Code d’invitation';

  @override
  String get skipForNow => 'Passer pour l’instant';

  @override
  String get setupInviteTitle => 'Invite les tiens';

  @override
  String get setupWorking => 'On prépare tout…';

  @override
  String get noEnvelopesYet =>
      'Pas encore d’enveloppes — crée la première depuis l’onglet Budgets.';

  @override
  String get noActivityYet =>
      'Rien d’enregistré pour l’instant. Touchez + pour ajouter ta première opération.';

  @override
  String get setupBanner =>
      'Termine la configuration : crée ta famille ou rejoins-en une avec un code';

  @override
  String get setupBannerCta => 'Configurer';

  @override
  String get deleteTypeHint => 'Tape DELETE pour confirmer';

  @override
  String get deletePermanently => 'Supprimer définitivement';

  @override
  String get errInviteCode =>
      'Saisis le code d\'invitation donné par le responsable de la famille — il ressemble à MHRI-4F2A.';

  @override
  String get errFamilyNameTaken =>
      'Ce nom de famille est déjà pris — essaie un autre nom.';

  @override
  String get authErrEmailNotConfirmed =>
      'Vérifie ta boîte mail — touche d\'abord le lien de confirmation, puis connecte-toi.';

  @override
  String get authErrBadCredentials =>
      'L\'e-mail ou le mot de passe est incorrect.';

  @override
  String get authErrAlreadyRegistered =>
      'Un compte existe déjà avec cet e-mail — connecte-toi.';

  @override
  String get authErrRateLimited =>
      'Trop de tentatives — attends une minute et réessaie.';

  @override
  String get authErrNetwork =>
      'Pas de connexion — vérifie ta connexion internet et réessaie.';

  @override
  String get authResend => 'Renvoyer l\'e-mail de confirmation';

  @override
  String get authResent => 'E-mail de confirmation envoyé — vérifie ta boîte.';

  @override
  String get mukandoOn => 'Cercle d\'épargne (mukando)';

  @override
  String get mukandoEnableTitle => 'Mukando — épargne rotative';

  @override
  String get mukandoEnableSub =>
      'Épargnez à tour de rôle en famille. Désactivé par défaut — active-le si votre cercle fait des tours.';

  @override
  String get mukandoEnableCta => 'Activer le mukando';

  @override
  String get addPhoto => 'Utiliser une photo';

  @override
  String get removePhoto => 'Retirer la photo';

  @override
  String get photoUploading => 'Envoi de la photo…';

  @override
  String get photoFailed =>
      'Impossible d\'envoyer la photo — vérifie ta connexion et réessaie.';

  @override
  String get photoSaved => 'Photo enregistrée — ta famille la verra aussi.';

  @override
  String get newSavingsGoal => 'Nouvel objectif d’épargne';

  @override
  String get createSavingsGoal => 'Créer un objectif d’épargne';

  @override
  String get goalName => 'Nom de l’objectif';

  @override
  String get goalNameHint => 'Fonds d’urgence';

  @override
  String get targetAmount => 'Montant cible';

  @override
  String get createGoal => 'Créer l’objectif';

  @override
  String get goalNameAmountFirst =>
      'Ajoute un nom et un objectif supérieur à zéro.';

  @override
  String get shoppingLogged => 'Courses enregistrées';

  @override
  String get loggedItem => 'Enregistré';

  @override
  String get syncDataTitle => 'Synchronisation et données';

  @override
  String get syncStateSyncing => 'Synchronisation…';

  @override
  String get syncStateError => 'En attente de réessai';

  @override
  String get syncStateOffline => 'Hors ligne — les changements sont enregistrés sur ce téléphone';

  @override
  String get syncStateNeedsSignIn => 'Connectez-vous pour synchroniser';

  @override
  String get syncStateSaved => 'Enregistré sur ce téléphone';

  @override
  String get syncNowBtn => 'Synchroniser maintenant';

  @override
  String get syncLastSync => 'Dernière synchronisation';

  @override
  String get syncNever => 'Pas encore';

  @override
  String get syncPendingLabel => 'En attente de synchronisation';

  @override
  String get syncUpToDate => 'Tout est enregistré et à jour';

  @override
  String get syncErrorLabel => 'Dernier problème';

  @override
  String get syncWhereTitle => 'Où vivent vos données';

  @override
  String get syncConnectedTo => 'Cloud familial :';

  @override
  String get syncNotConnected => 'Cet appareil seulement — aucun cloud familial connecté.';

  @override
  String get syncBackupNote => 'Il n\'y a pas de sauvegarde séparée à activer. Chaque changement est enregistré sur ce téléphone dès que vous le faites et se synchronise avec le cloud familial dès que vous avez des données. Exportez un CSV ci-dessous à tout moment pour une copie que vous contrôlez.';

  @override
  String get previewExit => 'Quitter';

  @override
  String previewBanner(Object name) {
    return 'Aperçu en tant que $name';
  }

  @override
  String get resetTitle => 'Choisissez un nouveau mot de passe';

  @override
  String get resetSubtitle => 'Vous êtes connecté via le lien de réinitialisation — choisissez maintenant un nouveau mot de passe.';

  @override
  String get resetNewLabel => 'Nouveau mot de passe';

  @override
  String get resetConfirmLabel => 'Confirmez le nouveau mot de passe';

  @override
  String get resetMismatch => 'Les deux mots de passe ne correspondent pas';

  @override
  String get resetRuleLength => 'Au moins 8 caractères';

  @override
  String get resetRuleMix => 'Avec une lettre et un chiffre';

  @override
  String get resetRuleHint => 'Utilisez au moins 8 caractères, avec une lettre et un chiffre.';

  @override
  String get resetCta => 'Changer le mot de passe';

  @override
  String get resetSuccess => 'Mot de passe modifié — connectez-vous avec le nouveau';

  @override
  String get resetShow => 'Afficher ou masquer le mot de passe';

  @override
  String get resetExpiredTitle => 'Ce lien a expiré';

  @override
  String get resetExpiredBody => 'Les liens de réinitialisation ne fonctionnent qu\'une seule fois et pendant une durée limitée. Envoyez-en un nouveau et réessayez.';

  @override
  String get resetSendNew => 'Envoyer un nouveau lien';

  @override
  String get listDelete => 'Supprimer l’article';

  @override
  String listDeleted(Object name) {
    return '« $name » supprimé de la liste';
  }

  @override
  String get roleAdult => 'Adulte';

  @override
  String get roleTeen => 'Ado';

  @override
  String get roleViewer => 'Observateur';

  @override
  String get inviteCode => 'Code d\'invitation';

  @override
  String get inviteTitle => 'Inviter la famille';

  @override
  String get inviteHowTo => 'Il crée un compte avec son e-mail, puis saisit ce code pour rejoindre ta famille.';

  @override
  String get inviteNew => 'Nouvelle invitation';

  @override
  String get inviteEmailOptional => 'Son e-mail (facultatif — cette personne seule pourra l’utiliser)';

  @override
  String get inviteCreate => 'Créer l’invitation';

  @override
  String get inviteCreated => 'Montrez-leur ce code ou ce QR';

  @override
  String get inviteScanHint => 'Ils scannent le QR avec l’appareil photo ou touchent le lien — l’app s’ouvre prête à rejoindre.';

  @override
  String get inviteShare => 'Partager';

  @override
  String get inviteShareText => 'Rejoins notre famille sur Mhuri Hub — ton invitation :';

  @override
  String get invitePending => 'Invitations en cours';

  @override
  String get inviteNone => 'Aucune invitation en cours.';

  @override
  String get inviteHistory => 'Invitations passées';

  @override
  String get inviteRevoke => 'Révoquer';

  @override
  String get inviteFailed => 'Impossible de créer l’invitation — vérifie ta connexion et réessaie.';

  @override
  String get inviteTooMany => 'Il y a déjà 5 invitations en cours — révoque-en une d’abord.';

  @override
  String get inviteOwnerOnly => 'Seul le propriétaire de la famille gère les invitations.';

  @override
  String get inviteAlreadyInFamily => 'Tu fais déjà partie d’une famille — les invitations servent à en rejoindre une nouvelle.';

  @override
  String get makeOwner => 'Nommer propriétaire';

  @override
  String get makeOwnerFailed => 'Impossible de transférer la propriété — vérifie ta connexion et réessaie.';

  @override
  String get roleParent => 'Parent';

  @override
  String get roleChild => 'Enfant';

  @override
  String inviteAcceptedLabel(Object code, Object role) {
    return '$code — a rejoint';
  }

  @override
  String makeOwnerBody(Object name) {
    return 'Faire de $name le propriétaire de la famille ? Tu deviens un simple membre adulte, et cette personne gère invitations et réglages.';
  }

  @override
  String makeOwnerDone(Object name) {
    return '$name est maintenant le propriétaire';
  }

  @override
  String inviteRevokeBody(Object code) {
    return 'Révoquer l’invitation $code ? Elle ne pourront plus l’utiliser pour rejoindre.';
  }

  @override
  String inviteLinkReady(Object code) {
    return 'L’invitation $code t’attend — rejoins la famille ci-dessous.';
  }

  @override
  String get syncProblemsTitle => 'Des changements qui ont besoin de toi';

  @override
  String get syncProblemsBody => 'Ces changements n’ont pas atteint le cloud familial après plusieurs essais. Réessaie ou abandonne — rien n’est supprimé sans ta confirmation.';

  @override
  String get syncRetryThis => 'Réessayer';

  @override
  String get syncDiscardThis => 'Abandonner';

  @override
  String get syncDiscardTitle => 'Abandonner ce changement ?';

  @override
  String get syncKindTx => 'Dépense';

  @override
  String get syncKindEnvelope => 'Budget';

  @override
  String get syncKindGoal => 'Objectif d’épargne';

  @override
  String get syncKindItem => 'Article';

  @override
  String get syncKindRequest => 'Demande';

  @override
  String get syncKindOther => 'Changement';

  @override
  String syncDiscardBody(Object what) {
    return '« $what » reste sur ce téléphone et n’atteindra jamais le cloud familial. L’abandonner ?';
  }

  @override
  String syncTries(Object tries) {
    return '$tries essais jusqu’ici';
  }

  @override
  String get setupInviteCopied => 'Invitation copiée.';

  @override
  String get setupBadEmail => 'Entrez un e-mail valide.';

  @override
  String get setupTagline => 'Une famille. Un plan.';

  @override
  String get setupPhotoOptional => 'Ajouter une photo (facultatif)';

  @override
  String get setupHaveCode => 'J’ai un code d’invitation';

  @override
  String get setupCreateInstead => 'Créer une famille';

  @override
  String get setupCopy => 'Copier';

  @override
  String get setupScanToJoin => 'Scanne pour rejoindre';

  @override
  String get setupCreateTitle => 'Crée ta famille';

  @override
  String get setupCreateSub => 'Dis-nous comment ta famille t’appelle.';

  @override
  String get setupPreferredName => 'Nom préféré';

  @override
  String get setupFamilyNameField => 'Nom de famille (par exemple, les Moyo)';

  @override
  String get setupCurrency => 'Devise principale';

  @override
  String get setupJoinTitle => 'Rejoins ta famille';

  @override
  String get setupJoinSub => 'Utilise le code partagé par un membre.';

  @override
  String get setupInviteTitle => 'Inviter des membres';

  @override
  String get setupInviteSub => 'Ramène tout le monde dans le même espace familial.';

  @override
  String get setupRoleSuggestion => 'Le rôle est une suggestion. Confirme-le dans les réglages Famille après leur arrivée.';

  @override
  String get setupSendInvite => 'Envoyer l’invitation';

  @override
  String get setupContinue => 'Continuer  →';

  @override
  String get setupInviteLater => 'Inviter plus tard';

  @override
  String get setupPermsTitle => 'Permissions';

  @override
  String get setupPermsSub => 'L’accès recommandé est prêt. Tu pourras le changer dans les réglages Famille.';

  @override
  String get setupPermWallet => 'Voir leur porte-monnaie';

  @override
  String get setupPermTx => 'Noter les transactions';

  @override
  String get setupPermBudget => 'Voir le budget familial';

  @override
  String get setupFinish => 'Terminer';

  @override
  String get deleteWhatTitle => 'Ce qui se passe à la suppression';

  @override
  String get deleteWhatOwner => 'Tu es le propriétaire : tout l’espace familial est supprimé — comptes, budgets, transactions et listes, pour tout le monde. Irréversible.';

  @override
  String get deleteWhatMember => 'Tu quittes la famille. Ton adhésion prend fin, ta photo et ton e-mail sont retirés, tes transactions passées restent affichées comme « Former member ». Les autres gardent leurs données.';

  @override
  String get deleteWhatSessions => 'Toutes les sessions sur tous les appareils sont déconnectées.';

  @override
  String get deleteStepLeave => 'Sortie de la famille…';

  @override
  String get deleteStepAnonymize => 'Retrait de tes données personnelles…';

  @override
  String get deleteStepSessions => 'Déconnexion des sessions…';

  @override
  String get deleteStepIdentity => 'Suppression du compte…';

  @override
  String setupInviteText(Object family, Object code, Object role) {
    return 'Rejoins $family sur Mhuri Hub avec le code $code. Rôle suggéré : $role.';
  }

  @override
  String setupInviteSubject(Object family) {
    return 'Rejoins $family sur Mhuri Hub';
  }

  @override
  String setupStepOf(Object n) {
    return 'Étape $n sur 3';
  }

  @override
  String kidsGoalSaved(Object goal, Object pct) {
    return 'Objectif : $goal — $pct% épargné';
  }

  @override
  String kidsHi(Object name) {
    return 'Salut $name !';
  }

  @override
  String kidsWishItem(Object amount) {
    return 'Ballon — US$25 · épargné $amount';
  }

  @override
  String loginSentCode(Object phone) {
    return 'Nous avons envoyé un code par SMS au $phone';
  }

  @override
  String recSkipped(Object date) {
    return 'Ignoré — prochain : $date';
  }

  @override
  String safeToSpend(Object amount) {
    return 'Sûr à dépenser aujourd\'hui : $amount';
  }

  @override
  String scheduledOn(Object from, Object to) {
    return 'Programmé sur cet appareil · heures calmes $from–$to';
  }

  @override
  String setCurrencySub(Object rate) {
    return 'USD principal · ZiG secondaire · $rate';
  }

  @override
  String syncPill(Object count) {
    return '{count, plural, =1{1 modification enregistrée sur cet appareil — synchronisation une fois en ligne} other{$count modifications enregistrées sur cet appareil — synchronisation une fois en ligne}}';
  }

  @override
  String teenSplitHint(Object amount) {
    return 'Répartition suggérée des $amount gagnés ce mois';
  }

  @override
  String get discardChangesTitle => 'Abandonner les changements ?';

  @override
  String get discardChangesBody => 'Pas encore enregistré. Quitter quand même ?';

  @override
  String get stay => 'Continuer l’édition';

  @override
  String get leave => 'Quitter';

  @override
  String get btnCreate => 'Créer';

  @override
  String get btnJoin => 'Rejoindre';

  @override
  String get hintFamilyExample => 'ex. la famille Taylor';

  @override
  String get transferFrom => 'De';

  @override
  String get transferTo => 'Vers';

  @override
  String get transferWhy => 'Pourquoi ?';

  @override
  String get listNameLabel => 'Article';

  @override
  String get listQtyLabel => 'Qté';

  @override
  String get kidsPinHint => 'Nouveau code (4–6 chiffres)';

  @override
  String get kidsPinUpdated => 'Code du Mode Enfants mis à jour ✓';

  @override
  String get setupEnterBoth => 'Saisis ton prénom et le nom de la famille.';

  @override
  String get setupNeedsConnection => 'Connexion nécessaire pour créer ta famille.';

  @override
  String get setupNameTaken => 'Ce nom de famille est déjà pris. Essaie un autre.';

  @override
  String get setupEnterJoin => 'Saisis ton prénom et le code d’invitation.';

  @override
  String get avatarError => 'Impossible de mettre à jour la photo. Essaie-en une autre.';

  @override
  String get invitesLoadFailed => 'Impossible de charger les invitations. Tire pour actualiser.';

  @override
  String filterAll(Object n) {
    return 'Tout ($n)';
  }

  @override
  String get envLabel => 'Environnement';

  @override
  String get syncStateNeedsSetup => 'Configure ta famille pour synchroniser';
}
