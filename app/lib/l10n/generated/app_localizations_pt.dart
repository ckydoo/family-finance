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
      'Entre com o seu telefone para abrir o seu espaço familiar.';

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
  String get loginFooter =>
      'Demonstração: entra com qualquer e-mail e palavra-passe (6+ caracteres).';

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
  String get membersDemoTip =>
      'Dica demo: use \"Ver como\" para trocar de perfil. As crianças entram num modo selado.';

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
  String get viewAs => 'Ver como';

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
  String get inviteDemoNote =>
      'O modo demo vem com uma família de exemplo. No modo live o seu código de convite vive aqui — partilhe-o e a família entra no seu espaço.';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get editProfileSub => 'Nome e avatar deste membro';

  @override
  String get photoNote =>
      'As fotos de perfil chegam com a sincronização familiar. Os avatares já estão ativos.';

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
}
