import '../models/models.dart';
import '../money/money.dart';
import '../planning/commitments.dart';
import '../state/app_state.dart';

enum AskMhuriTopic {
  affordability,
  budgets,
  spending,
  members,
  bills,
  savings,
  debts,
  shopping,
  overview,
}

class AskMhuriLocalResult {
  const AskMhuriLocalResult({
    required this.answer,
    required this.facts,
    required this.topic,
    this.followUps = const [],
    this.isFallback = false,
  });

  final String answer;
  final Map<String, Object?> facts;
  final AskMhuriTopic topic;
  final List<String> followUps;
  final bool isFallback;
}

/// Instant, zero-latency, offline-capable household answer engine backed by
/// [AppState]. Computes exact per-currency figures without cross-currency
/// mixing, excludes private accounts and other children's jars, and produces
/// `facts` in the exact schema used by the `ask-mhuri` Edge Function.
class AskMhuriLocalEngine {
  const AskMhuriLocalEngine._();

  static const List<String> starterQuestions = [
    'How much can we safely spend right now?',
    'Where are we spending the most?',
    'Who spent the most this month?',
    'What bills are coming up?',
    'How are our savings goals doing?',
    'Can we afford something extra this month?',
  ];

  static AskMhuriTopic inferTopic(String question) {
    final q = question.toLowerCase();
    if (RegExp(r'\b(shopping|grocery list|groceries list|to buy|in cart|basket)\b')
            .hasMatch(q) ||
        (q.contains('list') && q.contains('shop'))) {
      return AskMhuriTopic.shopping;
    }
    if (RegExp(r'\b(who|member|everyone|partner|husband|wife|sister|brother|each person)\b')
            .hasMatch(q) &&
        RegExp(r'\b(spend|spent|spending|most|more|less|paid|expense)\b')
            .hasMatch(q)) {
      return AskMhuriTopic.members;
    }
    if (RegExp(r'\b(bill|bills|due|overdue|commitment|commitments|recurring|rent|subscription)\b')
        .hasMatch(q)) {
      return AskMhuriTopic.bills;
    }
    if (RegExp(r'\b(debt|debts|loan|loans|owe|owed|repay|repayment)\b')
        .hasMatch(q)) {
      return AskMhuriTopic.debts;
    }
    if (RegExp(r'\b(save|saving|savings|goal|goals|target|emergency fund)\b')
        .hasMatch(q)) {
      return AskMhuriTopic.savings;
    }
    if (RegExp(r'\b(afford|safely spend|safe to spend|extra|left to spend|available cash|buy a|purchase)\b')
        .hasMatch(q)) {
      return AskMhuriTopic.affordability;
    }
    if (RegExp(r'\b(budget|budgets|envelope|envelopes|limit|over budget|left in)\b')
        .hasMatch(q)) {
      return AskMhuriTopic.budgets;
    }
    if (RegExp(r'\b(spend|spent|spending|top categor|most on|last month|previous|compare|income)\b')
        .hasMatch(q)) {
      return AskMhuriTopic.spending;
    }
    return AskMhuriTopic.overview;
  }

  static List<String> followUpsFor(AskMhuriTopic topic) => switch (topic) {
        AskMhuriTopic.affordability => const [
            'What bills are coming up?',
            'Where are we spending the most?',
          ],
        AskMhuriTopic.budgets => const [
            'How much can we safely spend right now?',
            'Who spent the most this month?',
          ],
        AskMhuriTopic.spending => const [
            'Who spent the most this month?',
            'How are our budgets looking?',
          ],
        AskMhuriTopic.members => const [
            'Where are we spending the most?',
            'How are our budgets looking?',
          ],
        AskMhuriTopic.bills => const [
            'How much can we safely spend right now?',
            'How are our savings goals doing?',
          ],
        AskMhuriTopic.savings => const [
            'How much can we safely spend right now?',
            'What bills are coming up?',
          ],
        AskMhuriTopic.debts => const [
            'What bills are coming up?',
            'How much can we safely spend right now?',
          ],
        AskMhuriTopic.shopping => const [
            'How are our budgets looking?',
            'How much can we safely spend right now?',
          ],
        AskMhuriTopic.overview => const [
            'Where are we spending the most?',
            'What bills are coming up?',
          ],
      };

  /// Returns an instant, deterministic answer when [question] is a direct
  /// factual lookup, or `null` when deeper multi-turn / strategic AI coaching
  /// should be preferred.
  static AskMhuriLocalResult? tryAnswer(
    AppState state,
    String question, {
    bool hasPriorTurns = false,
  }) {
    if (!_roleAllowed(state)) return null;
    final trimmed = question.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();

    // Defer follow-up pronoun / coaching / strategy prompts to cloud AI when online.
    if (hasPriorTurns &&
        RegExp(r'^(and\b|what about\b|how about\b|why\b|what if\b|if we\b|instead\b|tell me more)')
            .hasMatch(lower)) {
      return null;
    }
    if (RegExp(
      r'\b(advice|advise|strategy|tips|recommend|how should we|help us plan|cut back|reduce our|trade-?off|why did we|what happens if)\b',
    ).hasMatch(lower)) {
      return null;
    }

    final snap = _Snapshot.fromState(state, trimmed);

    // 1. Named budget envelope lookup ("How much is left in Groceries?")
    final matchedEnvelope = _matchNamedBudget(snap.budgets, lower);
    if (matchedEnvelope != null &&
        !RegExp(r'\b(who|bill|due|goal|debt|shopping)\b').hasMatch(lower)) {
      return _answerSingleBudget(snap, matchedEnvelope);
    }

    // 2. Shopping list questions
    if (RegExp(r'\b(shopping|grocery list|groceries list|to buy|in cart|on our list)\b')
        .hasMatch(lower)) {
      return _answerShopping(snap);
    }

    // 3. Member spending & comparison ("Who spent the most?", "How much did I spend?")
    if ((RegExp(r'\b(who|member|everyone|partner|husband|wife|sister|brother|each person)\b')
                .hasMatch(lower) &&
            RegExp(r'\b(spend|spent|spending|most|more|less|paid|expense)\b')
                .hasMatch(lower)) ||
        RegExp(r'\bhow much (did|have) i spen[dt]\b').hasMatch(lower)) {
      return _answerMemberSpending(snap, lower);
    }

    // 4. Upcoming bills & recurring rules
    if (RegExp(r'\b(bill|bills|due|overdue|commitment|commitments|recurring|upcoming payment)\b')
        .hasMatch(lower)) {
      return _answerBills(snap);
    }

    // 5. Debts
    if (RegExp(r'\b(debt|debts|loan|loans|owe|owed|repay|repayment)\b')
        .hasMatch(lower)) {
      return _answerDebts(snap);
    }

    // 6. Savings goals
    if (RegExp(r'\b(save|saving|savings|goal|goals|target|emergency fund)\b')
        .hasMatch(lower)) {
      return _answerGoals(snap);
    }

    // 7. Safe to spend / Affordability / Purchase check
    if (RegExp(
      r'\b(afford|safely spend|safe to spend|available to spend|extra this month|left to spend|can we buy|can i buy)\b',
    ).hasMatch(lower)) {
      return _answerAffordability(snap);
    }

    // 8. Budget health overview
    if (RegExp(r'\b(budget|budgets|envelope|envelopes|over budget)\b')
        .hasMatch(lower)) {
      return _answerBudgetsOverview(snap);
    }

    // 9. Spending summary / Top categories / Period comparison
    if (RegExp(
      r'\b(where are we spending|spending the most|spent this|how much have we spent|top categor|compare|last month|previous month|income this)\b',
    ).hasMatch(lower)) {
      return _answerSpending(snap, lower);
    }

    return null;
  }

  /// Offline / cloud-unavailable fallback so the user always gets accurate
  /// household figures immediately even without internet or cloud quota.
  static AskMhuriLocalResult fallbackAnswer(AppState state, String question) {
    final direct = tryAnswer(state, question, hasPriorTurns: false);
    if (direct != null) {
      return AskMhuriLocalResult(
        answer: direct.answer,
        facts: direct.facts,
        topic: direct.topic,
        followUps: direct.followUps,
        isFallback: true,
      );
    }
    final snap = _Snapshot.fromState(state, question);
    final topic = inferTopic(question);
    final result = switch (topic) {
      AskMhuriTopic.shopping => _answerShopping(snap),
      AskMhuriTopic.members => _answerMemberSpending(snap, question.toLowerCase()),
      AskMhuriTopic.bills => _answerBills(snap),
      AskMhuriTopic.debts => _answerDebts(snap),
      AskMhuriTopic.savings => _answerGoals(snap),
      AskMhuriTopic.affordability => _answerAffordability(snap),
      AskMhuriTopic.budgets => _answerBudgetsOverview(snap),
      AskMhuriTopic.spending => _answerSpending(snap, question.toLowerCase()),
      AskMhuriTopic.overview => _answerOverview(snap),
    };
    return AskMhuriLocalResult(
      answer: result.answer,
      facts: result.facts,
      topic: result.topic,
      followUps: result.followUps,
      isFallback: true,
    );
  }

  static bool _roleAllowed(AppState state) {
    final role = state.authRole;
    return role != Role.kid && role != Role.teen;
  }

  static Map<String, Object?>? _matchNamedBudget(
    List<Map<String, Object?>> budgets,
    String lowerQuestion,
  ) {
    Map<String, Object?>? best;
    var bestLen = 0;
    for (final b in budgets) {
      final name = (b['name']?.toString() ?? '').trim();
      if (name.length < 3) continue;
      final lowerName = name.toLowerCase();
      if (lowerQuestion.contains(lowerName) && lowerName.length > bestLen) {
        best = b;
        bestLen = lowerName.length;
      }
    }
    return best;
  }

  static AskMhuriLocalResult _answerSingleBudget(
    _Snapshot snap,
    Map<String, Object?> budget,
  ) {
    final name = budget['name']?.toString() ?? 'Budget';
    final code = budget['currency']?.toString() ?? snap.baseCurrency.code;
    final complete = budget['complete'] == true;
    final limit = (budget['limit_minor'] as int?) ?? 0;
    if (!complete) {
      return AskMhuriLocalResult(
        answer:
            '**$name** has a **${_fmt(limit, code)}** limit, but includes mixed-currency allocations so its exact remaining balance cannot be combined into one currency.',
        facts: snap.facts,
        topic: AskMhuriTopic.budgets,
        followUps: followUpsFor(AskMhuriTopic.budgets),
      );
    }
    final spent = (budget['spent_minor'] as int?) ?? 0;
    final remaining = (budget['remaining_minor'] as int?) ?? (limit - spent);
    final statusLine = remaining >= 0
        ? '**${_fmt(remaining, code)} left** in **$name** this cycle (${_fmt(spent, code)} spent of ${_fmt(limit, code)}).'
        : '**$name is over budget by ${_fmt(remaining.abs(), code)}** (${_fmt(spent, code)} spent against a ${_fmt(limit, code)} limit).';
    final daysLeft = snap.daysLeftInCycle;
    final paceLine = remaining > 0 && daysLeft > 0
        ? 'With **$daysLeft day${daysLeft == 1 ? '' : 's'}** until the next cycle (${snap.nextCycleIso}), that leaves roughly **${_fmt((remaining / daysLeft).floor(), code)}/day**.'
        : 'Cycle runs ${snap.cycleStartIso} to ${snap.nextCycleIso}.';
    return AskMhuriLocalResult(
      answer: '$statusLine\n$paceLine',
      facts: snap.facts,
      topic: AskMhuriTopic.budgets,
      followUps: followUpsFor(AskMhuriTopic.budgets),
    );
  }

  static AskMhuriLocalResult _answerAffordability(_Snapshot snap) {
    final scenario = snap.purchaseScenario;
    if (scenario != null) {
      final status = scenario['status']?.toString();
      if (status == 'currency_required') {
        final minor = (scenario['purchase_minor'] as int?) ?? 0;
        final major = (minor / 100).toStringAsFixed(2);
        return AskMhuriLocalResult(
          answer:
              'Please confirm which currency you mean for **$major** (${snap.activeCurrencyCodes.join(' or ')}) so I can check the matching balance and upcoming bills without mixing currencies.',
          facts: snap.facts,
          topic: AskMhuriTopic.affordability,
          followUps: followUpsFor(AskMhuriTopic.affordability),
        );
      }
      if (status == 'insufficient_balance_data') {
        final code = scenario['currency']?.toString() ?? snap.baseCurrency.code;
        final purchase = (scenario['purchase_minor'] as int?) ?? 0;
        return AskMhuriLocalResult(
          answer:
              'There is no recorded shared **$code** balance yet to check a **${_fmt(purchase, code)}** purchase. Add your account opening balance or income in Mhuri first.',
          facts: snap.facts,
          topic: AskMhuriTopic.affordability,
          followUps: followUpsFor(AskMhuriTopic.affordability),
        );
      }
      final code = scenario['currency']?.toString() ?? snap.baseCurrency.code;
      final purchase = (scenario['purchase_minor'] as int?) ?? 0;
      final beforeBills = (scenario['spendable_before_bills_minor'] as int?) ?? 0;
      final bills = (scenario['upcoming_bills_before_next_cycle_minor'] as int?) ?? 0;
      final afterPurchase = (scenario['estimated_after_purchase_minor'] as int?) ?? 0;
      final fits = scenario['fits_recorded_cash_estimate'] == true;
      final headline = fits
          ? '**Yes — ${_fmt(purchase, code)} fits your recorded cash**, leaving an estimated **${_fmt(afterPurchase, code)}** after upcoming bills.'
          : '**Tight right now — ${_fmt(purchase, code)} exceeds recorded cash after upcoming bills by ${_fmt(afterPurchase.abs(), code)}.**';
      final bullets = <String>[
        '- Available after recorded savings: **${_fmt(beforeBills, code)}**',
        '- Unpaid bills before ${snap.nextCycleIso}: **${_fmt(bills, code)}**',
        '- Estimated cash after bills & purchase: **${_fmt(afterPurchase, code)}**',
      ];
      return AskMhuriLocalResult(
        answer: '$headline\n${bullets.join('\n')}',
        facts: snap.facts,
        topic: AskMhuriTopic.affordability,
        followUps: followUpsFor(AskMhuriTopic.affordability),
      );
    }

    if (snap.availableAfterSavings.isEmpty) {
      return AskMhuriLocalResult(
        answer:
            'No shared balances or transactions are recorded yet. Log your shared account balance or income first to see what is safe to spend.',
        facts: snap.facts,
        topic: AskMhuriTopic.affordability,
        followUps: followUpsFor(AskMhuriTopic.affordability),
      );
    }

    final lines = <String>[];
    String? lead;
    for (final row in snap.availableAfterSavings) {
      final code = row['currency']?.toString() ?? snap.baseCurrency.code;
      final avail = (row['minor_units'] as int?) ?? 0;
      final dueBeforeNext = snap.billsBeforeNextCycleByCurrency[code] ?? 0;
      final afterBills = avail - dueBeforeNext;
      lead ??= afterBills >= 0
          ? '**${_fmt(afterBills, code)} is available after savings and upcoming bills** before ${snap.nextCycleIso}.'
          : '**Upcoming bills exceed recorded $code cash by ${_fmt(afterBills.abs(), code)}** before ${snap.nextCycleIso}.';
      lines.add(
        '- **$code**: ${_fmt(avail, code)} after savings · ${_fmt(dueBeforeNext, code)} in bills due before ${snap.nextCycleIso} → **${_fmt(afterBills, code)}** cushion',
      );
    }
    final overCount = snap.budgets
        .where((b) => b['complete'] == true && ((b['remaining_minor'] as int?) ?? 0) < 0)
        .length;
    if (overCount > 0) {
      lines.add(
        '- Note: **$overCount budget${overCount == 1 ? ' is' : 's are'}** currently over limit this cycle.',
      );
    }
    return AskMhuriLocalResult(
      answer: '${lead ?? ''}\n${lines.join('\n')}'.trim(),
      facts: snap.facts,
      topic: AskMhuriTopic.affordability,
      followUps: followUpsFor(AskMhuriTopic.affordability),
    );
  }

  static AskMhuriLocalResult _answerSpending(_Snapshot snap, String lower) {
    final nonZeroSpend = snap.cycleSpending
        .where((r) => ((r['minor_units'] as int?) ?? 0) > 0)
        .toList();
    if (nonZeroSpend.isEmpty) {
      return AskMhuriLocalResult(
        answer:
            '**No shared expenses are recorded yet** for this cycle (${snap.cycleStartIso} to ${snap.nextCycleIso}).',
        facts: snap.facts,
        topic: AskMhuriTopic.spending,
        followUps: followUpsFor(AskMhuriTopic.spending),
      );
    }

    final totalParts = nonZeroSpend
        .map((r) => _fmt(r['minor_units'] as int, r['currency'].toString()))
        .join(' and ');
    final top = snap.topCategories;
    final headline = top.isNotEmpty
        ? '**${top.first['name']} leads spending at ${_fmt(top.first['spent_minor'] as int, top.first['currency'].toString())}** out of **$totalParts** spent this cycle.'
        : '**$totalParts spent** in shared expenses since ${snap.cycleStartIso}.';

    final bullets = <String>[];
    for (final cat in top.take(4)) {
      bullets.add(
        '- **${cat['name']}**: ${_fmt(cat['spent_minor'] as int, cat['currency'].toString())}',
      );
    }
    for (final curRow in nonZeroSpend) {
      final code = curRow['currency'].toString();
      final curMinor = curRow['minor_units'] as int;
      final prevMinor = snap.previousCycleSpending
              .where((p) => p['currency'] == code)
              .map((p) => (p['minor_units'] as int?) ?? 0)
              .firstOrNull ??
          0;
      if (prevMinor > 0 || lower.contains('last') || lower.contains('previous') || lower.contains('compare')) {
        final diff = curMinor - prevMinor;
        final dir = diff == 0
            ? 'unchanged vs last cycle'
            : diff > 0
                ? 'up ${_fmt(diff, code)} vs last cycle (${_fmt(prevMinor, code)})'
                : 'down ${_fmt(diff.abs(), code)} vs last cycle (${_fmt(prevMinor, code)})';
        bullets.add('- **$code cycle comparison**: $dir');
      }
    }

    return AskMhuriLocalResult(
      answer: bullets.isEmpty ? headline : '$headline\n${bullets.join('\n')}',
      facts: snap.facts,
      topic: AskMhuriTopic.spending,
      followUps: followUpsFor(AskMhuriTopic.spending),
    );
  }

  static AskMhuriLocalResult _answerMemberSpending(_Snapshot snap, String lower) {
    final rows = snap.memberSpending;
    if (rows.isEmpty) {
      return AskMhuriLocalResult(
        answer:
            '**No shared member expenses are recorded yet** in this cycle (${snap.cycleStartIso} to ${snap.nextCycleIso}).',
        facts: snap.facts,
        topic: AskMhuriTopic.members,
        followUps: followUpsFor(AskMhuriTopic.members),
      );
    }

    final asksSelf = RegExp(r'\bhow much (did|have) i spen[dt]\b').hasMatch(lower);
    if (asksSelf) {
      final mine = rows.where((r) => r['is_you'] == true).toList();
      if (mine.isEmpty) {
        return AskMhuriLocalResult(
          answer:
              '**You have 0 recorded shared expenses** so far this cycle (since ${snap.cycleStartIso}).',
          facts: snap.facts,
          topic: AskMhuriTopic.members,
          followUps: followUpsFor(AskMhuriTopic.members),
        );
      }
      final parts = mine
          .map((r) =>
              '**${_fmt(r['spent_minor'] as int, r['currency'].toString())}** (${r['share_percent']}% of shared ${r['currency']} spending across ${r['tx_count']} transaction${r['tx_count'] == 1 ? '' : 's'})')
          .join(' and ');
      return AskMhuriLocalResult(
        answer: 'You have recorded $parts this cycle.',
        facts: snap.facts,
        topic: AskMhuriTopic.members,
        followUps: followUpsFor(AskMhuriTopic.members),
      );
    }

    final top = rows.first;
    final topLabel = top['is_you'] == true ? '${top['name']} (you)' : '${top['name']}';
    final topAmt = _fmt(top['spent_minor'] as int, top['currency'].toString());
    final headline =
        '**$topLabel recorded the most shared spending** this cycle at **$topAmt** (${top['share_percent']}% of ${top['currency']} spending).';
    final bullets = rows.take(5).map((r) {
      final who = r['is_you'] == true ? '${r['name']} (you)' : '${r['name']}';
      final amt = _fmt(r['spent_minor'] as int, r['currency'].toString());
      final cnt = r['tx_count'] as int;
      return '- **$who**: $amt (${r['share_percent']}% · $cnt expense${cnt == 1 ? '' : 's'})';
    }).join('\n');

    return AskMhuriLocalResult(
      answer: '$headline\n$bullets',
      facts: snap.facts,
      topic: AskMhuriTopic.members,
      followUps: followUpsFor(AskMhuriTopic.members),
    );
  }

  static AskMhuriLocalResult _answerBudgetsOverview(_Snapshot snap) {
    final complete = snap.budgets.where((b) => b['complete'] == true).toList();
    if (complete.isEmpty) {
      return AskMhuriLocalResult(
        answer:
            '**No shared budgets are set up yet.** Open **Budgets** to set category limits for your household.',
        facts: snap.facts,
        topic: AskMhuriTopic.budgets,
        followUps: followUpsFor(AskMhuriTopic.budgets),
      );
    }
    final over = complete.where((b) => ((b['remaining_minor'] as int?) ?? 0) < 0).toList();
    final onTrackCount = complete.length - over.length;
    final headline = over.isEmpty
        ? '**All ${complete.length} shared budgets are within limit** this cycle.'
        : '**${over.length} of ${complete.length} budgets ${over.length == 1 ? 'is' : 'are'} over limit** ($onTrackCount on track).';
    final prioritized = [
      ...over,
      ...complete.where((b) => ((b['remaining_minor'] as int?) ?? 0) >= 0),
    ].take(5);
    final bullets = prioritized.map((b) {
      final code = b['currency'].toString();
      final rem = b['remaining_minor'] as int;
      final lim = b['limit_minor'] as int;
      final stateText = rem >= 0
          ? '**${_fmt(rem, code)} left** of ${_fmt(lim, code)}'
          : '**over by ${_fmt(rem.abs(), code)}** (limit ${_fmt(lim, code)})';
      return '- **${b['name']}**: $stateText';
    }).join('\n');

    return AskMhuriLocalResult(
      answer: '$headline\n$bullets',
      facts: snap.facts,
      topic: AskMhuriTopic.budgets,
      followUps: followUpsFor(AskMhuriTopic.budgets),
    );
  }

  static AskMhuriLocalResult _answerBills(_Snapshot snap) {
    final bills = snap.upcomingCommitments;
    if (bills.isEmpty) {
      return AskMhuriLocalResult(
        answer:
            '**No unpaid bills or recurring payments are due** in the next 45 days.',
        facts: snap.facts,
        topic: AskMhuriTopic.bills,
        followUps: followUpsFor(AskMhuriTopic.bills),
      );
    }
    final totalsByCur = <String, int>{};
    for (final b in bills) {
      final code = b['currency'].toString();
      totalsByCur[code] = (totalsByCur[code] ?? 0) + ((b['amount_minor'] as int?) ?? 0);
    }
    final totalText = totalsByCur.entries
        .map((e) => '**${_fmt(e.value, e.key)}**')
        .join(' and ');
    final headline =
        '**${bills.length} upcoming bill${bills.length == 1 ? '' : 's'} totaling $totalText** over the next 45 days:';
    final bullets = bills.take(5).map((b) {
      final code = b['currency'].toString();
      final amt = _fmt(b['amount_minor'] as int, code);
      final due = _shortDate(b['due_date']?.toString());
      final overdue = b['overdue'] == true ? ' *(overdue)*' : '';
      return '- **${b['name']}**: $amt · due $due$overdue';
    }).join('\n');
    final extra = bills.length > 5 ? '\n- …plus ${bills.length - 5} more in Upcoming Bills.' : '';
    return AskMhuriLocalResult(
      answer: '$headline\n$bullets$extra',
      facts: snap.facts,
      topic: AskMhuriTopic.bills,
      followUps: followUpsFor(AskMhuriTopic.bills),
    );
  }

  static AskMhuriLocalResult _answerGoals(_Snapshot snap) {
    final goals = snap.savingsGoals.where((g) => g['complete'] == true).toList();
    if (goals.isEmpty) {
      return AskMhuriLocalResult(
        answer:
            '**No active savings goals are recorded yet.** Open **Savings** to set a target such as an emergency fund or school fees.',
        facts: snap.facts,
        topic: AskMhuriTopic.savings,
        followUps: followUpsFor(AskMhuriTopic.savings),
      );
    }
    final first = goals.first;
    final fCode = first['currency'].toString();
    final fSaved = first['saved_minor'] as int;
    final fTarget = first['target_minor'] as int;
    final headline = goals.length == 1
        ? '**${first['name']} is at ${_fmt(fSaved, fCode)}** of its **${_fmt(fTarget, fCode)}** target.'
        : '**Tracking ${goals.length} active savings goals:**';
    final bullets = goals.take(4).map((g) {
      final code = g['currency'].toString();
      final saved = g['saved_minor'] as int;
      final target = g['target_minor'] as int;
      final rem = g['remaining_minor'] as int;
      final weekly = g['required_weekly_minor'] as int?;
      final pace = weekly != null && rem > 0 ? ' · need **${_fmt(weekly, code)}/wk**' : '';
      return '- **${g['name']}**: ${_fmt(saved, code)} saved, **${_fmt(rem, code)} to go** (target ${_fmt(target, code)})$pace';
    }).join('\n');

    return AskMhuriLocalResult(
      answer: '$headline\n$bullets',
      facts: snap.facts,
      topic: AskMhuriTopic.savings,
      followUps: followUpsFor(AskMhuriTopic.savings),
    );
  }

  static AskMhuriLocalResult _answerDebts(_Snapshot snap) {
    final debts = snap.debts.where((d) => d['complete'] == true).toList();
    if (debts.isEmpty) {
      return AskMhuriLocalResult(
        answer: '**No active family debts are recorded right now.**',
        facts: snap.facts,
        topic: AskMhuriTopic.debts,
        followUps: followUpsFor(AskMhuriTopic.debts),
      );
    }
    final bullets = debts.take(5).map((d) {
      final code = d['currency'].toString();
      final rem = d['remaining_minor'] as int;
      final orig = d['original_minor'] as int;
      final dir = d['direction']?.toString() == 'owedToMe' ? 'owed to family' : 'family owes';
      return '- **${d['name']}** ($dir): **${_fmt(rem, code)} remaining** of ${_fmt(orig, code)}';
    }).join('\n');
    return AskMhuriLocalResult(
      answer: '**${debts.length} active debt record${debts.length == 1 ? '' : 's'}:**\n$bullets',
      facts: snap.facts,
      topic: AskMhuriTopic.debts,
      followUps: followUpsFor(AskMhuriTopic.debts),
    );
  }

  static AskMhuriLocalResult _answerShopping(_Snapshot snap) {
    if (snap.openShoppingItems.isEmpty) {
      return AskMhuriLocalResult(
        answer: '**Your shopping list is clear** — 0 open items right now.',
        facts: snap.facts,
        topic: AskMhuriTopic.shopping,
        followUps: followUpsFor(AskMhuriTopic.shopping),
      );
    }
    final summaryText = snap.shoppingSummary
        .map((s) =>
            '**${s['open_items']} item${s['open_items'] == 1 ? '' : 's'}** (~${_fmt(s['estimated_minor'] as int, s['currency'].toString())})')
        .join(' and ');
    final preview = snap.openShoppingItems
        .take(5)
        .map((i) => '- **${i.name}**${i.qty > 1 ? ' ×${i.qty}' : ''}'
            '${i.est.minor > 0 ? ' · est. ${Money(i.est.minor * i.qty, i.est.currency).text}' : ''}')
        .join('\n');
    return AskMhuriLocalResult(
      answer: 'You have $summaryText on your shopping list:\n$preview',
      facts: snap.facts,
      topic: AskMhuriTopic.shopping,
      followUps: followUpsFor(AskMhuriTopic.shopping),
    );
  }

  static AskMhuriLocalResult _answerOverview(_Snapshot snap) {
    final bullets = <String>[];
    for (final row in snap.availableAfterSavings.take(2)) {
      final code = row['currency'].toString();
      final avail = row['minor_units'] as int;
      bullets.add('- **Available after savings ($code)**: ${_fmt(avail, code)}');
    }
    for (final row in snap.cycleSpending.where((r) => ((r['minor_units'] as int?) ?? 0) > 0)) {
      final code = row['currency'].toString();
      bullets.add('- **Spent since ${snap.cycleStartIso} ($code)**: ${_fmt(row['minor_units'] as int, code)}');
    }
    if (snap.upcomingCommitments.isNotEmpty) {
      final nextBill = snap.upcomingCommitments.first;
      bullets.add(
        '- **Next bill**: ${nextBill['name']} (${_fmt(nextBill['amount_minor'] as int, nextBill['currency'].toString())}, due ${_shortDate(nextBill['due_date']?.toString())})',
      );
    }
    if (bullets.isEmpty) {
      return AskMhuriLocalResult(
        answer:
            '**Your household snapshot is ready**, with no shared transactions or bills recorded yet this cycle.',
        facts: snap.facts,
        topic: AskMhuriTopic.overview,
        followUps: followUpsFor(AskMhuriTopic.overview),
      );
    }
    return AskMhuriLocalResult(
      answer: '**Here is your current household snapshot:**\n${bullets.join('\n')}',
      facts: snap.facts,
      topic: AskMhuriTopic.overview,
      followUps: followUpsFor(AskMhuriTopic.overview),
    );
  }

  static String _fmt(int minor, String currencyCode) {
    final match = Currency.values
        .where((c) => c.code.toUpperCase() == currencyCode.toUpperCase())
        .firstOrNull;
    if (match != null) return Money(minor, match).text;
    return '$currencyCode ${(minor / 100).toStringAsFixed(2)}';
  }

  static String _shortDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'soon';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${parsed.day} ${months[parsed.month - 1]}';
  }
}

class _Snapshot {
  _Snapshot({
    required this.baseCurrency,
    required this.activeCurrencyCodes,
    required this.cycleStartIso,
    required this.nextCycleIso,
    required this.daysLeftInCycle,
    required this.cycleSpending,
    required this.cycleIncome,
    required this.previousCycleSpending,
    required this.availableAfterSavings,
    required this.billsBeforeNextCycleByCurrency,
    required this.memberSpending,
    required this.budgets,
    required this.topCategories,
    required this.upcomingCommitments,
    required this.savingsGoals,
    required this.debts,
    required this.shoppingSummary,
    required this.openShoppingItems,
    required this.purchaseScenario,
    required this.facts,
  });

  final Currency baseCurrency;
  final List<String> activeCurrencyCodes;
  final String cycleStartIso;
  final String nextCycleIso;
  final int daysLeftInCycle;
  final List<Map<String, Object?>> cycleSpending;
  final List<Map<String, Object?>> cycleIncome;
  final List<Map<String, Object?>> previousCycleSpending;
  final List<Map<String, Object?>> availableAfterSavings;
  final Map<String, int> billsBeforeNextCycleByCurrency;
  final List<Map<String, Object?>> memberSpending;
  final List<Map<String, Object?>> budgets;
  final List<Map<String, Object?>> topCategories;
  final List<Map<String, Object?>> upcomingCommitments;
  final List<Map<String, Object?>> savingsGoals;
  final List<Map<String, Object?>> debts;
  final List<Map<String, Object?>> shoppingSummary;
  final List<ListItem> openShoppingItems;
  final Map<String, Object?>? purchaseScenario;
  final Map<String, Object?> facts;

  static String _isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory _Snapshot.fromState(AppState state, String question) {
    // Household-anchored wall clock (#2): a Harare family with members in
    // London or New York gets the same cycle dates in Ask Mhuri answers.
    final wall = state.householdNow;
    final today = DateTime(wall.year, wall.month, wall.day);
    final cycleStart = state.cycleStart;
    final nextCycle = state.nextCycleStart;
    final prevCycleStart = state.cycleStartAtOffset(1);

    final sharedTxs = state.familyTransactions;
    final currencies = <Currency>{
      state.primaryCurrency,
      if (state.secondaryCurrency != null) state.secondaryCurrency!,
      for (final a in state.accounts)
        if (!a.isPrivate) a.balance.currency,
      for (final t in sharedTxs) t.amount.currency,
    }.toList();

    List<Map<String, Object?>> sumTx(TxType kind, DateTime from, DateTime to) {
      return [
        for (final c in currencies)
          {
            'currency': c.code,
            'minor_units': sharedTxs
                .where((t) =>
                    t.type == kind &&
                    t.amount.currency == c &&
                    !t.when.isBefore(from) &&
                    t.when.isBefore(to))
                .fold<int>(0, (s, t) => s + t.amount.minor),
          },
      ];
    }

    final cycleSpending = sumTx(TxType.expense, cycleStart, nextCycle);
    final cycleIncome = sumTx(TxType.income, cycleStart, nextCycle);
    final prevSpending = sumTx(TxType.expense, prevCycleStart, cycleStart);
    final prevIncome = sumTx(TxType.income, prevCycleStart, cycleStart);

    // Exact per-currency shared balances & available after recorded savings
    final visibleGoalIds = {
      for (final g in state.goals)
        if (g.status == 'active' &&
            !(g.isKidJar && g.ownerMemberId != state.realUser.id))
          g.id,
    };
    final accountBalances = <Map<String, Object?>>[];
    final availableAfterSavings = <Map<String, Object?>>[];
    for (final c in currencies) {
      var bal = 0;
      var hasAny = c == state.primaryCurrency;
      for (final a in state.accounts) {
        if (a.isPrivate || a.balance.currency != c) continue;
        hasAny = true;
        bal += a.balance.minor;
      }
      for (final t in sharedTxs) {
        if (t.amount.currency != c) continue;
        hasAny = true;
        if (t.type == TxType.income) {
          bal += t.amount.minor;
        } else if (t.type == TxType.expense) {
          bal -= t.amount.minor;
        }
      }
      var saved = 0;
      for (final gt in state.goalTxs) {
        if (visibleGoalIds.contains(gt.goalId) && gt.amount.currency == c) {
          saved += gt.amount.minor;
        }
      }
      if (hasAny || saved > 0) {
        accountBalances.add({'currency': c.code, 'minor_units': bal});
        availableAfterSavings
            .add({'currency': c.code, 'minor_units': bal - saved});
      }
    }

    // Member spending in current cycle (per currency, no cross-currency mixing)
    final memberSpending = <Map<String, Object?>>[];
    for (final c in currencies) {
      final byMember = <String, ({int minor, int count})>{};
      var totalMinor = 0;
      for (final t in sharedTxs) {
        if (t.type != TxType.expense ||
            t.amount.currency != c ||
            t.when.isBefore(cycleStart) ||
            !t.when.isBefore(nextCycle)) {
          continue;
        }
        final prev = byMember[t.memberId] ?? (minor: 0, count: 0);
        byMember[t.memberId] =
            (minor: prev.minor + t.amount.minor, count: prev.count + 1);
        totalMinor += t.amount.minor;
      }
      final entries = byMember.entries.toList()
        ..sort((a, b) => b.value.minor.compareTo(a.value.minor));
      for (final entry in entries) {
        final name = state.member(entry.key)?.name ?? 'Family member';
        final pct =
            totalMinor > 0 ? ((entry.value.minor * 100) / totalMinor).round() : 0;
        memberSpending.add({
          'name': name,
          'is_you': entry.key == state.realUser.id,
          'currency': c.code,
          'spent_minor': entry.value.minor,
          'tx_count': entry.value.count,
          'share_percent': pct,
        });
      }
    }

    // Budgets (including splits + single-envelope allocations, matching Postgres 080)
    final cycleExpenses = sharedTxs
        .where((t) =>
            t.type == TxType.expense &&
            !t.when.isBefore(cycleStart) &&
            t.when.isBefore(nextCycle))
        .toList();
    final splitByTx = <String, List<TxAllocation>>{};
    for (final al in state.txAllocations) {
      (splitByTx[al.txId] ??= []).add(al);
    }

    final budgets = <Map<String, Object?>>[];
    for (final env in state.envelopes) {
      if (env.isArchived || env.isPersonal) continue;
      final limitMinor = state.effectiveLimit(env).minor;
      final envCurrency = env.limit.currency;
      var spentMinor = 0;
      var complete = true;
      for (final tx in cycleExpenses) {
        final splits = splitByTx[tx.id];
        if (splits != null && splits.isNotEmpty) {
          for (final sp in splits) {
            if (sp.envelopeId != env.id) continue;
            if (sp.amount.currency != envCurrency) {
              complete = false;
            } else {
              spentMinor += sp.amount.minor;
            }
          }
        } else if (tx.envelopeId == env.id) {
          if (tx.amount.currency != envCurrency) {
            complete = false;
          } else {
            spentMinor += tx.amount.minor;
          }
        }
      }
      budgets.add({
        'name': env.name,
        'currency': envCurrency.code,
        'complete': complete,
        'limit_minor': limitMinor,
        'spent_minor': complete ? spentMinor : null,
        'remaining_minor': complete ? (limitMinor - spentMinor) : null,
      });
    }
    budgets.sort((a, b) =>
        ((b['spent_minor'] as int?) ?? 0).compareTo((a['spent_minor'] as int?) ?? 0));

    final topCategories = <Map<String, Object?>>[];
    for (final c in currencies) {
      final matching = budgets
          .where((b) =>
              b['complete'] == true &&
              b['currency'] == c.code &&
              ((b['spent_minor'] as int?) ?? 0) > 0)
          .take(5);
      for (final b in matching) {
        topCategories.add({
          'name': b['name'],
          'currency': c.code,
          'spent_minor': b['spent_minor'],
        });
      }
    }

    // Upcoming commitments (overdue + next 45 days) + active recurring rules
    final horizon = today.add(const Duration(days: 45));
    final commitmentById = {
      for (final fc in state.financialCommitments)
        if (fc.status == CommitmentStatus.active) fc.id: fc,
    };
    final upcoming = <Map<String, Object?>>[];
    for (final occ in state.commitmentOccurrences) {
      if (occ.status == CommitmentOccurrenceStatus.paid ||
          occ.status == CommitmentOccurrenceStatus.skipped ||
          occ.status == CommitmentOccurrenceStatus.canceled) {
        continue;
      }
      if (occ.dueDate.isAfter(horizon)) continue;
      final parent = commitmentById[occ.commitmentId];
      if (parent == null) continue;
      final outstanding = state.commitmentOutstanding(occ);
      if (outstanding.minor <= 0) continue;
      upcoming.add({
        'name': parent.name,
        'due_date': occ.dueDate.toIso8601String(),
        'currency': outstanding.currency.code,
        'amount_minor': outstanding.minor,
        'overdue': occ.dueDate.isBefore(today),
      });
    }
    for (final rr in state.recurring) {
      if (!rr.active || rr.isArchived || rr.amount.minor <= 0) continue;
      final dueDay = DateTime(rr.nextDue.year, rr.nextDue.month, rr.nextDue.day);
      if (dueDay.isAfter(horizon)) continue;
      final duplicate = upcoming.any((u) {
        final uDate = DateTime.tryParse(u['due_date']?.toString() ?? '');
        return (u['name']?.toString() ?? '').trim().toLowerCase() ==
                rr.name.trim().toLowerCase() &&
            uDate != null &&
            uDate.year == dueDay.year &&
            uDate.month == dueDay.month &&
            uDate.day == dueDay.day;
      });
      if (!duplicate) {
        upcoming.add({
          'name': rr.name,
          'due_date': dueDay.toIso8601String(),
          'currency': rr.amount.currency.code,
          'amount_minor': rr.amount.minor,
          'overdue': dueDay.isBefore(today),
        });
      }
    }
    upcoming.sort((a, b) => (a['due_date']?.toString() ?? '')
        .compareTo(b['due_date']?.toString() ?? ''));

    final billsBeforeNext = <String, int>{};
    for (final bill in upcoming) {
      final d = DateTime.tryParse(bill['due_date']?.toString() ?? '');
      if (d != null && !d.isBefore(nextCycle)) continue;
      final code = bill['currency'].toString();
      billsBeforeNext[code] =
          (billsBeforeNext[code] ?? 0) + ((bill['amount_minor'] as int?) ?? 0);
    }

    // Savings goals
    final savingsGoals = <Map<String, Object?>>[];
    for (final g in state.goals) {
      if (!visibleGoalIds.contains(g.id)) continue;
      final gTxs = state.goalTxs.where((gt) => gt.goalId == g.id).toList();
      final complete = gTxs.every((gt) => gt.amount.currency == g.target.currency);
      final savedMinor = gTxs
          .where((gt) => gt.amount.currency == g.target.currency)
          .fold<int>(0, (s, gt) => s + gt.amount.minor);
      final remainingMinor =
          (g.target.minor - savedMinor).clamp(0, g.target.minor);
      int? weeksToDeadline;
      int? requiredWeekly;
      if (g.deadline != null && g.deadline!.isAfter(today)) {
        final days = g.deadline!.difference(today).inDays;
        weeksToDeadline = ((days + 6) ~/ 7).clamp(1, 10000);
        if (complete && remainingMinor > 0) {
          requiredWeekly = (remainingMinor / weeksToDeadline).ceil();
        }
      }
      savingsGoals.add({
        'name': g.name,
        'currency': g.target.currency.code,
        'complete': complete,
        'target_minor': g.target.minor,
        'saved_minor': complete ? savedMinor : null,
        'remaining_minor': complete ? remainingMinor : null,
        'required_weekly_minor': requiredWeekly,
        'weeks_to_deadline': weeksToDeadline,
        'deadline': g.deadline != null ? _isoDay(g.deadline!) : null,
      });
    }

    // Debts
    final debts = <Map<String, Object?>>[];
    for (final d in state.familyDebts) {
      if (d.status != 'active') continue;
      final dPayments =
          state.debtRepayments.where((p) => p.debtId == d.id).toList();
      final complete =
          dPayments.every((p) => p.amount.currency == d.principal.currency);
      final repaidMinor = dPayments
          .where((p) => p.amount.currency == d.principal.currency)
          .fold<int>(0, (s, p) => s + p.amount.minor);
      final remainingMinor =
          (d.principal.minor - repaidMinor).clamp(0, d.principal.minor);
      debts.add({
        'name': d.name,
        'direction': d.direction.name,
        'currency': d.principal.currency.code,
        'complete': complete,
        'original_minor': d.principal.minor,
        'repaid_minor': complete ? repaidMinor : null,
        'remaining_minor': complete ? remainingMinor : null,
        'due_date': d.dueDate != null ? _isoDay(d.dueDate!) : null,
      });
    }

    // Shopping summary
    final openItems = state.items
        .where((i) =>
            i.deletedAt == null && !i.checkedOut && i.state != ItemState.done)
        .toList();
    final shoppingByCur = <String, ({int count, int estMinor})>{};
    for (final item in openItems) {
      final code = item.est.currency.code;
      final prev = shoppingByCur[code] ?? (count: 0, estMinor: 0);
      shoppingByCur[code] = (
        count: prev.count + 1,
        estMinor: prev.estMinor + item.est.minor * (item.qty < 1 ? 1 : item.qty),
      );
    }
    final shoppingSummary = [
      for (final e in shoppingByCur.entries)
        {
          'currency': e.key,
          'open_items': e.value.count,
          'estimated_minor': e.value.estMinor,
        },
    ];

    // Purchase scenario if question mentions an explicit amount
    final purchaseScenario = _computePurchaseScenario(
      question: question,
      fallbackCurrency: state.primaryCurrency.code,
      hasMultipleCurrencies: state.secondaryCurrency != null,
      availableAfterSavings: availableAfterSavings,
      billsBeforeNext: billsBeforeNext,
    );

    final cycleStartIso = _isoDay(cycleStart);
    final nextCycleIso = _isoDay(nextCycle);
    final prevCycleIso = _isoDay(prevCycleStart);

    final facts = <String, Object?>{
      'as_of': wall.toUtc().toIso8601String(),
      'currency': state.primaryCurrency.code,
      'cycle_start': cycleStartIso,
      'next_cycle_start': nextCycleIso,
      'cycle_spending': cycleSpending,
      'cycle_income': cycleIncome,
      'previous_cycle_start': prevCycleIso,
      'previous_cycle_spending': prevSpending,
      'previous_cycle_income': prevIncome,
      'member_spending': memberSpending,
      'top_categories': topCategories,
      'account_balances_estimate': accountBalances,
      'available_after_recorded_savings': availableAfterSavings,
      'purchase_scenario': purchaseScenario,
      'budgets': budgets,
      'upcoming_commitments': upcoming,
      'savings_goals': savingsGoals,
      'debts': debts,
      'shopping_summary': shoppingSummary,
    };

    return _Snapshot(
      baseCurrency: state.primaryCurrency,
      activeCurrencyCodes: [for (final c in currencies) c.code],
      cycleStartIso: cycleStartIso,
      nextCycleIso: nextCycleIso,
      daysLeftInCycle: state.daysLeftInCycle,
      cycleSpending: cycleSpending,
      cycleIncome: cycleIncome,
      previousCycleSpending: prevSpending,
      availableAfterSavings: availableAfterSavings,
      billsBeforeNextCycleByCurrency: billsBeforeNext,
      memberSpending: memberSpending,
      budgets: budgets,
      topCategories: topCategories,
      upcomingCommitments: upcoming,
      savingsGoals: savingsGoals,
      debts: debts,
      shoppingSummary: shoppingSummary,
      openShoppingItems: openItems,
      purchaseScenario: purchaseScenario,
      facts: facts,
    );
  }

  static Map<String, Object?>? _computePurchaseScenario({
    required String question,
    required String fallbackCurrency,
    required bool hasMultipleCurrencies,
    required List<Map<String, Object?>> availableAfterSavings,
    required Map<String, int> billsBeforeNext,
  }) {
    if (!RegExp(r'\b(afford|buy|purchase|cost|price|spend)\b',
            caseSensitive: false)
        .hasMatch(question)) {
      return null;
    }
    final marked = RegExp(
      r'(?:US\$|USD|ZWG|ZIG|ZIG\$|\$|R)\s*(\d[\d,]*(?:\.\d{1,2})?)|(\d[\d,]*(?:\.\d{1,2})?)\s*(USD|ZWG|ZIG|ZIG\$|DOLLARS?)',
      caseSensitive: false,
    ).firstMatch(question);
    final bare = marked != null
        ? null
        : RegExp(
            r'\b(?:for|costs?|price|worth|at|spend)\s+(?:of\s+)?(\d[\d,]*(?:\.\d{1,2})?)\b',
            caseSensitive: false,
          ).firstMatch(question);
    final raw = marked?.group(1) ?? marked?.group(2) ?? bare?.group(1);
    if (raw == null) return null;
    final fullMatch = marked?.group(0) ?? '';
    final marker = fullMatch.replaceAll(raw, '').trim().toUpperCase();
    String? currency;
    if (marker == r'$' && (fallbackCurrency != 'USD' || hasMultipleCurrencies)) {
      currency = fallbackCurrency == 'USD' && !hasMultipleCurrencies ? 'USD' : null;
    } else if (marker.contains('ZWG') || marker.contains('ZIG')) {
      currency = 'ZWG';
    } else if (marker == 'USD' || marker.contains(r'US$') || marker.contains('DOLLAR')) {
      currency = 'USD';
    } else if (marker == 'R') {
      currency = 'ZAR';
    } else if (marker.isEmpty && hasMultipleCurrencies) {
      currency = null;
    } else {
      currency = fallbackCurrency;
    }

    final parsedMoney = Money.tryParse(raw, Currency.usd);
    if (parsedMoney == null || parsedMoney.minor <= 0) return null;
    final minor = parsedMoney.minor;

    if (currency == null) {
      return {'status': 'currency_required', 'purchase_minor': minor};
    }
    final spendableRow = availableAfterSavings
        .where((r) => r['currency'] == currency)
        .firstOrNull;
    if (spendableRow == null) {
      return {
        'currency': currency,
        'purchase_minor': minor,
        'status': 'insufficient_balance_data',
      };
    }
    final spendable = (spendableRow['minor_units'] as int?) ?? 0;
    final bills = billsBeforeNext[currency] ?? 0;
    final afterBills = spendable - bills;
    final afterPurchase = afterBills - minor;
    return {
      'currency': currency,
      'purchase_minor': minor,
      'spendable_before_bills_minor': spendable,
      'upcoming_bills_before_next_cycle_minor': bills,
      'estimated_after_bills_minor': afterBills,
      'estimated_after_purchase_minor': afterPurchase,
      'fits_recorded_cash_estimate': minor <= afterBills,
    };
  }
}
