import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';

enum GuideCategory { all, budgeting, currency, shopping, savings, family, sync }

class InstructionsScreen extends StatefulWidget {
  const InstructionsScreen({super.key});

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  final _searchController = TextEditingController();
  GuideCategory _selectedCategory = GuideCategory.all;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredGuides = _allGuides.where((guide) {
      final matchesCategory = _selectedCategory == GuideCategory.all ||
          guide.category == _selectedCategory;
      final q = _searchQuery.toLowerCase().trim();
      final matchesSearch = q.isEmpty ||
          guide.title.toLowerCase().contains(q) ||
          guide.summary.toLowerCase().contains(q) ||
          guide.steps.any((s) => s.toLowerCase().contains(q));
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text(
          'How Mhuri Works',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText:
                      'Search guide (e.g. envelope, rate, mukando, chore)...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: context.card,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // Category filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _categoryChip('All Guides', GuideCategory.all),
                  const SizedBox(width: 8),
                  _categoryChip('Budgeting', GuideCategory.budgeting),
                  const SizedBox(width: 8),
                  _categoryChip('Currencies', GuideCategory.currency),
                  const SizedBox(width: 8),
                  _categoryChip('Shopping', GuideCategory.shopping),
                  const SizedBox(width: 8),
                  _categoryChip('Savings & Mukando', GuideCategory.savings),
                  const SizedBox(width: 8),
                  _categoryChip('Kids & Roles', GuideCategory.family),
                  const SizedBox(width: 8),
                  _categoryChip('Offline & Sync', GuideCategory.sync),
                ],
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: filteredGuides.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 48, color: context.inkSoft),
                          const SizedBox(height: 8),
                          Text(
                            'No guides matching "$_searchQuery"',
                            style:
                                TextStyle(fontSize: 14, color: context.inkSoft),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: filteredGuides.length,
                      itemBuilder: (context, index) {
                        final guide = filteredGuides[index];
                        return _buildGuideCard(context, guide);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String label, GuideCategory category) {
    final selected = _selectedCategory == category;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedCategory = category),
      selectedColor: context.primarySoft,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        color: selected ? context.primary : context.inkSoft,
      ),
      side: BorderSide(
        color: selected ? context.primary : context.hairline,
      ),
    );
  }

  Widget _buildGuideCard(BuildContext context, _GuideItem guide) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MhuriCard(
        padding: const EdgeInsets.all(0),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Icon(guide.icon, color: context.primary, size: 22),
              ),
            ),
            title: Text(
              guide.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: context.ink,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                guide.summary,
                style: TextStyle(fontSize: 12.5, color: context.inkSoft),
              ),
            ),
            children: [
              const Divider(height: 20),
              for (var i = 0; i < guide.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(right: 10, top: 2),
                        decoration: BoxDecoration(
                          color: context.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: context.primary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          guide.steps[i],
                          style: TextStyle(
                            fontSize: 13,
                            color: context.ink,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (guide.proTip != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          guide.proTip!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideItem {
  final String title;
  final String summary;
  final IconData icon;
  final GuideCategory category;
  final List<String> steps;
  final String? proTip;

  const _GuideItem({
    required this.title,
    required this.summary,
    required this.icon,
    required this.category,
    required this.steps,
    this.proTip,
  });
}

const List<_GuideItem> _allGuides = [
  _GuideItem(
    title: 'Zero-Based Envelope Budgeting',
    summary: 'Give every unit of money a specific job before you spend it.',
    icon: Icons.mail_outline,
    category: GuideCategory.budgeting,
    steps: [
      'Create envelopes for your regular expenses (e.g., Groceries, Rent, Fuel, Utilities).',
      'Set a monthly limit in your preferred currency.',
      'Choose a rollover mode: Reset (starts fresh each cycle), Rollover (carries surpluses/deficits), or Accumulate (savings buffer).',
      'Log expenses directly to the envelope using the Quick Add button (+) on the home screen.',
      'Check envelope health rings regularly to avoid end-of-month surprises.',
    ],
    proTip:
        'Configure your Overspend Policy in Family Settings to either warn you before overspending or strictly block over-budget expenses.',
  ),
  _GuideItem(
    title: 'Multi-Currency & Dual-Currency Tracking',
    summary:
        'Manage single or multi-currency households with exact conversion.',
    icon: Icons.currency_exchange,
    category: GuideCategory.currency,
    steps: [
      'Mhuri supports global currencies including USD, EUR, GBP, ZAR, CAD, AUD, KES, NGN, INR, and ZiG (ZWG).',
      'Configure your Primary Currency and optional Secondary Currency in Family Settings → Currency.',
      'When adding an expense or income, select the exact currency of the transaction.',
      'Configure exchange rates to match current market or bank rates under Settings.',
      'Tap the currency toggle on the Home screen to view your total Family Pool in any active currency without altering underlying records.',
    ],
    proTip:
        'The original recorded currency and amount are always authoritative. Conversions are applied dynamically for consolidated balances.',
  ),
  _GuideItem(
    title: 'Household Roles & Permissions',
    summary:
        'Ensure each family member has the right level of access and responsibility.',
    icon: Icons.people_outline,
    category: GuideCategory.family,
    steps: [
      'Owner: The creator of the Family Space. Full administrative authority, invites, role assignment, and ownership transfer.',
      'Adult (Parent / Admin): Full financial access, can approve chores and kid requests, manage envelopes, and invite members.',
      'Teen: Can propose budget expenses, record independent side earnings, and earn a 50% parental savings match in their jar.',
      'Child (Kid): Signs in on a parent’s phone via Profile PIN. Can claim chores for star rewards and request pocket money into their Kid Jar.',
      'Viewer: Read-only observer (e.g. grandparents or family accountant); cannot post or edit transactions.',
    ],
    proTip:
        'Parents can use Profile Preview in Family Members to test what their kids or teens see without accidentally granting elevated permissions.',
  ),
  _GuideItem(
    title: 'Collaborative Shopping Runs',
    summary:
        'Shared live grocery lists that turn into budget expenses in one tap.',
    icon: Icons.shopping_cart_outlined,
    category: GuideCategory.shopping,
    steps: [
      'Any family member can add items and cost estimates to the shared Shopping List.',
      'While at the supermarket, tap items to mark them as in-cart or done in real time across family devices.',
      'When finished at the checkout till, tap "Finish Shopping".',
      'Mhuri automatically tallies the checked items and creates a single consolidated expense against your Groceries envelope!',
    ],
    proTip:
        'You can adjust the final receipt total before posting if actual store prices differed from your estimates.',
  ),
  _GuideItem(
    title: 'Mukando & Rotating Savings Circles (ROSCA)',
    summary:
        'Track family and community round-robin savings clubs without paper ledgers.',
    icon: Icons.autorenew,
    category: GuideCategory.savings,
    steps: [
      'Enable Mukando under Settings → Savings to activate the circle header.',
      'Set the fixed contribution amount (e.g. \$50 / month) and the member rotation order.',
      'Each cycle, Mhuri tracks who has contributed and whose turn it is to receive the accumulated pot.',
      'Tap "Collect Round" when the recipient receives their payout to advance the round counter.',
    ],
    proTip:
        'Savings circle rounds are records only. All funds remain in the physical custody of the family or chosen club treasurer.',
  ),
  _GuideItem(
    title: 'Chores & Star Rewards for Kids',
    summary:
        'Teach financial literacy and responsibility through earned allowances.',
    icon: Icons.star_outline,
    category: GuideCategory.family,
    steps: [
      'Parents create chores with star values (e.g. Wash dishes = 3 stars, Clean yard = 5 stars).',
      'Kids switch to Kids Mode and tap "I did this!" to submit a chore for review.',
      'Parents review completed tasks on the Home notification bell or in Kids Mode and tap "Confirm".',
      'Kids can convert stars into pocket money requests that land directly in their digital savings jar!',
    ],
    proTip:
        'Kids Mode is protected by a 4-digit parent PIN so children cannot alter envelope budgets or account settings.',
  ),
  _GuideItem(
    title: 'Offline-First & Cloud Sync',
    summary:
        'Never lose a transaction, even when electricity or mobile network is down.',
    icon: Icons.cloud_done_outlined,
    category: GuideCategory.sync,
    steps: [
      'Every mutation is committed locally to your device’s secure database first. You never have to wait for a loading spinner.',
      'An encrypted outbox queues your changes and flushes them to the family cloud as soon as data or Wi-Fi reconnects.',
      'Visit Settings → Sync & Data to see your connection status, pending change count, and last sync timestamp.',
      'If changes ever fail due to server issues, they are held safely under "Changes that need you" with full retry and discard options.',
      'Export a complete CSV file under Settings at any time to keep your own independent spreadsheet backup.',
    ],
    proTip:
        'If your sync indicator shows "Waiting to retry", simply tap "Sync now" in Settings to trigger an immediate push of any parked items.',
  ),
  _GuideItem(
    title: 'Moving Money Between Envelopes',
    summary: 'Reallocate funds on the fly when unexpected expenses arise.',
    icon: Icons.swap_horiz,
    category: GuideCategory.budgeting,
    steps: [
      'Open the Budgets tab and select any envelope.',
      'Tap "Move money" in the top action bar or bottom sheet.',
      'Select the source envelope, the destination envelope, the amount, and a brief reason (e.g., "Car repair emergency").',
      'The transfer updates both envelopes immediately and logs an audit record so your family balance remains reconciled.',
    ],
    proTip:
        'Moving money maintains envelope balance invariants and never creates fake new income or expenses in your reports.',
  ),
];
