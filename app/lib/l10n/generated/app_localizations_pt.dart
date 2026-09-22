// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get tabHome => 'Início';

  @override
  String get tabBudgets => 'Orçamentos';

  @override
  String get tabSavings => 'Poupança';

  @override
  String get tabLists => 'Listas';

  @override
  String get tabFamily => 'Família';

  @override
  String get tabActivity => 'Atividade';

  @override
  String get greetingMorning => 'Bom dia';

  @override
  String get greetingAfternoon => 'Boa tarde';

  @override
  String get greetingEvening => 'Boa noite';

  @override
  String get familyPool => 'Fundo da família';

  @override
  String safeToSpend(String amount) {
    return 'Seguro para gastar hoje: $amount';
  }

  @override
  String get seeAll => 'Ver tudo';

  @override
  String get add => 'Adicionar';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get undo => 'Desfazer';

  @override
  String get post => 'Registar';

  @override
  String get skip => 'Ignorar';

  @override
  String get approve => 'Aprovar';

  @override
  String get notThisWeek => 'Não nesta semana';

  @override
  String get done => 'Pronto';

  @override
  String get export => 'Exportar';

  @override
  String get meeting => 'Reunião';

  @override
  String get newEnvelope => 'Novo envelope';

  @override
  String get recurringExpenses => 'Despesas recorrentes';

  @override
  String get shopping => 'Compras';

  @override
  String get activityTitle => 'Atividade';

  @override
  String get noActivityTitle => 'Ainda sem atividade';

  @override
  String get noActivityHint =>
      'Cada despesa, rendimento e aprovação aparece aqui — adicione a primeira com o botão +.';

  @override
  String get noGoals => 'Ainda sem metas';

  @override
  String get noGoalsHint =>
      'Comece com um fundo de emergência — mesmo pouco por semana muda a forma como se vive o imprevisto.';

  @override
  String get reportTitle => 'Boletim da família';

  @override
  String get income => 'Receita';

  @override
  String get spent => 'Gasto';

  @override
  String get saved => 'Poupado';

  @override
  String get safePerDay => 'Seguro / dia';

  @override
  String get envelopeHealth => 'Saúde dos envelopes';

  @override
  String get cashLeak => 'Fuga de dinheiro vivo';

  @override
  String get shareReport => 'Partilhar com a família';

  @override
  String get meetingCta => 'Iniciar a reunião de família';

  @override
  String get exportCsv => 'Exportar transações (CSV)';

  @override
  String get family => 'Família';

  @override
  String get hi => 'Olá';

  @override
  String get mySavings => 'A minha poupança';

  @override
  String get addToJar => 'Adicionar ao frasco';

  @override
  String get savingsMatch => 'Poupança equiparada';

  @override
  String get savingsMatchNote => 'Os pais igualam 50% de tudo o que poupas';

  @override
  String get earnings => 'Ganhos';

  @override
  String get logEarning => 'Registar ganho';

  @override
  String get myProposals => 'As minhas propostas';

  @override
  String get proposeExpense => 'Propor despesa';

  @override
  String get proposeTitle => 'Propor uma despesa';

  @override
  String get peek => 'Os pais deixam-te ver este envelope';

  @override
  String get plan => 'Plano: Gastar · Poupar · Dar';

  @override
  String get settingsTitle => 'Definições';

  @override
  String get remindersOnDevice => 'Lembretes neste dispositivo';

  @override
  String get remindersSubtitle =>
      'Faturas, orçamentos, crianças, metas, círculos de poupança e reuniões';

  @override
  String get quietHours =>
      'Horas de silêncio (sem notificações dentro desta janela)';

  @override
  String get monthStartsOn => 'O mês começa no dia';

  @override
  String get language => 'Idioma';

  @override
  String get largeText => 'Texto grande (mais fácil de ler)';

  @override
  String get exportCsvSettings => 'Exportar transações (CSV)';

  @override
  String get comingSoon => 'Brevemente';

  @override
  String get remindersTitle => 'Lembretes';

  @override
  String scheduledOn(String from, String to) {
    return 'Agendado neste dispositivo · horas de silêncio $from–$to';
  }

  @override
  String get remindersOff => 'Lembretes desligados';

  @override
  String get nothingComing => 'Nada à vista';

  @override
  String get ob1Title => 'Dinheiro, gerido em conjunto';

  @override
  String get ob1Body =>
      'Um lugar calmo para tudo o que a sua família ganha, gasta, poupa e planeia — em todas as suas moedas, online ou offline.';

  @override
  String get ob2Title => 'Envelopes, sem culpa';

  @override
  String get ob2Body =>
      'Dê um trabalho a cada dólar. Comida, escola, transporte — veja de relance o que está bem, o que precisa de reforço e o que é seguro gastar hoje.';

  @override
  String get ob3Title => 'Feito para toda a família';

  @override
  String get ob3Body =>
      'Os parceiros partilham o plano. As crianças enchem frascos e ganham estrelas. Os adolescentes propõem despesas e aprendem com a poupança equiparada. A avó guarda o registo do círculo de poupança.';

  @override
  String get ob4Title => 'Lembretes gentis';

  @override
  String syncPill(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count alterações guardadas neste dispositivo — sincronizam quando online',
      one: '1 alteração guardada neste dispositivo — sincroniza quando online',
    );
    return '$_temp0';
  }

  @override
  String get hideAmountsTip => 'Ocultar valores';

  @override
  String get showAmountsTip => 'Mostrar valores';

  @override
  String get themeLabel => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get sixMonthNet => 'Saldo de 6 meses (USD)';

  @override
  String get donutEmpty =>
      'Sem despesas registadas neste ciclo — o anel preenche-se ao adicionar despesas.';

  @override
  String get ob4Body =>
      'Avisos de contas, alertas de orçamento e o resumo familiar semanal — com horário de silêncio, no seu telefone. Você está no controle.';

  @override
  String get next => 'Seguinte';

  @override
  String get loginWelcome => 'Boas-vindas ao Mhuri Hub';

  @override
  String get loginEnterCode => 'Introduza o código';

  @override
  String loginSentCode(String phone) {
    return 'Enviamos um código por SMS para $phone';
  }

  @override
  String get loginSignInHint =>
      'Entre com o seu e-mail para abrir o seu espaço familiar.';

  @override
  String get loginSendCode => 'Enviar código';

  @override
  String get loginVerify => 'Verificar e entrar';

  @override
  String get loginChangeNumber => 'Mudar número';

  @override
  String get loginBadPhone =>
      'Introduza um telefone válido (ex.: +44 7700 900123).';

  @override
  String get quickAddTitle => 'Adicionar rápido';

  @override
  String get expense => 'Despesa';

  @override
  String get envelopeLabel => 'Envelope';

  @override
  String get whoLabel => 'Quem';

  @override
  String get paidWithLabel => 'Pago com';

  @override
  String get noteHint => 'Nota (ex.: FreshMart)';

  @override
  String get enterAmountFirst => 'Introduza primeiro um valor';

  @override
  String get savedOffline =>
      'Guardado ✓ — funciona offline, sincroniza quando online';

  @override
  String kidsHi(String name) {
    return 'Olá $name!';
  }

  @override
  String get kidsMyJar => 'O meu cofre';

  @override
  String kidsGoalSaved(String goal, int pct) {
    return 'Meta: $goal — $pct% poupado';
  }

  @override
  String get kidsMyChores => 'As minhas tarefas';

  @override
  String get kidsWishList => 'Lista de desejos';

  @override
  String kidsWishItem(String amount) {
    return 'Bola — US\$25 · poupado $amount';
  }

  @override
  String get kidsAskMoney => 'Peça ao\npapá/mamã';

  @override
  String get kidsDoChore => 'Fazer uma tarefa';

  @override
  String get kidsAllDone => 'Tarefas concluídas!';

  @override
  String get kidsParents => 'Pais';

  @override
  String get kidsAskTitle => 'Pedir ao papá e à mamã';

  @override
  String get kidsWhatFor => 'Para quê?';

  @override
  String get kidsDefaultReason => 'Dinheiro de bolso';

  @override
  String get teenZoneTitle => 'Zona teen · 13–17';

  @override
  String get teenNoEarnings => 'Ainda sem ganâncias registadas';

  @override
  String get teenEarnHint =>
      'Lave um carro, ajude na loja — registe e veja o cofre crescer.';

  @override
  String get teenSpend => 'Gastar 50%';

  @override
  String get teenSave => 'Poupar 40%';

  @override
  String get teenGive => 'Dar 10%';

  @override
  String teenSplitHint(String amount) {
    return 'Divisão sugerida dos $amount ganados este mês';
  }

  @override
  String get teenSavedJar => 'Poupado no cofre — os pais igualam 50%';

  @override
  String get teenWhatDid => 'O que fez?';

  @override
  String get familyTitle => 'Família';

  @override
  String get membersDesc => 'Casal + crianças · o mês começa no dia 1';

  @override
  String get membersInviteHint =>
      'Partilhe o código ou leia para convidar um familiar';

  @override
  String get setCurrency => 'Moeda e taxas';

  @override
  String setCurrencySub(String rate) {
    return 'USD principal · ZiG secundária · $rate';
  }

  @override
  String get setPrivacy => 'Privacidade';

  @override
  String get setPrivacySub =>
      'Bolsos privados: não — o parceiro vê só o partilhado';

  @override
  String get setMonthStart => 'Início do mês';

  @override
  String get setMonthStartSub => 'Dia 1 — alinhado com o ciclo salarial';

  @override
  String get setNotif => 'Notificações';

  @override
  String get setNotifSub =>
      'Alerta de orçamento 80% · contas · pedidos das crianças';

  @override
  String get setBackup => 'Cópia e exportação';

  @override
  String get setBackupSub =>
      'Cópia cifrada na nuvem · exportação CSV (proprietário)';

  @override
  String get meetingTitle => 'Reunião de família';

  @override
  String get mFigures => 'O mês passado, em números';

  @override
  String get figureIncome => 'Receitas';

  @override
  String get figureSpent => 'Gasto';

  @override
  String get figureSaved => 'Poupado';

  @override
  String get mEnvelopeHealth => 'Saúde dos envelopes';

  @override
  String get mReachedTalk =>
      'Falem dos envelopes marcados \"Atingido\". Completar juntos, com calma.';

  @override
  String get mGoals => 'Metas de poupança';

  @override
  String get mChores => 'Tarefas, cofres e pedidos';

  @override
  String get mImprove => 'Uma coisa a melhorar';

  @override
  String recSkipped(String date) {
    return 'Ignorado — próximo: $date';
  }

  @override
  String get recNew => 'Nova despesa recorrente';

  @override
  String get recReview =>
      'Nada é cobrado automaticamente — você revê e regista tudo.';

  @override
  String get recNoEnvelope => 'Sem envelope';

  @override
  String get recNextDue => 'Próximo vencimento:';

  @override
  String get recNameAmount => 'Dê um nome e um valor';

  @override
  String get recSaveRule => 'Guardar regra';

  @override
  String get recNameHint => 'Nome (ex.: Propinas escolares)';

  @override
  String get roleOwner => 'Proprietário';

  @override
  String get roleAdult => 'Adulto';

  @override
  String get roleTeen => 'Adolescente';

  @override
  String get roleKid => 'Criança';

  @override
  String get roleViewer => 'Idoso · Observador';

  @override
  String get methodCash => 'Dinheiro';

  @override
  String get methodMobile => 'Dinheiro móvel';

  @override
  String get methodCard => 'Cartão';

  @override
  String get methodTransfer => 'Transferência';

  @override
  String get methodAgent => 'Agente / ponto de dinheiro';

  @override
  String get methodOther => 'Outro';

  @override
  String get stateToBuy => 'A comprar';

  @override
  String get stateInCart => 'No carrinho';

  @override
  String get stateDone => 'Feito';

  @override
  String get freqWeekly => 'Semanal';

  @override
  String get freqMonthly => 'Mensal';

  @override
  String get rollReset => 'Reiniciar cada mês';

  @override
  String get rollRoll => 'Transportar o resto';

  @override
  String get rollAccum => 'Acumular';

  @override
  String get freqTerm => 'Por trimestre (~3 meses)';

  @override
  String get budgetsTitle => 'Orçamentos';

  @override
  String get noEnvelopes => 'Ainda sem envelopes';

  @override
  String get envelopesHint =>
      'Os envelopes são orçamentos visíveis: mercado, escola, transporte. Crie o primeiro abaixo.';

  @override
  String get newEnvStub => 'Novo envelope — a caminho (fase 1)';

  @override
  String get addRecurringTip => 'Adicionar despesa recorrente';

  @override
  String get recReviewed =>
      'Revista antes de registar — nada é cobrado em silêncio.';

  @override
  String get noRecurring => 'Ainda sem despesas recorrentes';

  @override
  String get recurringHint =>
      'Adicione regras de propinas, renda ou carregamento — avisamos quando cada uma vence.';

  @override
  String get chipOnTrack => 'No caminho';

  @override
  String get chipReached => 'Atingido';

  @override
  String get remaining => 'Restante';

  @override
  String get moveMoney => 'Mover dinheiro';

  @override
  String get pickFirst => 'Escolha primeiro envelopes e um valor';

  @override
  String get skipPeriod => 'Ignorar este período';

  @override
  String get pauseRule => 'Pausar regra';

  @override
  String get resumeRule => 'Retomar regra';

  @override
  String get meetingHint => '15 minutos, uma vez por mês.';

  @override
  String mChoresLine(Object proposals, Object requests, Object stars) {
    return '$stars estrelas ganhas · $requests pedidos à espera · $proposals propostas teen à espera.';
  }

  @override
  String get meetingNoteHint =>
      'ex.: \"Cozinhar mais aos domingos — o gasto do mercado sobe.\"';

  @override
  String get meetingSaveNote => 'Guardar a nossa nota';

  @override
  String get savedTick => 'Guardado ✓';

  @override
  String get meetingDone => 'Feito — até o mês que vem';

  @override
  String get reportCard => 'Boletim';

  @override
  String get recentActivity => 'Atividade recente';

  @override
  String get swapCurrency => 'Trocar moeda de exibição';

  @override
  String get yourChild => 'Seu filho';

  @override
  String get review => 'Rever';

  @override
  String get confirm => 'Confirmar';

  @override
  String get markCollected => 'Marcar recolhido';

  @override
  String get decline => 'Recusar';

  @override
  String get sentToParents => 'Enviado ao papá e à mamã';

  @override
  String get sendRequest => 'Enviar pedido';

  @override
  String get parentsOnly => 'Só pais';

  @override
  String get pinExitLine => 'Introduza o PIN para sair do Modo Criança.';

  @override
  String get wrongPin => 'PIN errado';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get addItem => 'Adicionar item';

  @override
  String get listSharedSub =>
      'Lista de compras da família · partilhada com todos';

  @override
  String get tickFirst => 'Marque primeiro os itens';

  @override
  String get namePriceFirst => 'Dê nome e preço ao item';

  @override
  String get addToList => 'Adicionar à lista';

  @override
  String get spaceSetup => 'Configure o seu espaço familiar';

  @override
  String get spaceSetupSub =>
      'Crie um espaço para a sua família ou entre no que o seu parceiro criou com o código. Tudo o que registar sincroniza entre os telefones.';

  @override
  String get createSpace => 'Criar espaço';

  @override
  String get joinWithCode => 'Entrar com código';

  @override
  String get offlineRetry => 'Offline — tenta de novo sozinho';

  @override
  String get syncProblem => 'Problema de sincronização';

  @override
  String get signinExpired => 'Sessão expirada — saia e volte a entrar';

  @override
  String get syncing => 'A sincronizar…';

  @override
  String lastSync(Object last) {
    return 'Última sincronização: $last';
  }

  @override
  String get familySpace => 'Espaço familiar';

  @override
  String get syncNow => 'Sincronizar agora';

  @override
  String get createFamilySpace => 'Criar espaço familiar';

  @override
  String get familyName => 'Nome da família';

  @override
  String get localizedNote =>
      'A app inteira já fala seis línguas — nada fica só em inglês.';

  @override
  String get nextCreateSpace =>
      'A seguir: crie o seu espaço familiar (ou entre com um código) no separador Família.';

  @override
  String reachedMove(Object on, Object total) {
    return '$on de $total envelopes ainda no caminho. Abra os marcados \"Atingido\" e mova dinheiro para lá — com calma, sem perfeição.';
  }

  @override
  String get cashTrace =>
      'O dinheiro vivo é fácil de gastar e difícil de rastrear. Pagar um pouco mais por dinheiro móvel ou cartão mantém a imagem mais clara.';

  @override
  String get whereMoneyWent => 'Para onde foi o dinheiro';

  @override
  String get exportFailed => 'A exportação falhou neste dispositivo';

  @override
  String csvSaved(Object path) {
    return 'CSV guardado: $path';
  }

  @override
  String exportedPath(Object path) {
    return 'Exportado ✓ $path';
  }

  @override
  String get bringToMeeting => 'Leve isto à Reunião de Família mensal';

  @override
  String get savingsTitle => 'Poupança';

  @override
  String get markRound => 'Marcar ronda recolhida';

  @override
  String get recordsOnly => 'O Mhuri Hub nunca guarda o dinheiro — só regista.';

  @override
  String get saveContribution => 'Guardar contribuição';

  @override
  String get sendTest => 'Enviar notificação de teste';

  @override
  String get testOk => 'Os lembretes funcionam neste dispositivo.';

  @override
  String get monthCycle => 'Ciclo do mês';

  @override
  String get paydayAlign =>
      'Orçamentos alinhados ao salário — os ciclos reiniciam neste dia e o lembrete da reunião chega na véspera';

  @override
  String get backupComing => 'Cópia e restauro (em breve)';

  @override
  String get fromLabel => 'De';

  @override
  String get addTransaction => 'Adicionar transação';

  @override
  String get logWhatAmount => 'Adicione o que fez e o valor';

  @override
  String get logIt => 'Registar';

  @override
  String get fromEnvelope => 'Do envelope';

  @override
  String get amountPurposeFirst => 'Adicione um valor e para que é';

  @override
  String get sentApproval => 'Enviado ao papá e à mamã para aprovar';

  @override
  String get sendProposal => 'Enviar proposta';

  @override
  String get stWaiting => 'À espera ⏳';

  @override
  String get stApproved => 'Aprovado ✓';

  @override
  String get stDeclined => 'Recusado';

  @override
  String requestTitle(Object amount, Object name) {
    return '$name pediu $amount';
  }

  @override
  String proposalTitle(Object amount, Object name) {
    return '$name propõe $amount';
  }

  @override
  String proposalSub(Object env, Object reason) {
    return '$reason · do envelope $env';
  }

  @override
  String recDueSub(Object when) {
    return 'Recorrente · vence $when · registe quando pagar';
  }

  @override
  String get dueNow => 'agora';

  @override
  String get dueSoon => 'em breve';

  @override
  String choreDoneTitle(Object name) {
    return '\"$name\" feito — confirmar?';
  }

  @override
  String choreDoneSub(Object stars) {
    return '$stars estrelas — confirme para crescer o cofre';
  }

  @override
  String circleSub(Object amount, Object pot, Object who) {
    return '$who vai recolher $amount · pote $pot até agora';
  }

  @override
  String get exportReal => 'A exportação funciona num dispositivo real';

  @override
  String get allSynced => '✓ Tudo sincronizado';

  @override
  String get familyCta => 'Família ›';

  @override
  String get recentInEnv => 'Recente neste envelope';

  @override
  String get nothingLogged => 'Nada registado aqui ainda.';

  @override
  String dueBy(Object days) {
    return 'atrasado ${days}d';
  }

  @override
  String get dueToday => 'vence hoje';

  @override
  String get dueTomorrow => 'vence amanhã';

  @override
  String dueIn(Object days) {
    return 'vence em ${days}d';
  }

  @override
  String circleTitle(Object round, Object total) {
    return 'Círculo de poupança — Ronda $round de $total';
  }

  @override
  String postedSnack(Object name) {
    return '$name registado ✓ — envelope atualizado';
  }

  @override
  String starsGiven(Object stars) {
    return '$stars estrelas dadas às crianças!';
  }

  @override
  String approvedReq(Object amount, Object name) {
    return 'Aprovado ✓ — $amount adicionado a $name';
  }

  @override
  String declineBody(Object env, Object reason) {
    return '$reason\n\nDo envelope: $env';
  }

  @override
  String approvedProp(Object amount, Object env) {
    return 'Aprovado ✓ — $amount registado em $env';
  }

  @override
  String sentKid(Object name) {
    return '\"$name\" enviado ao papá e à mamã';
  }

  @override
  String get listEmptyAdd => 'Nada aqui — adicione um item com ＋';

  @override
  String usesPct(Object name, Object pct) {
    return 'Usa $pct% do envelope $name';
  }

  @override
  String loggedTo(Object amount, Object name) {
    return 'Registado $amount em $name ✓ — envelope atualizado';
  }

  @override
  String get finishShop => 'Terminar compras → registar despesa';

  @override
  String estPrice(Object symbol) {
    return 'Preço unitário estimado ($symbol)';
  }

  @override
  String get myFamily => 'A minha família';

  @override
  String spaceCreated(Object code) {
    return 'Espaço criado ✓ Código de convite: $code';
  }

  @override
  String get createFail => 'Não foi possível criar o espaço — tente de novo';

  @override
  String get joinSpaceTitle => 'Entrar num espaço familiar';

  @override
  String get inviteCode => 'Código de convite';

  @override
  String get joinedOk => 'Entrou ✓ — os seus dados estão a sincronizar';

  @override
  String get joinFail => 'Não foi possível entrar — tente de novo';

  @override
  String get kidsPin => 'PIN de saída do Modo Criança';

  @override
  String get kidsPinSub =>
      'Necessário para sair do Modo Criança — toque para mudar';

  @override
  String signedInAs(Object masked) {
    return 'Sessão: $masked';
  }

  @override
  String get signOut => 'Terminar sessão';

  @override
  String get viewAs => 'Ver como…';

  @override
  String cashShare(Object pct) {
    return '$pct% do gasto';
  }

  @override
  String donutA11y(Object name, Object share) {
    return 'Gasto por envelope, $name selecionado, $share por cento';
  }

  @override
  String starsHome(Object stars) {
    return '$stars estrelas — confirme tarefas no Início para encher cofres';
  }

  @override
  String circleMember(Object name) {
    return 'Círculo de poupança · $name';
  }

  @override
  String potSoFar(Object pot) {
    return 'Pote até agora: $pot';
  }

  @override
  String get roundOk =>
      'Ronda registada ✓ — só regista, nunca guardamos dinheiro';

  @override
  String addToGoal(Object name) {
    return 'Adicionar a $name';
  }

  @override
  String addedToGoal(Object name) {
    return 'Adicionado a $name';
  }

  @override
  String goalBase(Object short) {
    return 'Base da meta: $short';
  }

  @override
  String syncTime(Object t) {
    return 'hoje às $t';
  }

  @override
  String get watch => 'Atenção';

  @override
  String get spentLabel => 'Gasto';

  @override
  String get limitLabel => 'Limite';

  @override
  String envelopeRemaining(Object amount, Object name) {
    return 'Restam $amount em $name';
  }

  @override
  String envelopeWillLeave(Object amount, Object name) {
    return 'Isto deixa $amount em $name';
  }

  @override
  String envelopeWillExceed(Object amount, Object name) {
    return 'Isto deixa $name $amount acima do orçamento';
  }

  @override
  String get overBudgetTitle => 'Este envelope ficará acima do orçamento';

  @override
  String overBudgetBody(Object amount, Object name) {
    return '$name ficará $amount acima do orçamento. Ainda podes registar a despesa.';
  }

  @override
  String get adjustAmount => 'Ajustar valor';

  @override
  String get logAnyway => 'Registar mesmo assim';

  @override
  String overBy(Object amount) {
    return 'Acima por $amount';
  }

  @override
  String get overBudgetLabel => 'Acima do orçamento';

  @override
  String memberPot(Object contribution, Object count, Object pot) {
    return 'Pote: $pot · $contribution × $count membros';
  }

  @override
  String get switchProfile => 'Mudar de perfil';

  @override
  String get switchProfileSub => 'Ver a app como outro membro da família';

  @override
  String get youTag => 'Você';

  @override
  String get pickCurrency => 'Moeda de exibição';

  @override
  String get rateField => 'ZiG por 1 USD';

  @override
  String get rateSave => 'Guardar taxa';

  @override
  String get rateReset => 'Voltar à referência RBZ';

  @override
  String get rateCustomNote =>
      'Usada para a vista ZiG em toda a app. A referência RBZ incluída é 15,27.';

  @override
  String get autoHide => 'Esconder valores ao sair da app';

  @override
  String get autoHideSub =>
      'Os saldos escondem-se quando a app vai para segundo plano — desligue se preferir.';

  @override
  String get hideNow => 'Esconder valores agora';

  @override
  String get exportCsvRow => 'Exportar todas as transações (CSV)';

  @override
  String get copyInvite => 'Copiar código de convite';

  @override
  String get copied => 'Copiado ✓';

  @override
  String get inviteTitle => 'Convidar um familiar';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get editProfileSub => 'Nome e avatar deste membro';

  @override
  String get photoNote =>
      'As fotos são enviadas para o servidor da família e aparecem em todos os dispositivos.';

  @override
  String get accountTitle => 'Conta';

  @override
  String get deleteAccount => 'Eliminar conta';

  @override
  String get deleteAccountTitle => 'Eliminar a sua conta?';

  @override
  String get deleteAccountBody =>
      'Isto elimina permanentemente o seu acesso e os dados financeiros guardados neste dispositivo. Não pode ser desfeito.';

  @override
  String get deleteAccountConfirm => 'Eliminar permanentemente';

  @override
  String get deleteAccountFailed =>
      'Não foi possível eliminar a sua conta. Verifique a ligação e tente novamente.';

  @override
  String get moreDetails => 'Mais detalhes';

  @override
  String get lessDetails => 'Menos detalhes';

  @override
  String get discardTitle => 'Descartar este lançamento?';

  @override
  String get discardBody => 'Introduziu dados que ainda não foram guardados.';

  @override
  String get keepEditing => 'Continuar a editar';

  @override
  String get discard => 'Descartar';

  @override
  String get viewDetails => 'Ver detalhes do saldo';

  @override
  String get fabTip => 'Toque + para registar entradas ou saídas';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get passwordLabel => 'Palavra-passe';

  @override
  String get loginSignIn => 'Entrar';

  @override
  String get loginCreateAccount => 'Criar conta';

  @override
  String get welcomeBack => 'Bem-vindo de volta';

  @override
  String get brandTagline => 'DINHEIRO EM FAMÍLIA, JUNTOS';

  @override
  String get createAccountTitle => 'Cria a tua conta';

  @override
  String get createAccountHint =>
      'Cria o espaço financeiro seguro da tua família.';

  @override
  String get forgotPassword => 'Esqueceste a palavra-passe?';

  @override
  String get sendingPasswordReset => 'A enviar…';

  @override
  String get passwordResetSent =>
      'E-mail de redefinição enviado — abra o link neste telefone e o app conclui a troca.';

  @override
  String get passwordResetFailed =>
      'Não foi possível enviar o e-mail. Verifica a ligação e tenta novamente.';

  @override
  String get newToMhuri => 'Novo no Mhuri Hub?';

  @override
  String get alreadyHaveAccount => 'Já tens uma conta?';

  @override
  String get loginBadEmail => 'Introduza um e-mail válido.';

  @override
  String get loginShortPassword =>
      'A palavra-passe precisa de pelo menos 6 caracteres.';

  @override
  String get checkYourEmail =>
      'Quase lá — verifica o teu e-mail e confirma, depois entra.';

  @override
  String get togglePassword => 'Mostrar ou ocultar a palavra-passe';

  @override
  String get inviteHowTo =>
      'A pessoa cria uma conta com o e-mail dela e depois introduz este código para entrar na tua família.';

  @override
  String get obDone => 'Vamos começar';

  @override
  String get setupChoiceTitle => 'Configura a tua família';

  @override
  String get setupChoiceBody =>
      'O Mhuri Hub funciona para uma família, em conjunto. Cria a tua ou entra na que já pertences.';

  @override
  String get setupCreateCard => 'Criar uma família';

  @override
  String get setupCreateCardBody =>
      'Dá um nome, escolhe o tipo de agregado e convida os teus.';

  @override
  String get setupJoinCard => 'Entrar com um código';

  @override
  String get setupJoinCardBody =>
      'Alguém convidou-te — introduz o código familiar para entrares.';

  @override
  String get createFamilyCta => 'Criar família';

  @override
  String get joinFamilyCta => 'Entrar na família';

  @override
  String get familyNameLabel => 'Nome da família';

  @override
  String get familyNameHint => 'ex.: A família Marufu';

  @override
  String get householdLabel => 'Que tipo de família?';

  @override
  String get hhCouple => 'Casal com filhos';

  @override
  String get hhSingle => 'Pai/mãe solteira';

  @override
  String get hhExtended => 'Família alargada';

  @override
  String get hhBlended => 'Família reconstruída';

  @override
  String get hhPartners => 'Casal sem filhos';

  @override
  String get hhSolo => 'Só eu por agora';

  @override
  String get hhOther => 'Outro';

  @override
  String get joinCodeLabel => 'Código de convite';

  @override
  String get skipForNow => 'Ignorar por agora';

  @override
  String get setupInviteTitle => 'Convida os teus';

  @override
  String get setupWorking => 'A preparar tudo…';

  @override
  String get noEnvelopesYet =>
      'Ainda não há envelopes — cria o primeiro no separador Orçamentos.';

  @override
  String get noActivityYet =>
      'Nada registado ainda. Toque + para adicionar a tua primeira transação.';

  @override
  String get setupBanner =>
      'Termina a configuração: cria a tua família ou entra com um código';

  @override
  String get setupBannerCta => 'Configurar';

  @override
  String get deleteTypeHint => 'Escreve DELETE para confirmar';

  @override
  String get deletePermanently => 'Eliminar permanentemente';

  @override
  String get errInviteCode =>
      'Introduz o código de convite do responsável da família — tem o formato MHRI-4F2A.';

  @override
  String get errFamilyNameTaken =>
      'Esse nome de família já está em uso — tenta outro.';

  @override
  String get authErrEmailNotConfirmed =>
      'Verifica o teu correio — toca primeiro no link de confirmação e depois entra.';

  @override
  String get authErrBadCredentials =>
      'O e-mail ou a palavra-passe está errado.';

  @override
  String get authErrAlreadyRegistered =>
      'Já existe uma conta com este e-mail — entra.';

  @override
  String get authErrRateLimited =>
      'Demasiadas tentativas — espera um minuto e tenta de novo.';

  @override
  String get authErrNetwork =>
      'Sem ligação — verifica a tua internet e tenta de novo.';

  @override
  String get authResend => 'Reenviar e-mail de confirmação';

  @override
  String get authResent =>
      'E-mail de confirmação enviado — verifica a tua caixa.';

  @override
  String get mukandoOn => 'Círculo de poupança (mukando)';

  @override
  String get mukandoEnableTitle => 'Mukando — poupança rotativa';

  @override
  String get mukandoEnableSub =>
      'Poupa em turnos com a tua família. Desligado por defeito — liga se o teu círculo faz rodadas.';

  @override
  String get mukandoEnableCta => 'Ativar o mukando';

  @override
  String get addPhoto => 'Usar foto';

  @override
  String get removePhoto => 'Remover foto';

  @override
  String get photoUploading => 'A enviar a foto…';

  @override
  String get photoFailed =>
      'Não foi possível enviar a foto — verifica a ligação e tenta de novo.';

  @override
  String get photoSaved => 'Foto guardada — a tua família também a verá.';

  @override
  String get newSavingsGoal => 'Nova meta de poupança';

  @override
  String get createSavingsGoal => 'Criar meta de poupança';

  @override
  String get goalName => 'Nome da meta';

  @override
  String get goalNameHint => 'Fundo de emergência';

  @override
  String get targetAmount => 'Valor alvo';

  @override
  String get createGoal => 'Criar meta';

  @override
  String get goalNameAmountFirst =>
      'Adiciona um nome e um alvo maior que zero.';

  @override
  String get shoppingLogged => 'Compras registadas';

  @override
  String get loggedItem => 'Registado';

  @override
  String get syncDataTitle => 'Sincronização e dados';

  @override
  String get syncStateSyncing => 'Sincronizando…';

  @override
  String get syncStateError => 'Aguardando nova tentativa';

  @override
  String get syncStateOffline => 'Sem conexão — as mudanças ficam salvas neste telefone';

  @override
  String get syncStateNeedsSignIn => 'Entre para sincronizar';

  @override
  String get syncStateSaved => 'Salvo neste telefone';

  @override
  String get syncNowBtn => 'Sincronizar agora';

  @override
  String get syncLastSync => 'Última sincronização';

  @override
  String get syncNever => 'Ainda não';

  @override
  String get syncPendingLabel => 'Aguardando sincronização';

  @override
  String get syncUpToDate => 'Tudo salvo e em dia';

  @override
  String get syncErrorLabel => 'Último problema';

  @override
  String get syncWhereTitle => 'Onde seus dados vivem';

  @override
  String get syncConnectedTo => 'Nuvem da família:';

  @override
  String get syncNotConnected => 'Somente este aparelho — nenhuma nuvem da família conectada.';

  @override
  String get syncBackupNote => 'Não há backup separado para ativar. Cada mudança é salva neste telefone no momento em que você a faz e sincroniza com a nuvem da família sempre que houver internet. Exporte um CSV abaixo quando quiser para ter uma cópia sob seu controle.';

  @override
  String get previewExit => 'Sair';

  @override
  String previewBanner(Object name) {
    return 'Vendo como $name';
  }

  @override
  String get resetTitle => 'Escolha uma nova palavra-passe';

  @override
  String get resetSubtitle => 'Você entrou pelo link de redefinição — agora escolha uma nova palavra-passe.';

  @override
  String get resetNewLabel => 'Nova palavra-passe';

  @override
  String get resetConfirmLabel => 'Confirme a nova palavra-passe';

  @override
  String get resetMismatch => 'As duas palavras-passe não coincidem';

  @override
  String get resetRuleLength => 'Pelo menos 8 caracteres';

  @override
  String get resetRuleMix => 'Com uma letra e um número';

  @override
  String get resetRuleHint => 'Use pelo menos 8 caracteres, com uma letra e um número.';

  @override
  String get resetCta => 'Alterar palavra-passe';

  @override
  String get resetSuccess => 'Palavra-passe alterada — entre com a nova';

  @override
  String get resetShow => 'Mostrar ou ocultar a palavra-passe';

  @override
  String get resetExpiredTitle => 'Este link expirou';

  @override
  String get resetExpiredBody => 'Links de redefinição funcionam uma única vez e por pouco tempo. Envie um novo e tente novamente.';

  @override
  String get resetSendNew => 'Enviar um novo link';

  @override
  String get listDelete => 'Excluir item';

  @override
  String listDeleted(Object name) {
    return '"$name" removido da lista';
  }

  @override
  String get roleAdult => 'Adulto';

  @override
  String get roleTeen => 'Adolescente';

  @override
  String get roleViewer => 'Observador';

  @override
  String get inviteCode => 'Código de convite';

  @override
  String get inviteTitle => 'Convidar a família';

  @override
  String get inviteHowTo => 'A pessoa cria uma conta com o e-mail dela e depois introduz este código para entrar na tua família.';

  @override
  String get inviteNew => 'Novo convite';

  @override
  String get inviteEmailOptional => 'O email dele(a) (opcional — só essa pessoa poderá usar)';

  @override
  String get inviteCreate => 'Criar convite';

  @override
  String get inviteCreated => 'Mostre este código ou QR para a pessoa';

  @override
  String get inviteScanHint => 'Ela escaneia o QR com a câmera ou toca no link — o app abre pronto para entrar.';

  @override
  String get inviteShare => 'Partilhar';

  @override
  String get inviteShareText => 'Entra na nossa família no Mhuri Hub — o teu convite:';

  @override
  String get invitePending => 'Convites abertos';

  @override
  String get inviteNone => 'Nenhum convite aberto.';

  @override
  String get inviteHistory => 'Convites anteriores';

  @override
  String get inviteRevoke => 'Revogar';

  @override
  String get inviteFailed => 'Não foi possível criar o convite — verifique a conexão e tente novamente.';

  @override
  String get inviteTooMany => 'Já há 5 convites abertos — revogue um primeiro.';

  @override
  String get inviteOwnerOnly => 'Apenas o dono da família gere os convites.';

  @override
  String get inviteAlreadyInFamily => 'Você já pertence a uma família — convites servem para entrar numa nova.';

  @override
  String get makeOwner => 'Tornar dono';

  @override
  String get makeOwnerFailed => 'Não foi possível transferir a propriedade — verifique a conexão e tente novamente.';

  @override
  String get roleParent => 'Pai/Mãe';

  @override
  String get roleChild => 'Criança';

  @override
  String inviteAcceptedLabel(Object code, Object role) {
    return '$code — entrou';
  }

  @override
  String makeOwnerBody(Object name) {
    return 'Fazer de $name o dono da família? Você passa a membro adulto comum e essa pessoa gere convites e configurações.';
  }

  @override
  String makeOwnerDone(Object name) {
    return '$name agora é o dono da família';
  }

  @override
  String inviteRevokeBody(Object code) {
    return 'Revogar o convite $code? A pessoa não vai poder entrar com ele.';
  }

  @override
  String inviteLinkReady(Object code) {
    return 'O convite $code está à espera — entre na família abaixo.';
  }

  @override
  String get syncProblemsTitle => 'Mudanças que precisam de você';

  @override
  String get syncProblemsBody => 'Estas mudanças não chegaram à nuvem da família após várias tentativas. Tente de novo ou descarte — nada é removido sem a sua confirmação.';

  @override
  String get syncRetryThis => 'Tentar de novo';

  @override
  String get syncDiscardThis => 'Descartar';

  @override
  String get syncDiscardTitle => 'Descartar esta mudança?';

  @override
  String get syncKindTx => 'Despesa';

  @override
  String get syncKindEnvelope => 'Orçamento';

  @override
  String get syncKindGoal => 'Meta de poupança';

  @override
  String get syncKindItem => 'Item da lista';

  @override
  String get syncKindRequest => 'Pedido';

  @override
  String get syncKindOther => 'Mudança';

  @override
  String syncDiscardBody(Object what) {
    return '“$what” fica só neste telefone e nunca chegará à nuvem da família. Descartar?';
  }

  @override
  String syncTries(Object tries) {
    return '$tries tentativas até agora';
  }

  @override
  String get setupInviteCopied => 'Convite copiado.';

  @override
  String get setupBadEmail => 'Introduza um email válido.';

  @override
  String get setupTagline => 'Uma família. Um plano.';

  @override
  String get setupPhotoOptional => 'Adicionar foto (opcional)';

  @override
  String get setupHaveCode => 'Tenho um código de convite';

  @override
  String get setupCreateInstead => 'Criar uma família';

  @override
  String get setupCopy => 'Copiar';

  @override
  String get setupScanToJoin => 'Ler para entrar';

  @override
  String get setupCreateTitle => 'Crie a sua família';

  @override
  String get setupCreateSub => 'Diga-nos como a sua família lhe chama.';

  @override
  String get setupPreferredName => 'Nome preferido';

  @override
  String get setupFamilyNameField => 'Nome da família (por exemplo, os Moyo)';

  @override
  String get setupCurrency => 'Moeda principal';

  @override
  String get setupJoinTitle => 'Entre na sua família';

  @override
  String get setupJoinSub => 'Use o código partilhado por um familiar.';

  @override
  String get setupInviteTitle => 'Convidar membros';

  @override
  String get setupInviteSub => 'Traga todos para o mesmo espaço familiar.';

  @override
  String get setupRoleSuggestion => 'O papel vai como sugestão. Confirme nas definições da Família depois de entrarem.';

  @override
  String get setupSendInvite => 'Enviar convite';

  @override
  String get setupContinue => 'Continuar  →';

  @override
  String get setupInviteLater => 'Convidar mais tarde';

  @override
  String get setupPermsTitle => 'Permissões';

  @override
  String get setupPermsSub => 'O acesso recomendado está pronto. Pode alterá-lo nas definições da Família.';

  @override
  String get setupPermWallet => 'Ver a carteira deles';

  @override
  String get setupPermTx => 'Registar transações';

  @override
  String get setupPermBudget => 'Ver o orçamento familiar';

  @override
  String get setupFinish => 'Concluir';

  @override
  String get deleteWhatTitle => 'O que acontece ao eliminar a conta';

  @override
  String get deleteWhatOwner => 'É o dono da família: todo o espaço familiar é eliminado — contas, orçamentos, transações e listas, para todos. Não pode ser desfeito.';

  @override
  String get deleteWhatMember => 'Sai da família. A sua adesão termina, a foto e o email são removidos, e as transações passadas ficam como “Former member”. Os outros mantêm os dados.';

  @override
  String get deleteWhatSessions => 'Todas as sessões em todos os aparelhos terminam.';

  @override
  String get deleteStepLeave => 'A sair da família…';

  @override
  String get deleteStepAnonymize => 'A remover os seus dados pessoais…';

  @override
  String get deleteStepSessions => 'A terminar sessões…';

  @override
  String get deleteStepIdentity => 'A eliminar a sua conta…';

  @override
  String setupInviteText(Object family, Object code, Object role) {
    return 'Entra na família $family no Mhuri Hub com o código $code. Papel sugerido: $role.';
  }

  @override
  String setupInviteSubject(Object family) {
    return 'Entra na família $family no Mhuri Hub';
  }

  @override
  String setupStepOf(Object n) {
    return 'Passo $n de 3';
  }

  @override
  String kidsGoalSaved(Object goal, Object pct) {
    return 'Meta: $goal — $pct% poupado';
  }

  @override
  String kidsHi(Object name) {
    return 'Olá $name!';
  }

  @override
  String kidsWishItem(Object amount) {
    return 'Bola — US$25 · poupado $amount';
  }

  @override
  String loginSentCode(Object phone) {
    return 'Enviamos um código por SMS para $phone';
  }

  @override
  String recSkipped(Object date) {
    return 'Ignorado — próximo: $date';
  }

  @override
  String safeToSpend(Object amount) {
    return 'Seguro para gastar hoje: $amount';
  }

  @override
  String scheduledOn(Object from, Object to) {
    return 'Agendado neste dispositivo · horas de silêncio $from–$to';
  }

  @override
  String setCurrencySub(Object rate) {
    return 'USD principal · ZiG secundária · $rate';
  }

  @override
  String syncPill(Object count) {
    return '{count, plural, =1{1 alteração guardada neste dispositivo — sincroniza quando online} other{$count alterações guardadas neste dispositivo — sincronizam quando online}}';
  }

  @override
  String teenSplitHint(Object amount) {
    return 'Divisão sugerida dos $amount ganados este mês';
  }

  @override
  String get discardChangesTitle => 'Descartar alterações?';

  @override
  String get discardChangesBody => 'Ainda não foi guardado. Sair na mesma?';

  @override
  String get stay => 'Continuar a editar';

  @override
  String get leave => 'Sair';
}
