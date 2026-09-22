// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get tabHome => 'Inicio';

  @override
  String get tabBudgets => 'Presupuestos';

  @override
  String get tabSavings => 'Ahorros';

  @override
  String get tabLists => 'Listas';

  @override
  String get tabFamily => 'Familia';

  @override
  String get tabActivity => 'Actividad';

  @override
  String get greetingMorning => 'Buenos días';

  @override
  String get greetingAfternoon => 'Buenas tardes';

  @override
  String get greetingEvening => 'Buenas noches';

  @override
  String get familyPool => 'Fondo familiar';

  @override
  String safeToSpend(String amount) {
    return 'Seguro para gastar hoy: $amount';
  }

  @override
  String get seeAll => 'Ver todo';

  @override
  String get add => 'Añadir';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get undo => 'Deshacer';

  @override
  String get post => 'Registrar';

  @override
  String get skip => 'Omitir';

  @override
  String get approve => 'Aprobar';

  @override
  String get notThisWeek => 'No esta semana';

  @override
  String get done => 'Listo';

  @override
  String get export => 'Exportar';

  @override
  String get meeting => 'Reunión';

  @override
  String get newEnvelope => 'Nuevo sobre';

  @override
  String get recurringExpenses => 'Gastos recurrentes';

  @override
  String get shopping => 'Compras';

  @override
  String get activityTitle => 'Actividad';

  @override
  String get noActivityTitle => 'Aún no hay actividad';

  @override
  String get noActivityHint =>
      'Cada gasto, ingreso y aprobación aparece aquí — añade el primero con el botón +.';

  @override
  String get noGoals => 'Aún no hay metas';

  @override
  String get noGoalsHint =>
      'Empieza con un fondo de emergencia — aunque sea poco cada semana, cambia cómo se sienten las emergencias.';

  @override
  String get reportTitle => 'Boleta de progreso';

  @override
  String get income => 'Ingreso';

  @override
  String get spent => 'Gastado';

  @override
  String get saved => 'Ahorrado';

  @override
  String get safePerDay => 'Seguro / día';

  @override
  String get envelopeHealth => 'Salud de los sobres';

  @override
  String get cashLeak => 'Fuga de efectivo';

  @override
  String get shareReport => 'Compartir con la familia';

  @override
  String get meetingCta => 'Iniciar la reunión familiar';

  @override
  String get exportCsv => 'Exportar transacciones (CSV)';

  @override
  String get family => 'Familia';

  @override
  String get hi => 'Hola';

  @override
  String get mySavings => 'Mis ahorros';

  @override
  String get addToJar => 'Añadir al frasco';

  @override
  String get savingsMatch => 'Ahorro emparejado';

  @override
  String get savingsMatchNote =>
      'Los padres igualan el 50% de todo lo que ahorres';

  @override
  String get earnings => 'Ganancias';

  @override
  String get logEarning => 'Registrar ganancia';

  @override
  String get myProposals => 'Mis propuestas';

  @override
  String get proposeExpense => 'Proponer gasto';

  @override
  String get proposeTitle => 'Proponer un gasto';

  @override
  String get peek => 'Tus padres te dejan ver este sobre';

  @override
  String get plan => 'Plan: Gastar · Ahorrar · Dar';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get remindersOnDevice => 'Recordatorios en este dispositivo';

  @override
  String get remindersSubtitle =>
      'Facturas, presupuestos, niños, metas, círculos de ahorro y reuniones';

  @override
  String get quietHours =>
      'Horas de silencio (sin notificaciones dentro de esta ventana)';

  @override
  String get monthStartsOn => 'El mes empieza el día';

  @override
  String get language => 'Idioma';

  @override
  String get largeText => 'Texto grande (más fácil de leer)';

  @override
  String get exportCsvSettings => 'Exportar transacciones (CSV)';

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get remindersTitle => 'Recordatorios';

  @override
  String scheduledOn(String from, String to) {
    return 'Programados en este dispositivo · horas de silencio $from–$to';
  }

  @override
  String get remindersOff => 'Recordatorios desactivados';

  @override
  String get nothingComing => 'Nada a la vista';

  @override
  String get ob1Title => 'Dinero, gestionado en familia';

  @override
  String get ob1Body =>
      'Un lugar tranquilo para todo lo que tu familia gana, gasta, ahorra y planifica — en todas tus monedas, con o sin internet.';

  @override
  String get ob2Title => 'Sobres, no culpa';

  @override
  String get ob2Body =>
      'Dale a cada dólar un trabajo. Comida, escuela, transporte — ve de un vistazo qué va bien, qué necesita un repaso y qué es seguro gastar hoy.';

  @override
  String get ob3Title => 'Hecho para toda la familia';

  @override
  String get ob3Body =>
      'Las parejas comparten el plan. Los niños llenan frascos y ganan estrellas. Los adolescentes proponen gastos y aprenden con ahorro emparejado. La abuela lleva el registro del círculo de ahorro.';

  @override
  String get ob4Title => 'Recordatorios amables';

  @override
  String syncPill(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count cambios guardados en este dispositivo — se sincronizan al haber internet',
      one:
          '1 cambio guardado en este dispositivo — se sincroniza al haber internet',
    );
    return '$_temp0';
  }

  @override
  String get hideAmountsTip => 'Ocultar importes';

  @override
  String get showAmountsTip => 'Mostrar importes';

  @override
  String get themeLabel => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get sixMonthNet => 'Balance de 6 meses (USD)';

  @override
  String get donutEmpty =>
      'Sin gastos registrados este ciclo — el anillo se llena al añadir gastos.';

  @override
  String get ob4Body =>
      'Avisos de facturas, alertas de presupuesto y el resumen familiar semanal — con horario de silencio, todo en tu teléfono. Tú decides.';

  @override
  String get next => 'Siguiente';

  @override
  String get loginWelcome => 'Te damos la bienvenida a Mhuri Hub';

  @override
  String get loginEnterCode => 'Introduce el código';

  @override
  String loginSentCode(String phone) {
    return 'Enviamos un código por SMS al $phone';
  }

  @override
  String get loginSignInHint =>
      'Inicia sesión con tu teléfono para abrir tu espacio familiar.';

  @override
  String get loginSendCode => 'Enviar código';

  @override
  String get loginVerify => 'Verificar e iniciar sesión';

  @override
  String get loginChangeNumber => 'Cambiar número';

  @override
  String get loginBadPhone =>
      'Introduce un teléfono válido (p. ej. +44 7700 900123).';

  @override

  @override
  String get quickAddTitle => 'Añadir rápido';

  @override
  String get expense => 'Gasto';

  @override
  String get envelopeLabel => 'Sobre';

  @override
  String get whoLabel => 'Quién';

  @override
  String get paidWithLabel => 'Pagado con';

  @override
  String get noteHint => 'Nota (p. ej. FreshMart)';

  @override
  String get enterAmountFirst => 'Introduce primero un importe';

  @override
  String get savedOffline =>
      'Guardado ✓ — funciona sin internet, se sincroniza al conectar';

  @override
  String kidsHi(String name) {
    return '¡Hola $name!';
  }

  @override
  String get kidsMyJar => 'Mi tarro';

  @override
  String kidsGoalSaved(String goal, int pct) {
    return 'Meta: $goal — $pct% ahorrado';
  }

  @override
  String get kidsMyChores => 'Mis tareas';

  @override
  String get kidsWishList => 'Lista de deseos';

  @override
  String kidsWishItem(String amount) {
    return 'Pelota — US\$25 · ahorrado $amount';
  }

  @override
  String get kidsAskMoney => 'Pídeselo\na mamá o papá';

  @override
  String get kidsDoChore => 'Hacer una tarea';

  @override
  String get kidsAllDone => '¡Tareas completadas!';

  @override
  String get kidsParents => 'Papás';

  @override
  String get kidsAskTitle => 'Pedir a mamá y papá';

  @override
  String get kidsWhatFor => '¿Para qué?';

  @override
  String get kidsDefaultReason => 'Dinero de bolsillo';

  @override
  String get teenZoneTitle => 'Zona teen · 13–17';

  @override
  String get teenNoEarnings => 'Aún no hay ganancias registradas';

  @override
  String get teenEarnHint =>
      'Lava un coche, ayuda en la tienda — regístralo y mira crecer tu tarro.';

  @override
  String get teenSpend => 'Gastar 50%';

  @override
  String get teenSave => 'Ahorrar 40%';

  @override
  String get teenGive => 'Dar 10%';

  @override
  String teenSplitHint(String amount) {
    return 'Reparto sugerido de $amount ganado este mes';
  }

  @override
  String get teenSavedJar => 'Guardado en tu tarro — papás igualan el 50%';

  @override
  String get teenWhatDid => '¿Qué hiciste?';

  @override
  String get familyTitle => 'Familia';

  @override
  String get membersDesc => 'Pareja + niños · el mes empieza el 1';

  @override
  String get membersInviteHint =>
      'Comparte el código o escanea para invitar a un familiar';

  @override

  @override
  String get setCurrency => 'Moneda y tasas';

  @override
  String setCurrencySub(String rate) {
    return 'USD principal · ZiG secundaria · $rate';
  }

  @override
  String get setPrivacy => 'Privacidad';

  @override
  String get setPrivacySub =>
      'Bolsillos privados: no — la pareja ve solo lo compartido';

  @override
  String get setMonthStart => 'Inicio de mes';

  @override
  String get setMonthStartSub => 'Día 1 — alineado con el ciclo de sueldo';

  @override
  String get setNotif => 'Notificaciones';

  @override
  String get setNotifSub =>
      'Aviso 80% presupuesto · facturas · peticiones de los niños';

  @override
  String get setBackup => 'Copia y exportación';

  @override
  String get setBackupSub =>
      'Copia cifrada en la nube · exportación CSV (propietario)';

  @override
  String get meetingTitle => 'Reunión familiar';

  @override
  String get mFigures => 'El mes pasado, en números';

  @override
  String get figureIncome => 'Ingresos';

  @override
  String get figureSpent => 'Gastado';

  @override
  String get figureSaved => 'Ahorrado';

  @override
  String get mEnvelopeHealth => 'Salud de los sobres';

  @override
  String get mReachedTalk =>
      'Habla de los sobres marcados \"Alcanzado\". Rellénenlos juntos, con calma.';

  @override
  String get mGoals => 'Metas de ahorro';

  @override
  String get mChores => 'Tareas, tarros y peticiones';

  @override
  String get mImprove => 'Una cosa a mejorar';

  @override
  String recSkipped(String date) {
    return 'Omitido — próximo: $date';
  }

  @override
  String get recNew => 'Nuevo gasto recurrente';

  @override
  String get recReview =>
      'Nada se cobra automáticamente — tú revisas y registras todo.';

  @override
  String get recNoEnvelope => 'Sin sobre';

  @override
  String get recNextDue => 'Próximo vencimiento:';

  @override
  String get recNameAmount => 'Ponle nombre e importe';

  @override
  String get recSaveRule => 'Guardar regla';

  @override
  String get recNameHint => 'Nombre (p. ej. Cuota escolar)';

  @override
  String get roleOwner => 'Propietario';

  @override
  String get roleAdult => 'Adulto';

  @override
  String get roleTeen => 'Adolescente';

  @override
  String get roleKid => 'Niño';

  @override
  String get roleViewer => 'Abuelo · Espectador';

  @override
  String get methodCash => 'Efectivo';

  @override
  String get methodMobile => 'Dinero móvil';

  @override
  String get methodCard => 'Tarjeta';

  @override
  String get methodTransfer => 'Transferencia';

  @override
  String get methodAgent => 'Agente / punto de efectivo';

  @override
  String get methodOther => 'Otro';

  @override
  String get stateToBuy => 'Por comprar';

  @override
  String get stateInCart => 'En el carrito';

  @override
  String get stateDone => 'Hecho';

  @override
  String get freqWeekly => 'Semanal';

  @override
  String get freqMonthly => 'Mensual';

  @override
  String get rollReset => 'Reiniciar cada mes';

  @override
  String get rollRoll => 'Arrastrar el resto';

  @override
  String get rollAccum => 'Acumular';

  @override
  String get freqTerm => 'Por trimestre (~3 meses)';

  @override
  String get budgetsTitle => 'Presupuestos';

  @override
  String get noEnvelopes => 'Aún no hay sobres';

  @override
  String get envelopesHint =>
      'Los sobres son presupuestos visibles: comida, escuela, transporte. Crea el primero abajo.';

  @override
  String get newEnvStub => 'Nuevo sobre — en camino (Fase 1)';

  @override
  String get addRecurringTip => 'Añadir gasto recurrente';

  @override
  String get recReviewed =>
      'Se revisa antes de registrar — nada se cobra en silencio.';

  @override
  String get noRecurring => 'Aún no hay gastos recurrentes';

  @override
  String get recurringHint =>
      'Añade reglas de escuela, alquiler o aire — te avisamos cuando vence cada una.';

  @override
  String get chipOnTrack => 'En rumbo';

  @override
  String get chipReached => 'Alcanzado';

  @override
  String get remaining => 'Restante';

  @override
  String get moveMoney => 'Mover dinero';

  @override
  String get pickFirst => 'Elige primero sobres e importe';

  @override
  String get skipPeriod => 'Omitir este periodo';

  @override
  String get pauseRule => 'Pausar regla';

  @override
  String get resumeRule => 'Reanudar regla';

  @override
  String get meetingHint => '15 minutos, una vez al mes.';

  @override
  String mChoresLine(Object proposals, Object requests, Object stars) {
    return '$stars estrellas ganadas · $requests peticiones en espera · $proposals propuestas teen en espera.';
  }

  @override
  String get meetingNoteHint =>
      'p. ej. «Cocinar más los domingos — el gasto del mercado sube.»';

  @override
  String get meetingSaveNote => 'Guardar nuestra nota';

  @override
  String get savedTick => 'Guardado ✓';

  @override
  String get meetingDone => 'Listo — nos vemos el mes que viene';

  @override
  String get reportCard => 'Boletín';

  @override
  String get recentActivity => 'Actividad reciente';

  @override
  String get swapCurrency => 'Cambiar moneda de vista';

  @override
  String get yourChild => 'Tu hijo';

  @override
  String get review => 'Revisar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get markCollected => 'Marcar recaudado';

  @override
  String get decline => 'Rechazar';

  @override
  String get sentToParents => 'Enviado a papá y mamá';

  @override
  String get sendRequest => 'Enviar petición';

  @override
  String get parentsOnly => 'Solo papás';

  @override
  String get pinExitLine => 'Introduce tu PIN para salir del Modo Niños.';

  @override
  String get wrongPin => 'PIN incorrecto';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get addItem => 'Añadir artículo';

  @override
  String get listSharedSub =>
      'Lista de compras familiar · compartida con todos';

  @override
  String get tickFirst => 'Marca primero los artículos';

  @override
  String get namePriceFirst => 'Ponle nombre y precio al artículo';

  @override
  String get addToList => 'Añadir a la lista';

  @override
  String get spaceSetup => 'Configura tu espacio familiar';

  @override
  String get spaceSetupSub =>
      'Crea un espacio para tu familia o únete al que creó tu pareja con su código. Todo lo que registres se sincroniza entre sus teléfonos.';

  @override
  String get createSpace => 'Crear espacio';

  @override
  String get joinWithCode => 'Unirse con código';

  @override
  String get offlineRetry => 'Sin conexión — reintento automático';

  @override
  String get syncProblem => 'Problema de sincronización';

  @override
  String get signinExpired => 'Sesión caducada — sal y vuelve a entrar';

  @override
  String get syncing => 'Sincronizando…';

  @override
  String lastSync(Object last) {
    return 'Última sincronización: $last';
  }

  @override
  String get familySpace => 'Espacio familiar';

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get createFamilySpace => 'Crear espacio familiar';

  @override
  String get familyName => 'Nombre de la familia';

  @override
  String get localizedNote =>
      'La app entera ya habla seis idiomas — nada queda solo en inglés.';

  @override
  String get nextCreateSpace =>
      'Siguiente: crea tu espacio familiar (o únete con un código) desde la pestaña Familia.';

  @override
  String reachedMove(Object on, Object total) {
    return '$on de $total sobres siguen en rumbo. Abre los marcados «Alcanzado» y mueve dinero ahí — con calma, sin perfección.';
  }

  @override
  String get cashTrace =>
      'El efectivo es fácil de gastar y difícil de rastrear. Pagar algo más con dinero móvil o tarjeta mantiene la imagen más clara.';

  @override
  String get whereMoneyWent => 'A dónde fue el dinero';

  @override
  String get exportFailed => 'La exportación falló en este dispositivo';

  @override
  String csvSaved(Object path) {
    return 'CSV guardado: $path';
  }

  @override
  String exportedPath(Object path) {
    return 'Exportado ✓ $path';
  }

  @override
  String get bringToMeeting => 'Lleva esto a la Reunión Familiar mensual';

  @override
  String get savingsTitle => 'Ahorros';

  @override
  String get markRound => 'Marcar ronda recaudada';

  @override
  String get recordsOnly => 'Mhuri Hub nunca guarda el dinero — solo registra.';

  @override
  String get saveContribution => 'Guardar aporte';

  @override
  String get sendTest => 'Enviar notificación de prueba';

  @override
  String get testOk => 'Los recordatorios funcionan en este dispositivo.';

  @override
  String get monthCycle => 'Ciclo del mes';

  @override
  String get paydayAlign =>
      'Presupuestos alineados al sueldo — los ciclos se reinician este día y el aviso de la reunión llega la noche anterior';

  @override
  String get backupComing => 'Copia y restauración (pronto)';

  @override
  String get fromLabel => 'De';

  @override
  String get addTransaction => 'Añadir transacción';

  @override
  String get logWhatAmount => 'Añade qué hiciste y el importe';

  @override
  String get logIt => 'Registrar';

  @override
  String get fromEnvelope => 'Del sobre';

  @override
  String get amountPurposeFirst => 'Añade un importe y para qué es';

  @override
  String get sentApproval => 'Enviado a papá y mamá para aprobar';

  @override
  String get sendProposal => 'Enviar propuesta';

  @override
  String get stWaiting => 'En espera ⏳';

  @override
  String get stApproved => 'Aprobado ✓';

  @override
  String get stDeclined => 'Rechazado';

  @override
  String requestTitle(Object amount, Object name) {
    return '$name pidió $amount';
  }

  @override
  String proposalTitle(Object amount, Object name) {
    return '$name propone $amount';
  }

  @override
  String proposalSub(Object env, Object reason) {
    return '$reason · del sobre $env';
  }

  @override
  String recDueSub(Object when) {
    return 'Recurrente · vence $when · regístralo cuando lo pagues';
  }

  @override
  String get dueNow => 'ahora';

  @override
  String get dueSoon => 'pronto';

  @override
  String choreDoneTitle(Object name) {
    return '«$name» hecho — ¿confirmar?';
  }

  @override
  String choreDoneSub(Object stars) {
    return '$stars estrellas — confirma para hacer crecer el tarro';
  }

  @override
  String circleSub(Object amount, Object pot, Object who) {
    return 'A $who le toca recaudar $amount · bote $pot hasta ahora';
  }

  @override
  String get exportReal => 'La exportación funciona en un dispositivo real';

  @override
  String get allSynced => '✓ Todo sincronizado';

  @override
  String get familyCta => 'Familia ›';

  @override
  String get recentInEnv => 'Reciente en este sobre';

  @override
  String get nothingLogged => 'Nada registrado aquí todavía.';

  @override
  String dueBy(Object days) {
    return 'atrasado ${days}d';
  }

  @override
  String get dueToday => 'vence hoy';

  @override
  String get dueTomorrow => 'vence mañana';

  @override
  String dueIn(Object days) {
    return 'vence en ${days}d';
  }

  @override
  String circleTitle(Object round, Object total) {
    return 'Círculo de ahorro — Ronda $round de $total';
  }

  @override
  String postedSnack(Object name) {
    return '$name registrado ✓ — sobre actualizado';
  }

  @override
  String starsGiven(Object stars) {
    return '¡$stars estrellas para los niños!';
  }

  @override
  String approvedReq(Object amount, Object name) {
    return 'Aprobado ✓ — $amount añadido a $name';
  }

  @override
  String declineBody(Object env, Object reason) {
    return '$reason\n\nDel sobre: $env';
  }

  @override
  String approvedProp(Object amount, Object env) {
    return 'Aprobado ✓ — $amount registrado en $env';
  }

  @override
  String sentKid(Object name) {
    return '«$name» enviado a papá y mamá';
  }

  @override
  String get listEmptyAdd => 'Nada aquí — añade un artículo con ＋';

  @override
  String usesPct(Object name, Object pct) {
    return 'Usa $pct% del sobre $name';
  }

  @override
  String loggedTo(Object amount, Object name) {
    return 'Registrado $amount en $name ✓ — sobre actualizado';
  }

  @override
  String get finishShop => 'Terminar compra → registrar gasto';

  @override
  String estPrice(Object symbol) {
    return 'Precio unitario estimado ($symbol)';
  }

  @override
  String get myFamily => 'Mi familia';

  @override
  String spaceCreated(Object code) {
    return 'Espacio creado ✓ Código de invitación: $code';
  }

  @override
  String get createFail => 'No se pudo crear el espacio — inténtalo de nuevo';

  @override
  String get joinSpaceTitle => 'Unirse a un espacio familiar';

  @override
  String get inviteCode => 'Código de invitación';

  @override
  String get joinedOk => 'Unido ✓ — tus datos se están sincronizando';

  @override
  String get joinFail => 'No se pudo unir — inténtalo de nuevo';

  @override
  String get kidsPin => 'PIN de salida del Modo Niños';

  @override
  String get kidsPinSub =>
      'Necesario para salir del Modo Niños — toca para cambiarlo';

  @override
  String signedInAs(Object masked) {
    return 'Sesión: $masked';
  }

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get viewAs => 'Ver como';

  @override
  String cashShare(Object pct) {
    return '$pct% del gasto';
  }

  @override
  String donutA11y(Object name, Object share) {
    return 'Gasto por sobre, $name seleccionado, $share por ciento';
  }

  @override
  String starsHome(Object stars) {
    return '$stars estrellas — confirma tareas en Inicio para llenar tarros';
  }

  @override
  String circleMember(Object name) {
    return 'Círculo de ahorro · $name';
  }

  @override
  String potSoFar(Object pot) {
    return 'Bote hasta ahora: $pot';
  }

  @override
  String get roundOk =>
      'Ronda registrada ✓ — solo registros, nunca guardamos dinero';

  @override
  String addToGoal(Object name) {
    return 'Añadir a $name';
  }

  @override
  String addedToGoal(Object name) {
    return 'Añadido a $name';
  }

  @override
  String goalBase(Object short) {
    return 'Base de la meta: $short';
  }

  @override
  String syncTime(Object t) {
    return 'hoy a las $t';
  }

  @override
  String get watch => 'Vigilar';

  @override
  String get spentLabel => 'Gastado';

  @override
  String get limitLabel => 'Límite';

  @override
  String memberPot(Object contribution, Object count, Object pot) {
    return 'Bote: $pot · $contribution × $count miembros';
  }

  @override
  String get switchProfile => 'Cambiar de perfil';

  @override
  String get switchProfileSub => 'Ver la app como otro miembro de la familia';

  @override
  String get youTag => 'Tú';

  @override
  String get pickCurrency => 'Moneda de vista';

  @override
  String get rateField => 'ZiG por 1 USD';

  @override
  String get rateSave => 'Guardar tasa';

  @override
  String get rateReset => 'Volver a la referencia RBZ';

  @override
  String get rateCustomNote =>
      'Se usa para la vista en ZiG en toda la app. La referencia RBZ incluida es 15,27.';

  @override
  String get autoHide => 'Ocultar importes al salir de la app';

  @override
  String get autoHideSub =>
      'Los saldos se ocultan al pasar la app a segundo plano — desactívalo si lo prefieres.';

  @override
  String get hideNow => 'Ocultar importes ahora';

  @override
  String get exportCsvRow => 'Exportar todas las transacciones (CSV)';

  @override
  String get copyInvite => 'Copiar código de invitación';

  @override
  String get copied => 'Copiado ✓';

  @override
  String get inviteTitle => 'Invitar a un familiar';

  @override

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get editProfileSub => 'Nombre y avatar de este miembro';

  @override
  String get photoNote =>
      'Las fotos de perfil llegan con la sincronización familiar. Los avatares ya están activos.';

  @override
  String get accountTitle => 'Cuenta';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountTitle => '¿Eliminar tu cuenta?';

  @override
  String get deleteAccountBody =>
      'Esto elimina permanentemente tu acceso y los datos financieros guardados en este dispositivo. No se puede deshacer.';

  @override
  String get deleteAccountConfirm => 'Eliminar permanentemente';

  @override
  String get deleteAccountFailed =>
      'No pudimos eliminar tu cuenta. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String get moreDetails => 'Más detalles';

  @override
  String get lessDetails => 'Menos detalles';

  @override
  String get discardTitle => '¿Descartar esta entrada?';

  @override
  String get discardBody => 'Has introducido datos que aún no se han guardado.';

  @override
  String get keepEditing => 'Seguir editando';

  @override
  String get discard => 'Descartar';

  @override
  String get viewDetails => 'Ver detalles del saldo';

  @override
  String get fabTip => 'Toca + para registrar ingresos o gastos';

  @override
  String get emailLabel => 'Correo electrónico';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get loginSignIn => 'Iniciar sesión';

  @override
  String get loginCreateAccount => 'Crear cuenta';

  @override
  String get loginBadEmail => 'Introduce un correo válido.';

  @override
  String get loginShortPassword =>
      'La contraseña debe tener al menos 6 caracteres.';

  @override
  String get checkYourEmail =>
      'Casi listo: revisa tu correo y confirma tu email, después inicia sesión.';

  @override
  String get togglePassword => 'Mostrar u ocultar la contraseña';

  @override
  String get inviteHowTo =>
      'Crea una cuenta con su correo y luego introduce este código para unirse a tu familia.';

  @override
  String get obDone => 'Empecemos';

  @override
  String get setupChoiceTitle => "Configura tu familia";

  @override
  String get setupChoiceBody => "Mhuri Hub funciona para una familia, juntos. Crea la tuya o únete a la que perteneces.";

  @override
  String get setupCreateCard => "Crear una familia";

  @override
  String get setupCreateCardBody => "Ponle nombre, elige el tipo de hogar e invita a los tuyos.";

  @override
  String get setupJoinCard => "Unirse con un código";

  @override
  String get setupJoinCardBody => "Alguien te invitó: introduce su código familiar para unirte.";

  @override
  String get createFamilyCta => "Crear familia";

  @override
  String get joinFamilyCta => "Unirse a la familia";

  @override
  String get familyNameLabel => "Nombre de la familia";

  @override
  String get familyNameHint => "p. ej. La familia Marufu";

  @override
  String get householdLabel => "¿Qué tipo de familia?";

  @override
  String get hhCouple => "Pareja con hijos";

  @override
  String get hhSingle => "Padre/madre soltero";

  @override
  String get hhExtended => "Familia extendida";

  @override
  String get hhBlended => "Familia ensamblada";

  @override
  String get hhPartners => "Pareja sin hijos";

  @override
  String get hhSolo => "Solo yo por ahora";

  @override
  String get hhOther => "Otro";

  @override
  String get joinCodeLabel => "Código de invitación";

  @override
  String get skipForNow => "Omitir por ahora";

  @override
  String get setupInviteTitle => "Invita a los tuyos";

  @override
  String get setupWorking => "Preparando todo…";

  @override
  String get noEnvelopesYet => "Aún no hay sobres: crea el primero desde la pestaña Presupuestos.";

  @override
  String get noActivityYet => "Nada registrado todavía. Toca + para añadir tu primera transacción.";

  @override
  String get setupBanner => "Termina la configuración: crea tu familia o únete con un código";

  @override
  String get setupBannerCta => "Configurar";

  @override
  String get deleteTypeHint => "Escribe DELETE para confirmar";

  @override
  String get deletePermanently => "Eliminar permanentemente";
}
