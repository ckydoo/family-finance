import '../models/models.dart';
import '../money/money.dart';
import '../state/app_state.dart';

/// Ask Mhuri without the network.
///
/// The AI path needs a configured Supabase function and a reachable provider.
/// When either is missing - no secret deployed yet, offline, provider trouble -
/// Mhuri still knows the family's own records, so the four questions the app
/// itself suggests can be answered locally and deterministically.
///
/// This is deliberately a narrow, conservative engine:
///
///  * it only answers questions it can compute exactly from recorded data;
///  * it never estimates, never mixes currencies, and never invents a figure;
///  * it returns null when it cannot help, so the caller keeps the existing
///    "couldn't answer" path instead of showing a guess.
class LocalAnswer {
  const LocalAnswer({required this.text, this.facts = const {}});

  final String text;

  /// Same shape the server returns, so the existing facts card renders it.
  final Map<String, Object?> facts;
}

enum _Intent { affordability, bills, spending, savings, budgetLeft, unknown }

const _billWords = [
  'bill',
  'bills',
  'due',
  'upcoming',
  'coming up',
  'recurring',
  'owe',
  'rent',
  'school fees',
];

/// Answers [question] from the family's recorded data, or null when the
/// question is outside what can be computed safely offline.
LocalAnswer? answerFromRecords(AppState state, String question) {
  final q = question.toLowerCase().trim();
  if (q.isEmpty) return null;

  switch (_classify(q)) {
    case _Intent.affordability:
      return _affordability(state);
    case _Intent.bills:
      return _bills(state);
    case _Intent.spending:
      return _spending(state);
    case _Intent.savings:
      return _savings(state);
    case _Intent.budgetLeft:
      return _budgetLeft(state);
    case _Intent.unknown:
      return null;
  }
}

_Intent _classify(String q) {
  bool has(List<String> words) => words.any(q.contains);

  // "What bills are coming up?" must beat the generic affordability word
  // "afford", and savings wording beats "left".
  if (has(_billWords)) return _Intent.bills;
  if (has(['save', 'saving', 'savings', 'goal'])) return _Intent.savings;
  if (has([
    'afford',
    'can we buy',
    'can i buy',
    'extra',
    'spare',
    'left over for',
  ])) {
    return _Intent.affordability;
  }
  if (has([
    'spending the most',
    'spend the most',
    'biggest',
    'top categor',
    'where are we spending',
    'where is our money going',
  ])) {
    return _Intent.spending;
  }
  if (has(['left', 'remaining', 'balance', 'budget'])) {
    return _Intent.budgetLeft;
  }
  return _Intent.unknown;
}

String _money(Money value) => value.text;

/// "Free after commitments" - recorded cash minus what is still owed before
/// the next budget boundary, in one currency only.
LocalAnswer? _affordability(AppState state) {
  final currency = state.displayCurrency;
  final cash = state.availableToSpend(currency);
  final due = _outstandingBeforeNextCycle(state, currency);
  final free = cash.minor - due.minor;
  if (cash.minor == 0 && due.minor == 0) return null;

  final facts = <String, Object?>{
    'available_to_spend': _money(cash),
    'due_before_next_cycle': _money(due),
    'estimated_free': _money(Money(free < 0 ? 0 : free, currency)),
  };
  final buffer = StringBuffer()
    ..write('From your records: ${_money(cash)} is available to spend, ')
    ..write('and ${_money(due)} of recorded bills are still due before ')
    ..write('the next budget cycle.')
    ..write(free > 0
        ? ' That leaves about ${_money(Money(free, currency))} unspoken for.'
        : ' The recorded bills already use up what is recorded as available.');
  buffer.write(
      ' This is an estimate from recorded data only - unrecorded cash and '
      'future changes are not included.');
  return LocalAnswer(text: buffer.toString(), facts: facts);
}

LocalAnswer? _bills(AppState state) {
  final currency = state.displayCurrency;
  final rows = <String>[];
  var total = 0;

  final upcoming = [...state.upcomingCommitments()]
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  for (final occurrence in upcoming.take(5)) {
    final name = _commitmentName(state, occurrence.commitmentId);
    final amount = occurrence.amount.inCurrency(currency, state.rate);
    total += amount.minor;
    rows.add('$name - ${_money(amount)} due ${_shortDate(occurrence.dueDate)}');
  }

  final recurring = _recurringBeforeBoundary(state);
  for (final rule in recurring.take(5)) {
    final amount = rule.amount.inCurrency(currency, state.rate);
    total += amount.minor;
    rows.add('${rule.name} - ${_money(amount)} due ${_shortDate(rule.nextDue)}');
  }

  if (rows.isEmpty) {
    return LocalAnswer(
      text: 'No recorded bills are due right now. Regular payments and '
          'planned commitments will show here once they are recorded.',
      facts: {'due_before_next_cycle': _money(const Money(0, Currency.usd))},
    );
  }

  final text = StringBuffer()
    ..write('From your records, these are the next bills coming up:\n')
    ..write(rows.map((row) => '- $row').join('\n'))
    ..write('\n\nRecorded total: ${_money(Money(total, currency))}.');
  return LocalAnswer(
    text: text.toString(),
    facts: {'due_before_next_cycle': _money(Money(total, currency))},
  );
}

LocalAnswer? _spending(AppState state) {
  final currency = state.displayCurrency;
  final ranked = <(String, Money)>[];
  for (final envelope in state.envelopes) {
    if (envelope.isArchived) continue;
    final spent = state.spentOn(envelope).inCurrency(currency, state.rate);
    if (spent.minor > 0) ranked.add((envelope.name, spent));
  }
  if (ranked.isEmpty) return null;
  ranked.sort((a, b) => b.$2.minor.compareTo(a.$2.minor));
  final top = ranked.take(3).toList(growable: false);
  final monthly = state.spentTotal.inCurrency(currency, state.rate);

  final text = StringBuffer()
    ..write('From your records, most spending in this cycle is:\n')
    ..write(top
        .map((row) =>
            '- ${row.$1}: ${_money(row.$2)}')
        .join('\n'))
    ..write('\n\nRecorded spending this cycle: ${_money(monthly)}.');
  return LocalAnswer(
    text: text.toString(),
    facts: {
      'spent_this_cycle': _money(monthly),
      'top_category': top.first.$1,
    },
  );
}

LocalAnswer? _savings(AppState state) {
  final active = state.goals
      .where((goal) => goal.status == 'active' && !goal.isKidJar)
      .toList(growable: false);
  if (active.isEmpty) {
    return const LocalAnswer(
      text: 'There are no savings goals recorded yet. Add a goal in Savings '
          'and Mhuri can track what is left and how much to put aside.',
    );
  }

  final rows = <String>[];
  for (final goal in active.take(3)) {
    final saved = state.savedOn(goal);
    final remaining = goal.target.minor - saved.minor;
    if (remaining <= 0) {
      rows.add('${goal.name}: complete (${_money(saved)} saved)');
      continue;
    }
    final line = StringBuffer()
      ..write('${goal.name}: ${_money(saved)} of '
          '${_money(goal.target)} saved');
    if (goal.deadline != null) {
      final weeks = _weeksUntil(state, goal.deadline!);
      if (weeks > 0) {
        final perWeek = (remaining / weeks).ceil();
        line.write(
            ', about ${_money(Money(perWeek, goal.target.currency))} a week '
            'to finish on time');
      }
    }
    rows.add(line.toString());
  }

  final text = StringBuffer()
    ..write('From your records, your savings goals look like this:\n')
    ..write(rows.map((row) => '- $row').join('\n'))
    ..write('\n\nThese are planned amounts from recorded data, not a promise '
        'about future income.');
  return LocalAnswer(text: text.toString());
}

LocalAnswer? _budgetLeft(AppState state) {
  final currency = state.displayCurrency;
  final rows = <String>[];
  var total = 0;
  for (final envelope in state.envelopes) {
    if (envelope.isArchived || envelope.isPersonal) continue;
    if (envelope.limit.minor <= 0) continue;
    final left = state.remainingOn(envelope).inCurrency(currency, state.rate);
    if (left.minor == 0) continue;
    total += left.minor;
    rows.add('${envelope.name}: ${_money(left)}');
  }
  if (rows.isEmpty) return null;
  rows.sort();
  final text = StringBuffer()
    ..write('From your records, this is what is left in each budget:\n')
    ..write(rows.take(6).map((row) => '- $row').join('\n'))
    ..write('\n\nBudget room this cycle: ${_money(Money(total, currency))}. '
        'Budget room is not cash - check the family pool for money on hand.');
  return LocalAnswer(
    text: text.toString(),
    facts: {'budget_room': _money(Money(total, currency))},
  );
}

/// Active regular payments due before the next budget boundary. Uses the
/// state clock (not the wall clock) so answers are reproducible in tests.
List<RecurringRule> _recurringBeforeBoundary(AppState state) {
  final boundary = state.nextCycleStart;
  final rows = state.recurring
      .where((rule) =>
          rule.active && !rule.isArchived && rule.nextDue.isBefore(boundary))
      .toList(growable: false)
    ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
  return rows;
}

Money _outstandingBeforeNextCycle(AppState state, Currency currency) {
  final boundary = state.nextCycleStart;
  var total = 0;
  for (final occurrence in state.upcomingCommitments()) {
    if (!occurrence.dueDate.isBefore(boundary)) continue;
    total += occurrence.amount.inCurrency(currency, state.rate).minor;
  }
  for (final rule in _recurringBeforeBoundary(state)) {
    total += rule.amount.inCurrency(currency, state.rate).minor;
  }
  return Money(total, currency);
}

String _commitmentName(AppState state, String commitmentId) {
  for (final commitment in state.financialCommitments) {
    if (commitment.id == commitmentId) return commitment.name;
  }
  return 'Commitment';
}

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}';

int _weeksUntil(AppState state, DateTime deadline) {
  final days = deadline.difference(state.now).inDays;
  if (days <= 0) return 0;
  return (days / 7).ceil();
}
