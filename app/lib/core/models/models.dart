import '../money/money.dart';

// ── Enums ───────────────────────────────────────────────────────────────────

enum Role { owner, adult, teen, kid, viewer }

enum TxType { expense, income }

enum Method { cash, mobileMoney, bankCard, bankTransfer, agent, other }

enum Rollover { reset, roll, accumulate }

enum ItemState { tobuy, incart, done }

enum ChoreState { todo, waiting, confirmed }

enum RequestState { pending, approved, declined }

extension RoleX on Role {
  String get label => switch (this) {
        Role.owner => 'Owner',
        Role.adult => 'Adult',
        Role.teen => 'Teen',
        Role.kid => 'Kid',
        Role.viewer => 'Elder · Viewer',
      };
}

extension MethodX on Method {
  String get label => switch (this) {
        Method.cash => 'Cash',
        Method.mobileMoney => 'Mobile money',
        Method.bankCard => 'Bank card',
        Method.bankTransfer => 'Bank transfer',
        Method.agent => 'Agent / cash point',
        Method.other => 'Other',
      };
}

extension RolloverX on Rollover {
  String get label => switch (this) {
        Rollover.reset => 'Resets monthly',
        Rollover.roll => 'Rolls over',
        Rollover.accumulate => 'Term savings',
      };
}

enum Frequency { weekly, monthly, term }

extension FrequencyX on Frequency {
  String get label => switch (this) {
        Frequency.weekly => 'Weekly',
        Frequency.monthly => 'Monthly',
        Frequency.term => 'Per term (~3 months)',
      };

  DateTime advanceFrom(DateTime d) => switch (this) {
        Frequency.weekly => DateTime(d.year, d.month, d.day + 7),
        Frequency.monthly => DateTime(d.year, d.month + 1, d.day),
        Frequency.term => DateTime(d.year, d.month + 3, d.day),
      };
}

/// C7 — a repeating expense (school fees, rent, airtime) with a review step:
/// due rules surface on Home and a parent posts them (or skips) — nothing is
/// charged silently. Device-local in M4; server sync joins later.
class RecurringRule {
  final String id;
  final String name;
  final String emoji;
  final Money amount;
  final String? envelopeId;
  final String memberId;
  final Method method;
  final Frequency frequency;
  DateTime nextDue;
  bool active;

  RecurringRule({
    required this.id,
    required this.name,
    required this.emoji,
    required this.amount,
    required this.memberId,
    required this.method,
    required this.frequency,
    required this.nextDue,
    this.envelopeId,
    this.active = true,
  });

  bool isDueWithin(Duration window) =>
      active && !nextDue.isAfter(DateTime.now().add(window));
}

extension ItemStateX on ItemState {
  String get label => switch (this) {
        ItemState.tobuy => 'To buy',
        ItemState.incart => 'In cart',
        ItemState.done => 'Done',
      };

  ItemState get next => switch (this) {
        ItemState.tobuy => ItemState.incart,
        ItemState.incart => ItemState.done,
        ItemState.done => ItemState.tobuy,
      };
}

// ── Entities ────────────────────────────────────────────────────────────────

class FamilySpace {
  final String name;
  final int monthStartDay;

  const FamilySpace({required this.name, this.monthStartDay = 1});
}

class Member {
  final String id;
  final String name;
  final String emoji;
  final Role role;

  const Member({
    required this.id,
    required this.name,
    required this.emoji,
    required this.role,
  });
}

/// Cash / mobile-money / bank balances. Money is *tagged*, never held.
class Account {
  final String id;
  final String name;
  final String emoji;
  final Money balance;

  const Account({
    required this.id,
    required this.name,
    required this.emoji,
    required this.balance,
  });
}

/// Envelope = a category with a monthly limit (spec Module D).
/// [limit] is mutable to support "move money between envelopes".
class Envelope {
  final String id;
  final String name;
  final String emoji;
  Money limit;
  final Rollover rollover;
  final bool isPersonal;

  Envelope({
    required this.id,
    required this.name,
    required this.emoji,
    required this.limit,
    this.rollover = Rollover.reset,
    this.isPersonal = false,
  });
}

class Tx {
  final String id;
  final String? envelopeId;
  final String memberId;
  final TxType type;
  final Money amount;
  final Method method;
  final String note;
  final DateTime when;

  const Tx({
    required this.id,
    required this.memberId,
    required this.type,
    required this.amount,
    required this.method,
    required this.note,
    required this.when,
    this.envelopeId,
  });
}

class Goal {
  final String id;
  final String name;
  final String emoji;
  final Money target;
  final String? autoSave;
  final bool isKidJar;
  final String? ownerMemberId;

  const Goal({
    required this.id,
    required this.name,
    required this.emoji,
    required this.target,
    this.autoSave,
    this.isKidJar = false,
    this.ownerMemberId,
  });
}

class GoalTx {
  final String goalId;
  final String byMemberId;
  final Money amount;
  final DateTime at;

  const GoalTx({
    required this.goalId,
    required this.byMemberId,
    required this.amount,
    required this.at,
  });
}

class ListItem {
  final String id;
  final String name;
  final int qty;
  final Money est; // estimated unit price
  ItemState state;
  final String addedById;

  ListItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.est,
    required this.addedById,
    this.state = ItemState.tobuy,
  });
}

class Chore {
  final String id;
  final String name;
  final int stars;
  ChoreState state;

  Chore({
    required this.id,
    required this.name,
    required this.stars,
    this.state = ChoreState.todo,
  });
}

class KidRequest {
  final String id;
  final String kidId;
  final Money amount;
  final String reason;
  RequestState state;

  KidRequest({
    required this.id,
    required this.kidId,
    required this.amount,
    required this.reason,
    this.state = RequestState.pending,
  });
}

/// Teen expense proposal (spec Module H2) — enters the parents' pending queue.
class Proposal {
  final String id;
  final String teenId;
  final Money amount;
  final String envelopeId;
  final String reason;
  RequestState state;

  Proposal({
    required this.id,
    required this.teenId,
    required this.amount,
    required this.envelopeId,
    required this.reason,
    this.state = RequestState.pending,
  });
}

/// Teen logged earning (spec Module H3).
class Earning {
  final String id;
  final String memberId;
  final String note;
  final Money amount;
  final DateTime when;

  const Earning({
    required this.id,
    required this.memberId,
    required this.note,
    required this.amount,
    required this.when,
  });
}

/// Savings circle (ROSCA — rotation savings). Records only — never holds
/// the money (spec §4 E4).
class SavingsCircle {
  final String name;
  final Money contribution;
  final int totalRounds;
  int currentRound; // 1-based; rounds before this are collected
  final List<String> order;

  SavingsCircle({
    required this.name,
    required this.contribution,
    required this.totalRounds,
    required this.currentRound,
    required this.order,
  });

  String get nextCollector {
    if (order.isEmpty) return '';
    final index =
        ((currentRound - 1) % order.length + order.length) % order.length;
    return order[index];
  }

  Money get potSoFar =>
      Money(contribution.minor * (currentRound - 1), contribution.currency);

  double get progress {
    if (totalRounds <= 0) return 0;
    return (currentRound / totalRounds).clamp(0.0, 1.0);
  }
}
