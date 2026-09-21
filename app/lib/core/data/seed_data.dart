import '../models/models.dart';
import '../money/money.dart';

Money _u(num v) => Money.fromMajor(v, Currency.usd);
Money _z(num v) => Money.fromMajor(v, Currency.zwg);

/// Bundle of everything the demo app starts with. Dates are relative to
/// "now" so the demo always looks fresh.
class SeedBundle {
  final FamilySpace space;
  final List<Member> members;
  final List<Account> accounts;
  final List<Envelope> envelopes;
  final List<Tx> txs;
  final List<Goal> goals;
  final List<GoalTx> goalTxs;
  final List<ListItem> items;
  final List<Chore> chores;
  final List<KidRequest> requests;
  final List<Proposal> proposals;
  final List<RecurringRule> recurring;
  final List<Earning> earnings;
  final SavingsCircle circle;

  SeedBundle({
    required this.space,
    required this.members,
    required this.accounts,
    required this.envelopes,
    required this.txs,
    required this.goals,
    required this.goalTxs,
    required this.items,
    required this.chores,
    required this.requests,
    required this.proposals,
    required this.recurring,
    required this.earnings,
    required this.circle,
  });
}

SeedBundle seedData() {
  final now = DateTime.now();
  DateTime d(int daysAgo, [int h = 10, int m = 0]) =>
      DateTime(now.year, now.month, now.day - daysAgo, h, m);

  const members = [
    Member(id: 'm_david', name: 'David', emoji: 'man', role: Role.owner),
    Member(id: 'm_maya', name: 'Maya', emoji: 'woman', role: Role.adult),
    Member(id: 'm_leo', name: 'Leo', emoji: 'boy', role: Role.kid),
    Member(id: 'm_mia', name: 'Mia', emoji: 'baby', role: Role.kid),
    Member(id: 'm_zoe', name: 'Zoe', emoji: 'student', role: Role.teen),
    Member(id: 'm_nana', name: 'Nana', emoji: 'grandma', role: Role.viewer),
  ];

  // Family Pool ≈ US$ 1,240.50 at the demo rate (see mockup A).
  final accounts = [
    Account(id: 'a_bank', name: 'Main bank', emoji: 'bank', balance: _u(920.50)),
    Account(id: 'a_cash', name: 'Cash at home', emoji: 'cash', balance: _u(180)),
    Account(id: 'a_wallet', name: 'Mobile wallet', emoji: 'wallet', balance: _z(2140)),
  ];

  final envelopes = [
    Envelope(id: 'e1', name: 'Groceries', emoji: 'cart', limit: _u(450)),
    Envelope(
      id: 'e2',
      name: 'School fees',
      emoji: 'school',
      limit: _u(300),
      rollover: Rollover.accumulate,
    ),
    Envelope(id: 'e3', name: 'Transport', emoji: 'fuel', limit: _u(200)),
    Envelope(id: 'e4', name: 'Electricity', emoji: 'power', limit: _u(60)),
    Envelope(id: 'e5', name: 'Airtime & data', emoji: 'airtime', limit: _z(600)),
    Envelope(id: 'e6', name: 'Kids & pocket money', emoji: 'stars', limit: _u(80)),
    Envelope(
      id: 'e7',
      name: 'Emergency buffer',
      emoji: 'lifebuoy',
      limit: _u(100),
      rollover: Rollover.roll,
    ),
    Envelope(
      id: 'e8',
      name: 'Tithing & giving',
      emoji: 'giving',
      limit: _u(50),
      isPersonal: true,
    ),
  ];

  final txs = <Tx>[
    // Income (spec Module B)
    Tx(
      id: 't101',
      memberId: 'm_david',
      type: TxType.income,
      amount: _u(650),
      method: Method.bankTransfer,
      note: 'Salary',
      when: DateTime(now.year, now.month, 1, 8, 5),
    ),
    Tx(
      id: 't102',
      memberId: 'm_maya',
      type: TxType.income,
      amount: _u(412.50),
      method: Method.cash,
      note: 'Corner shop — week sales',
      when: d(6, 17, 30),
    ),
    Tx(
      id: 't103',
      memberId: 'm_maya',
      type: TxType.income,
      amount: _u(180),
      method: Method.bankTransfer,
      note: 'Remittance — brother (UK)',
      when: d(9, 11, 0),
    ),
    Tx(
      id: 't104',
      memberId: 'm_maya',
      type: TxType.income,
      amount: _z(3200),
      method: Method.mobileMoney,
      note: 'Corner shop — mobile sales',
      when: d(3, 18, 45),
    ),
    // Groceries ≈ US$ 306 of US$ 450 (68%)
    Tx(
      id: 't110',
      envelopeId: 'e1',
      memberId: 'm_maya',
      type: TxType.expense,
      amount: _u(112),
      method: Method.bankCard,
      note: 'FreshMart',
      when: d(1, 10, 15),
    ),
    Tx(
      id: 't111',
      envelopeId: 'e1',
      memberId: 'm_david',
      type: TxType.expense,
      amount: _u(96),
      method: Method.bankCard,
      note: 'City Supermarket',
      when: d(4, 16, 20),
    ),
    Tx(
      id: 't112',
      envelopeId: 'e1',
      memberId: 'm_maya',
      type: TxType.expense,
      amount: _u(53),
      method: Method.cash,
      note: 'Saturday market — vegetables',
      when: d(6, 8, 40),
    ),
    Tx(
      id: 't113',
      envelopeId: 'e1',
      memberId: 'm_david',
      type: TxType.expense,
      amount: _u(45),
      method: Method.mobileMoney,
      note: 'Spar top-up',
      when: d(9, 17, 10),
    ),
    // Transport ≈ US$ 164 of US$ 200 (82% — watch)
    Tx(
      id: 't120',
      envelopeId: 'e3',
      memberId: 'm_david',
      type: TxType.expense,
      amount: _u(100),
      method: Method.bankCard,
      note: 'Fuel — full tank',
      when: d(2, 7, 30),
    ),
    Tx(
      id: 't121',
      envelopeId: 'e3',
      memberId: 'm_maya',
      type: TxType.expense,
      amount: _u(64),
      method: Method.cash,
      note: 'Fuel + bus fares',
      when: d(7, 7, 45),
    ),
    // Electricity — US$ 60 of US$ 60 (100% — reached)
    Tx(
      id: 't130',
      envelopeId: 'e4',
      memberId: 'm_david',
      type: TxType.expense,
      amount: _u(60),
      method: Method.mobileMoney,
      note: 'Prepaid electricity tokens',
      when: d(5, 19, 0),
    ),
    // School fees ≈ US$ 135 of US$ 300 (45%)
    Tx(
      id: 't140',
      envelopeId: 'e2',
      memberId: 'm_maya',
      type: TxType.expense,
      amount: _u(135),
      method: Method.bankTransfer,
      note: 'School fees + sport kit',
      when: d(8, 9, 30),
    ),
    // Airtime ≈ ZiG 565 of ZiG 600
    Tx(
      id: 't150',
      envelopeId: 'e5',
      memberId: 'm_david',
      type: TxType.expense,
      amount: _u(5),
      method: Method.mobileMoney,
      note: 'Mobile-money airtime',
      when: d(1, 9, 0),
    ),
    Tx(
      id: 't151',
      envelopeId: 'e5',
      memberId: 'm_maya',
      type: TxType.expense,
      amount: _u(17),
      method: Method.mobileMoney,
      note: 'Data bundle',
      when: d(4, 20, 15),
    ),
    // Kids & pocket money
    Tx(
      id: 't160',
      envelopeId: 'e6',
      memberId: 'm_david',
      type: TxType.expense,
      amount: _u(25),
      method: Method.cash,
      note: 'Pocket money — Leo',
      when: d(2, 15, 0),
    ),
    // Personal (private pocket — spec §3.2)
    Tx(
      id: 't170',
      envelopeId: 'e8',
      memberId: 'm_maya',
      type: TxType.expense,
      amount: _u(25),
      method: Method.cash,
      note: 'Church offering',
      when: d(5, 11, 0),
    ),
  ];

  final goals = [
    Goal(
      id: 'g_fees',
      name: 'School Fees — Term 2',
      emoji: 'school',
      target: _u(900),
      autoSave: 'Auto-save \$25 weekly · Fridays',
    ),
    Goal(
      id: 'g_emerg',
      name: 'Emergency Fund',
      emoji: 'lifebuoy',
      target: _u(1000),
      autoSave: 'Auto-save \$50 monthly · payday',
    ),
    Goal(
      id: 'g_hol',
      name: 'Family Holiday — by the sea',
      emoji: 'beach',
      target: _u(800),
    ),
    Goal(
      id: 'g_jar',
      name: "Leo's Jar — New Bike",
      emoji: 'bike',
      target: _u(120),
      isKidJar: true,
    ),
    Goal(
      id: 'g_teenjar',
      name: 'Zoe — Laptop Fund',
      emoji: 'laptop',
      target: _u(400),
      autoSave: 'Auto-save \$10 weekly · Mondays',
      ownerMemberId: 'm_zoe',
    ),
  ];

  // Goal contributions with real dates.
  final goalTxs = <GoalTx>[
    GoalTx(goalId: 'g_fees', byMemberId: 'm_david', amount: _u(200), at: d(20)),
      GoalTx(goalId: 'g_fees', byMemberId: 'm_maya', amount: _u(200), at: d(13)),
      GoalTx(goalId: 'g_fees', byMemberId: 'm_david', amount: _u(200), at: d(6)),
      GoalTx(goalId: 'g_emerg', byMemberId: 'm_maya', amount: _u(250), at: d(18)),
      GoalTx(goalId: 'g_emerg', byMemberId: 'm_david', amount: _u(250), at: d(10)),
      GoalTx(goalId: 'g_emerg', byMemberId: 'm_maya', amount: _u(220), at: d(3)),
      GoalTx(goalId: 'g_hol', byMemberId: 'm_david', amount: _u(90), at: d(15)),
      GoalTx(goalId: 'g_hol', byMemberId: 'm_maya', amount: _u(90), at: d(4)),
      GoalTx(goalId: 'g_jar', byMemberId: 'm_david', amount: _u(10), at: d(21)),
      GoalTx(goalId: 'g_jar', byMemberId: 'm_maya', amount: _u(8), at: d(12)),
      GoalTx(goalId: 'g_jar', byMemberId: 'm_maya', amount: _u(5), at: d(4)),
      GoalTx(goalId: 'g_teenjar', byMemberId: 'm_zoe', amount: _u(60), at: d(14)),
      GoalTx(goalId: 'g_teenjar', byMemberId: 'm_zoe', amount: _u(40), at: d(5)),
    ];

  final items = <ListItem>[
    ListItem(
      id: 'i1',
      name: 'Rice 10kg',
      qty: 2,
      est: _u(9.50),
      addedById: 'm_maya',
    ),
    ListItem(
      id: 'i2',
      name: 'Cooking oil 2L',
      qty: 1,
      est: _u(6.50),
      addedById: 'm_maya',
    ),
    ListItem(
      id: 'i3',
      name: 'Sugar 10kg',
      qty: 1,
      est: _u(9.20),
      addedById: 'm_david',
    ),
    ListItem(
      id: 'i4',
      name: 'Washing powder',
      qty: 1,
      est: _u(4.80),
      addedById: 'm_maya',
    ),
    ListItem(
      id: 'i5',
      name: 'Bread',
      qty: 4,
      est: _u(0.90),
      addedById: 'm_david',
      state: ItemState.done,
    ),
  ];

  final chores = <Chore>[
    Chore(id: 'c1', name: 'Feed the dog', stars: 2, state: ChoreState.confirmed),
    Chore(id: 'c2', name: 'Wash dishes', stars: 3),
    Chore(id: 'c3', name: 'Make my bed', stars: 1),
    Chore(id: 'c4', name: 'Pack school bag', stars: 2),
  ];

  final requests = <KidRequest>[
    KidRequest(
      id: 'r1',
      kidId: 'm_leo',
      amount: _u(10),
      reason: 'School trip — Natural History Museum',
    ),
  ];

  // Teen Zone seed (spec Module H).
  final proposals = <Proposal>[
    Proposal(
      id: 'p1',
      teenId: 'm_zoe',
      amount: _u(15),
      envelopeId: 'e6',
      reason: 'Movie night with study group — Friday',
    ),
  ];

  final earnings = <Earning>[
    Earning(id: 'e101', memberId: 'm_zoe', note: 'Car wash — Mr B', amount: _u(8), when: d(2)),
    Earning(id: 'e102', memberId: 'm_zoe', note: 'Helped at tuckshop', amount: _u(10), when: d(5)),
    Earning(id: 'e103', memberId: 'm_zoe', note: 'Dog walking', amount: _u(5), when: d(7)),
    Earning(id: 'e104', memberId: 'm_zoe', note: 'Car wash', amount: _u(8), when: d(12)),
    Earning(id: 'e105', memberId: 'm_zoe', note: 'Exam tutoring — cousin', amount: _u(12), when: d(16)),
  ];

  // Recurring expenses (C7) — one due within 2 days so the Home review
  // card is visible in the demo.
  final recurring = <RecurringRule>[
    RecurringRule(
      id: 'rc1',
      name: 'School fees & sport',
      emoji: 'school',
      amount: _u(135),
      envelopeId: 'e2',
      memberId: 'm_maya',
      method: Method.bankTransfer,
      frequency: Frequency.monthly,
      nextDue: d(-2, 9, 0),
    ),
    RecurringRule(
      id: 'rc2',
      name: 'Home airtime bundle',
      emoji: 'airtime',
      amount: _u(17),
      envelopeId: 'e5',
      memberId: 'm_david',
      method: Method.mobileMoney,
      frequency: Frequency.weekly,
      nextDue: d(-6, 8, 30),
    ),
    RecurringRule(
      id: 'rc3',
      name: 'Cottage rent',
      emoji: 'home',
      amount: _u(80),
      envelopeId: null,
      memberId: 'm_david',
      method: Method.bankTransfer,
      frequency: Frequency.monthly,
      nextDue: d(-20, 10, 0),
    ),
  ];

  final circle = SavingsCircle(
    name: 'Family Circle',
    contribution: _u(50),
    totalRounds: 8,
    currentRound: 4,
    order: const ['Aunt Kim', 'Maya', 'Uncle Raj', 'David', 'Mrs. Lee'],
  );

  return SeedBundle(
    space: const FamilySpace(name: 'The Taylor Family'),
    members: members,
    accounts: accounts,
    envelopes: envelopes,
    txs: txs,
    goals: goals,
    goalTxs: goalTxs,
    items: items,
    chores: chores,
    requests: requests,
    proposals: proposals,
    recurring: recurring,
    earnings: earnings,
    circle: circle,
  );
}
