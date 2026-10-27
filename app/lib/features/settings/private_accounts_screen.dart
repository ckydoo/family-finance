import 'package:flutter/material.dart';

import '../../core/models/models.dart' show TxType;
import '../../core/money/money.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../activity/activity_screen.dart';
import '../quickadd/quick_add_sheet.dart' show showQuickAdd;

/// Setup and overview for a member's private finances.
class PrivateAccountsScreen extends StatelessWidget {
  const PrivateAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final accounts = state.accounts
            .where((account) =>
                account.isPrivate && account.ownerMemberId == state.realUser.id)
            .toList(growable: false);
        return Scaffold(
          backgroundColor: context.bg,
          appBar: AppBar(title: const Text('Private accounts')),
          body: SafeArea(
            child: ListView(
              padding: kPageInsets,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.primarySoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded, color: context.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Keep side hustles or personal finances separate from the family budget. Only you can see your private accounts and their transactions.',
                          style: TextStyle(
                            color: context.ink,
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your private account',
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (accounts.isEmpty && state.canAuthorTransact)
                      FilledButton.icon(
                        onPressed: () => _createAccount(context, state),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (accounts.isEmpty)
                  _EmptyPrivateAccounts(
                    canCreate: state.canAuthorTransact,
                    onCreate: () => _createAccount(context, state),
                  )
                else
                  for (final account in accounts)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: context.primarySoft,
                                child: Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: context.primary),
                              ),
                              title: Text(account.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: const Text(
                                  'Private · tap to view transactions'),
                              onTap: () => Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => ActivityScreen(
                                    initialAccountId: account.id,
                                  ),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    state.privateAccountBalance(account).text,
                                    style: TextStyle(
                                      color: context.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => showQuickAdd(
                                        context,
                                        initialType: TxType.income,
                                        accountId: account.id,
                                      ),
                                      icon: const Icon(
                                          Icons.add_circle_outline_rounded,
                                          size: 18),
                                      label: const Text('Add income'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => showQuickAdd(
                                        context,
                                        initialType: TxType.expense,
                                        accountId: account.id,
                                      ),
                                      icon: const Icon(
                                          Icons.remove_circle_outline_rounded,
                                          size: 18),
                                      label: const Text('Add expense'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                Text(
                  'Use Add income or Add expense on an account to record transactions. They update that private balance and stay out of family totals.',
                  style: TextStyle(
                    color: context.inkSoft,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createAccount(BuildContext context, AppState state) async {
    final result = await showDialog<_PrivateAccountDraft>(
      context: context,
      builder: (_) => _PrivateAccountDialog(
        initialCurrency: state.displayCurrency,
        currencies: state.activeCurrencies,
      ),
    );
    if (result == null || result.name.isEmpty || !context.mounted) return;
    final account = state.createPrivateAccount(
      result.name,
      currency: result.currency,
    );
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not create a private account.'),
      ));
    }
  }
}

class _PrivateAccountDraft {
  const _PrivateAccountDraft(this.name, this.currency);

  final String name;
  final Currency currency;
}

class _PrivateAccountDialog extends StatefulWidget {
  const _PrivateAccountDialog({
    required this.initialCurrency,
    required this.currencies,
  });

  final Currency initialCurrency;
  final List<Currency> currencies;

  @override
  State<_PrivateAccountDialog> createState() => _PrivateAccountDialogState();
}

class _PrivateAccountDialogState extends State<_PrivateAccountDialog> {
  late final TextEditingController _controller;
  late Currency _currency;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _currency = widget.initialCurrency;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(
      context,
      _PrivateAccountDraft(_controller.text.trim(), _currency),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create private account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Account name',
                hintText: 'For example, Side hustle',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Text('Currency',
                style: TextStyle(
                  color: context.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final value in widget.currencies)
                  ChoiceChip(
                    label: Text(value.code),
                    selected: _currency == value,
                    onSelected: (_) => setState(() => _currency = value),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('Create account'),
          ),
        ],
      );
}

class _EmptyPrivateAccounts extends StatelessWidget {
  const _EmptyPrivateAccounts({
    required this.canCreate,
    required this.onCreate,
  });

  final bool canCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.hairline),
        ),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 30, color: context.inkSoft),
            const SizedBox(height: 10),
            Text('No private account yet',
                style: TextStyle(
                  color: context.ink,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 5),
            Text(
              canCreate
                  ? 'Create one for your personal finances or side hustle.'
                  : 'Ask an adult family member to set up a private account for you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.inkSoft, fontSize: 12),
            ),
            if (canCreate) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create private account'),
              ),
            ],
          ],
        ),
      );
}
