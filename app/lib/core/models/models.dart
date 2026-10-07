import '../money/money.dart';

// ── Enums ───────────────────────────────────────────────────────────────────

enum Role { owner, adult, teen, kid, viewer }

enum TxType { expense, income }

enum Method { cash, mobileMoney, bankCard, bankTransfer, agent, other }

enum Rollover { reset, roll, accumulate }

enum ItemState { tobuy, incart, done }

enum ChoreState { todo, waiting, confirmed }

enum ChatMessageStatus { sent, delivered, read }

enum FamilyTaskStatus { open, inProgress, done }

enum ChatReferenceType { task, shoppingList, expense, goal, contribution }

enum RequestState { pending, approved, declined }

enum OverspendPolicy { warn, block }

enum IncomePlanMode { knownMonthly, asEarned }

enum DebtDirection { iOwe, owedToMe, familyLoan }

enum SyncHealthState { saved, syncing, synced, needsAttention }

extension OverspendPolicyX on OverspendPolicy {
  String get label => switch (this) {
        OverspendPolicy.warn => 'Warn and require confirmation',
        OverspendPolicy.block => 'Block overspending strictly',
      };
}

extension RoleX on Role {
  String get label => switch (this) {
        Role.owner => 'Family Admin',
        Role.adult => 'Adult Member',
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

/// C7 - a repeating expense (school fees, rent, airtime) with a review step:
/// due rules surface on Home and a parent posts them (or skips) - nothing is
/// charged silently. Device-local in M4; server sync joins later.
class RecurringRule {
  final String id;
  String name;
  String emoji;
  Money amount;
  String? envelopeId;
  String memberId;
  Method method;
  Frequency frequency;
  DateTime nextDue;
  bool active;
  bool isArchived;

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
    this.isArchived = false,
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
  final String? serverRole;

  /// Public URL of the member's profile picture (null → emoji fallback).
  final String? avatarUrl;

  const Member({
    required this.id,
    required this.name,
    required this.emoji,
    required this.role,
    this.serverRole,
    this.avatarUrl,
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
  String name;
  String emoji;
  Money limit;
  Rollover rollover;
  final bool isPersonal;
  bool isArchived;

  Envelope({
    required this.id,
    required this.name,
    required this.emoji,
    required this.limit,
    this.rollover = Rollover.reset,
    this.isPersonal = false,
    this.isArchived = false,
  });
}

/// A versioned snapshot of the family's plan for one budget cycle.
/// Envelope limits remain the fast path used by the spending UI; this record
/// preserves what was agreed for each month and makes close/copy explicit.
class BudgetCyclePlan {
  final String id;
  final DateTime cycleStart;
  IncomePlanMode incomeMode;
  Money? expectedIncome;
  Map<String, int> allocations;
  bool isClosed;
  DateTime? closedAt;
  DateTime? copiedFrom;

  BudgetCyclePlan({
    required this.id,
    required this.cycleStart,
    required this.incomeMode,
    required this.allocations,
    this.expectedIncome,
    this.isClosed = false,
    this.closedAt,
    this.copiedFrom,
  });
}

/// Immutable family audit event. Server events are authoritative; local
/// derived events keep the feed useful while a device is offline.
class FamilyActivity {
  final String id;
  final String actorId;
  final String action;
  final String entity;
  final String? entityId;
  final Map<String, Object?> detail;
  final DateTime at;

  const FamilyActivity({
    required this.id,
    required this.actorId,
    required this.action,
    required this.entity,
    required this.at,
    this.entityId,
    this.detail = const {},
  });
}

class ContributionCampaign {
  final String id;
  String name;
  Money target;
  DateTime deadline;
  final String createdById;
  String status;

  ContributionCampaign({
    required this.id,
    required this.name,
    required this.target,
    required this.deadline,
    required this.createdById,
    this.status = 'active',
  });
}

class ContributionPledge {
  final String id;
  final String campaignId;
  final String memberId;
  Money amount;
  final DateTime createdAt;

  ContributionPledge({
    required this.id,
    required this.campaignId,
    required this.memberId,
    required this.amount,
    required this.createdAt,
  });
}

class ContributionPayment {
  final String id;
  final String campaignId;
  final String memberId;
  final Money amount;
  final DateTime paidAt;

  const ContributionPayment({
    required this.id,
    required this.campaignId,
    required this.memberId,
    required this.amount,
    required this.paidAt,
  });
}

class FamilyDebt {
  final String id;
  String name;
  DebtDirection direction;
  Money principal;
  String? counterpartyMemberId;
  DateTime? dueDate;
  String status;
  final String createdById;

  FamilyDebt({
    required this.id,
    required this.name,
    required this.direction,
    required this.principal,
    required this.createdById,
    this.counterpartyMemberId,
    this.dueDate,
    this.status = 'active',
  });
}

class DebtRepayment {
  final String id;
  final String debtId;
  final String memberId;
  final Money amount;
  final DateTime paidAt;

  const DebtRepayment({
    required this.id,
    required this.debtId,
    required this.memberId,
    required this.amount,
    required this.paidAt,
  });
}

class FamilyChatMessage {
  final String id;
  final String familyId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isSystem;
  final String? senderName;
  final String? senderAvatar;
  final ChatMessageStatus status;
  final ChatReferenceType? referenceType;
  final String? referenceId;
  final String? referenceTitle;
  final String? referenceMeta;
  final bool deleted;

  const FamilyChatMessage({
    required this.id,
    required this.familyId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isSystem = false,
    this.senderName,
    this.senderAvatar,
    this.status = ChatMessageStatus.sent,
    this.referenceType,
    this.referenceId,
    this.referenceTitle,
    this.referenceMeta,
    this.deleted = false,
  });
}

class FamilyTask {
  final String id;
  final String title;
  final String? note;
  final String? assigneeMemberId;
  final String? createdByMemberId;
  final DateTime createdAt;
  final DateTime? dueDate;
  FamilyTaskStatus status;
  int points;
  bool isArchived;

  FamilyTask({
    required this.id,
    required this.title,
    this.note,
    this.assigneeMemberId,
    this.createdByMemberId,
    required this.createdAt,
    this.dueDate,
    this.status = FamilyTaskStatus.open,
    this.points = 1,
    this.isArchived = false,
  });

  FamilyTask copyWith({
    String? id,
    String? title,
    String? note,
    String? assigneeMemberId,
    String? createdByMemberId,
    DateTime? createdAt,
    DateTime? dueDate,
    FamilyTaskStatus? status,
    int? points,
    bool? isArchived,
  }) => FamilyTask(
        id: id ?? this.id,
        title: title ?? this.title,
        note: note ?? this.note,
        assigneeMemberId: assigneeMemberId ?? this.assigneeMemberId,
        createdByMemberId: createdByMemberId ?? this.createdByMemberId,
        createdAt: createdAt ?? this.createdAt,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        points: points ?? this.points,
        isArchived: isArchived ?? this.isArchived,
      );

  bool get isDone => status == FamilyTaskStatus.done;
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
  final DateTime? deletedAt;
  final String? receiptUri;
  final String? recurringRuleId;

  const Tx({
    required this.id,
    required this.memberId,
    required this.type,
    required this.amount,
    required this.method,
    required this.note,
    required this.when,
    this.envelopeId,
    this.deletedAt,
    this.receiptUri,
    this.recurringRuleId,
  });
}

class TxAllocation {
  final String id;
  final String txId;
  final String envelopeId;
  final Money amount;

  const TxAllocation(
      {required this.id,
      required this.txId,
      required this.envelopeId,
      required this.amount});
}

class Goal {
  final String id;
  final String name;
  final String emoji;
  final Money target;
  final String? autoSave;
  final bool isKidJar;
  final String? ownerMemberId;
  final String status;

  const Goal({
    required this.id,
    required this.name,
    required this.emoji,
    required this.target,
    this.autoSave,
    this.isKidJar = false,
    this.ownerMemberId,
    this.status = 'active',
  });
}

class GoalTx {
  final String? id;
  final String goalId;
  final String byMemberId;
  final Money amount;
  final DateTime at;

  const GoalTx({
    this.id,
    required this.goalId,
    required this.byMemberId,
    required this.amount,
    required this.at,
  });
}

class ListItem {
  final String id;
  String name;
  int qty;
  Money est; // estimated unit price
  ItemState state;
  bool checkedOut;
  final String addedById;
  String? assignedToId;
  Money? actual; // actual unit price once bought
  String? purchasedById;

  /// Tombstone: when set, the item is deleted everywhere (sync carries the
  /// flag; devices remove their local copy on pull).
  DateTime? deletedAt;

  ListItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.est,
    required this.addedById,
    this.state = ItemState.tobuy,
    this.checkedOut = false,
    this.assignedToId,
    this.actual,
    this.purchasedById,
    this.deletedAt,
  });
}

/// The shopping-list header (server `shopping_list`). Devices only need to
/// know which list exists - the id stamps every item push (list_id) and the
/// name feeds the Lists screen title.
class ShoppingListHeader {
  final String id;
  final String name;
  final String status; // 'active' | 'done'
  final DateTime? deletedAt;

  const ShoppingListHeader({
    required this.id,
    required this.name,
    this.status = 'active',
    this.deletedAt,
  });

  bool get isLive => deletedAt == null && status == 'active';
}

/// A pending/accepted family invite (server `family_invite`, migration 010).
/// Owner-managed: role-bound, expiring, revocable, single-use.
class InviteInfo {
  final String id;
  final String code;
  final String role; // adult | co_parent | teen | kid | viewer
  final String? email; // optional bind
  final DateTime? expiresAt;
  final String? acceptedBy;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;

  const InviteInfo({
    required this.id,
    required this.code,
    required this.role,
    this.email,
    this.expiresAt,
    this.acceptedBy,
    this.acceptedAt,
    this.revokedAt,
  });

  bool get isOpen =>
      revokedAt == null &&
      acceptedAt == null &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  /// Deep link the QR encodes and the share sheet hands to WhatsApp/SMS.
  String get link => 'mhuri://join?c=$code';
}

class Chore {
  final String id;
  String name;
  int stars;
  ChoreState state;
  String? assigneeMemberId;
  bool isArchived;

  Chore({
    required this.id,
    required this.name,
    required this.stars,
    this.state = ChoreState.todo,
    this.assigneeMemberId,
    this.isArchived = false,
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

/// Teen expense proposal (spec Module H2) - enters the parents' pending queue.
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

/// Savings circle (ROSCA - rotation savings). Records only - never holds
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

  /// Rotation wraps: a circle can run more rounds than members (cycle 2
  /// starts at the top of [order]) - and an empty order can never crash.
  String get nextCollector =>
      order.isEmpty ? '' : order[(currentRound - 1) % order.length];

  Money get potSoFar =>
      Money(contribution.minor * (currentRound - 1), contribution.currency);

  double get progress => currentRound / totalRounds;
}
