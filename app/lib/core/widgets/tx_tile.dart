import 'package:flutter/material.dart';

import '../models/models.dart' show Tx, TxType;
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/when.dart';
import 'app_icons.dart';

/// One transaction row — used on Home (recent) and Activity (full feed).
class TxTile extends StatelessWidget {
  final Tx tx;
  final bool dense;

  const TxTile({super.key, required this.tx, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final env = s.envelope(tx.envelopeId);
    final icon = tx.type == TxType.income
        ? Icons.savings
        : iconForKey(env?.emoji) ?? Icons.receipt_long;
    final member = s.member(tx.memberId);
    final isIn = tx.type == TxType.income;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 10 : 14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFEDF4F1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 21, color: context.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${member?.name ?? ''} · ${fmtWhen(tx.when)}',
                  style: TextStyle(fontSize: 12, color: context.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isIn ? '+' : '-'}${tx.amount.text}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: isIn ? context.incomeGreen : context.expenseRed,
            ),
          ),
        ],
      ),
    );
  }
}
