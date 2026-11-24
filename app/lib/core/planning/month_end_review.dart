import '../money/money.dart';

/// What should happen to money that is still unspent when a budget month
/// closes.
///
/// Mhuri never moves a family's money silently. The mode only decides whether
/// the month-end review *asks*, sweeps, or stays quiet:
///
///  * [ask]    - show the review once per closed cycle and let the family choose.
///  * [always] - automatically move leftovers into the chosen savings goal.
///  * [never]  - say nothing; leftovers simply stay in the pool.
enum MonthEndSweepMode { ask, always, never }

extension MonthEndSweepModeX on MonthEndSweepMode {
  static MonthEndSweepMode fromIndex(int value) => MonthEndSweepMode
      .values[value.clamp(0, MonthEndSweepMode.values.length - 1)];
}

/// One budget envelope's leftover from a closed cycle.
class MonthEndLine {
  const MonthEndLine({
    required this.envelopeId,
    required this.name,
    required this.emoji,
    required this.remaining,
    required this.carries,
  });

  final String envelopeId;
  final String name;
  final String emoji;

  /// Money left in the envelope when the cycle closed, in the envelope's own
  /// currency. Always positive - overspent envelopes never produce a line.
  final Money remaining;

  /// True for `Rollover.roll` / `Rollover.accumulate` envelopes. The review
  /// shows this setting as context; the amount moved comes from real cash.
  final bool carries;
}

/// A read-only summary of what a closed cycle left behind.
class MonthEndReview {
  const MonthEndReview({
    required this.cycleStart,
    required this.completedAt,
    required this.lines,
    required this.totalLeft,
    required this.carriedLeft,
  });

  /// Start of the cycle that closed (i.e. the cycle before the current one).
  final DateTime cycleStart;

  /// The current cycle's start - the moment the closed cycle ended.
  final DateTime completedAt;

  final List<MonthEndLine> lines;

  /// Shared cash available at cycle close, capped to cash still available now.
  final Money totalLeft;

  /// Budgeted leftovers in rollover/accumulate envelopes, shown for context.
  final Money carriedLeft;

  /// Reset envelopes shown to explain the budget plan at cycle close.
  Iterable<MonthEndLine> get resetEnvelopes =>
      lines.where((line) => !line.carries);

  /// Envelopes that keep their money automatically.
  Iterable<MonthEndLine> get carried => lines.where((line) => line.carries);

  bool get hasCashToMove => totalLeft.minor > 0;
}
