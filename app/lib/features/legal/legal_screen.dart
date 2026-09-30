import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';

enum LegalSection { privacy, terms, disclaimer, dataRights }

/// Legalities, Terms of Service, Privacy Policy, and Disclaimers screen.
class LegalScreen extends StatefulWidget {
  const LegalScreen({
    super.key,
    this.initialSection = LegalSection.privacy,
  });

  final LegalSection initialSection;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late LegalSection _currentSection;

  @override
  void initState() {
    super.initState();
    _currentSection = widget.initialSection;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text(
          'Legal & Compliance',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Open Source Licenses',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Mhuri',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2026 Mhuri. All rights reserved.\n'
                  'Built for African family financial collaboration.',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Segment selector
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('Privacy Policy', LegalSection.privacy),
                    const SizedBox(width: 8),
                    _filterChip('Terms of Service', LegalSection.terms),
                    const SizedBox(width: 8),
                    _filterChip(
                        'Financial Disclaimer', LegalSection.disclaimer),
                    const SizedBox(width: 8),
                    _filterChip('Data & Deletion', LegalSection.dataRights),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  switch (_currentSection) {
                    LegalSection.privacy => _buildPrivacyPolicy(context),
                    LegalSection.terms => _buildTermsOfService(context),
                    LegalSection.disclaimer =>
                      _buildFinancialDisclaimer(context),
                    LegalSection.dataRights => _buildDataRights(context),
                  },
                  const SizedBox(height: 24),
                  _buildFooter(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String title, LegalSection section) {
    final selected = _currentSection == section;
    return ChoiceChip(
      label: Text(title),
      selected: selected,
      onSelected: (_) => setState(() => _currentSection = section),
      selectedColor: context.primarySoft,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        color: selected ? context.primary : context.inkSoft,
      ),
      side: BorderSide(
        color: selected ? context.primary : context.hairline,
      ),
    );
  }

  // ── Privacy Policy ────────────────────────────────────────────────────────
  Widget _buildPrivacyPolicy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleBadge('Privacy Policy', 'Effective: September 2026',
            Icons.privacy_tip_outlined),
        const SizedBox(height: 16),
        Text(
          'Mhuri is a family finance and envelope budgeting platform. '
          'We believe family financial records belong exclusively to the household that earned them. '
          'This Privacy Policy outlines how your data is processed, protected, and removed in plain language.',
          style: TextStyle(fontSize: 14, color: context.ink, height: 1.5),
        ),
        const SizedBox(height: 16),
        _sectionTitle('1. Information We Collect'),
        _cardItem(
          title: 'Account Credentials',
          description:
              'Email address and password. Passwords are salted and cryptographically hashed by our authentication infrastructure (Supabase Auth). We never have access to your plain-text password.',
        ),
        _cardItem(
          title: 'Family Financial Content',
          description:
              'Envelopes, income, expense transactions, shopping lists, bills, savings goals, and Mukando records. This content is isolated and scoped strictly to your unique Family Space ID.',
        ),
        _cardItem(
          title: 'Children & Minor Profiles',
          description:
              'Kids and teens have display names and avatar icons. Kids authenticate locally on a parent’s device using a local profile PIN. We do NOT collect phone numbers, email addresses, or marketing identifiers from children.',
        ),
        _cardItem(
          title: 'Diagnostics, Usage & Notifications',
          description:
              'Firebase processes an app-installation identifier, device push token, notification delivery/open events, and privacy-limited usage events so we can deliver important family updates and improve reliability. We do not send transaction amounts, balances, family names, email addresses, or children’s profile data to Analytics.',
        ),
        const SizedBox(height: 16),
        _sectionTitle('2. What We NEVER Collect or Sell'),
        _bulletPoint(
            'No Cross-App Advertising: We do not use Firebase data for advertising or track you across other companies’ apps or websites.'),
        _bulletPoint(
            'No Data Sales: Your family financial records are never monetized, sold, or shared with data brokers.'),
        _bulletPoint(
            'No Background Location or Contacts: We never request contacts or GPS tracking.'),
        _bulletPoint(
            'No Financial Account Takeover: We do not ask for bank login credentials or debit card PINs.'),
        const SizedBox(height: 16),
        _sectionTitle('3. Security & Row-Level Protection'),
        Text(
          'All database writes and reads are enforced by Postgres Row-Level Security (RLS) policies at the database layer. '
          'A user from Family A cannot view, query, or mutate records from Family B. '
          'All network communication occurs over encrypted TLS/HTTPS.',
          style:
              TextStyle(fontSize: 13.5, color: context.inkSoft, height: 1.45),
        ),
      ],
    );
  }

  // ── Terms of Service ──────────────────────────────────────────────────────
  Widget _buildTermsOfService(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleBadge('Terms of Service', 'Last Updated: September 2026',
            Icons.gavel_outlined),
        const SizedBox(height: 16),
        Text(
          'By creating an account, adopting a Family Space, or using Mhuri, '
          'you agree to be bound by these Terms of Service. If you disagree with any part of these terms, '
          'you should immediately discontinue use of the service.',
          style: TextStyle(fontSize: 14, color: context.ink, height: 1.5),
        ),
        const SizedBox(height: 16),
        _sectionTitle('1. Intended Use & Household Governance'),
        Text(
          'Mhuri is provided for domestic household budgeting, envelope tracking, and collaborative family savings. '
          'The family space Owner maintains administrative control over member roles, invitations, and space settings. '
          'You agree not to use the platform for unlawful financial schemes, money laundering, or malicious disruption.',
          style:
              TextStyle(fontSize: 13.5, color: context.inkSoft, height: 1.45),
        ),
        const SizedBox(height: 16),
        _sectionTitle('2. User Account Responsibilities'),
        Text(
          'You are responsible for safeguarding the credentials used to access your Mhuri account. '
          'You agree to notify your family administrator or Mhuri support immediately if you suspect unauthorized access to your account or device.',
          style:
              TextStyle(fontSize: 13.5, color: context.inkSoft, height: 1.45),
        ),
        const SizedBox(height: 16),
        _sectionTitle('3. Availability & Service Continuity'),
        Text(
          'Mhuri operates under an offline-first architecture. Local mutations are preserved on your physical device '
          'even when internet access is unavailable. While we strive for continuous cloud synchronization, '
          'we do not guarantee uninterrupted connectivity or zero latency during network disruptions.',
          style:
              TextStyle(fontSize: 13.5, color: context.inkSoft, height: 1.45),
        ),
        const SizedBox(height: 16),
        _sectionTitle('4. Limitation of Liability'),
        Text(
          'To the fullest extent permitted by applicable law, Mhuri and its contributors shall not be liable '
          'for indirect, incidental, or consequential damages resulting from user budgeting calculations, '
          'exchange rate differences, third-party network outages, or device loss.',
          style:
              TextStyle(fontSize: 13.5, color: context.inkSoft, height: 1.45),
        ),
      ],
    );
  }

  // ── Financial Disclaimer ──────────────────────────────────────────────────
  Widget _buildFinancialDisclaimer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade700, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.amber.shade900, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Important Regulatory Notice',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mhuri is NOT a bank, credit provider, licensed asset manager, or deposit-taking institution.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('1. Informational & Record-Keeping Tool Only'),
        Text(
          'Mhuri is a self-directed digital ledger designed to help families plan budgets and monitor spending. '
          'The app does not hold, transmit, custody, or invest actual fiat or digital currency funds. '
          'All monetary mutations inside the app represent mathematical ledger records of physical cash, '
          'mobile money, cards, or electronic banking transactions conducted externally by you.',
          style:
              TextStyle(fontSize: 13.5, color: context.inkSoft, height: 1.45),
        ),
        const SizedBox(height: 16),
        _sectionTitle('2. No Professional Financial or Investment Advice'),
        Text(
          'Content, envelope recommendations, safe-per-day spending limits, and reports within Mhuri '
          'are computational estimations for educational and organizational purposes only. '
          'Nothing in the app constitutes certified financial, legal, tax, or investment advice. '
          'Consult a licensed financial professional for individual financial planning decisions.',
          style:
              TextStyle(fontSize: 13.5, color: context.inkSoft, height: 1.45),
        ),
        const SizedBox(height: 16),
        _sectionTitle('3. Currency & Exchange Rate Disclosures'),
        Text(
          'Exchange rates across supported global currencies (USD, EUR, GBP, ZAR, CAD, AUD, KES, NGN, INR, ZiG) '
          'are pulled periodically from published financial market indicators or set manually by your family administrator. '
          'Market rates fluctuate, and rates displayed inside the app are reference indicators for consolidated reporting. '
          'Mhuri is not liable for price or exchange disparities during real-world transactions.',
          style:
              TextStyle(fontSize: 13.5, color: context.inkSoft, height: 1.45),
        ),
        const SizedBox(height: 16),
        _sectionTitle('4. Community Savings (Mukando / ROSCAs)'),
        Text(
          'The Mukando feature is an administrative tally for traditional rotating savings and credit associations. '
          'Mhuri does not escrow or guarantee member contributions, rounds, or payouts. '
          'Trust and distribution remain entirely between participating family members.',
          style:
              TextStyle(fontSize: 13.5, color: context.inkSoft, height: 1.45),
        ),
      ],
    );
  }

  // ── Data & Deletion ───────────────────────────────────────────────────────
  Widget _buildDataRights(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleBadge('Data Rights & Deletion', 'Compliance & Control',
            Icons.delete_outline_rounded),
        const SizedBox(height: 16),
        Text(
          'In compliance with global data privacy frameworks (including GDPR, UK GDPR, POPIA, CCPA, and regional data protection regulations), '
          'you maintain complete sovereignty over your personal data.',
          style: TextStyle(fontSize: 14, color: context.ink, height: 1.5),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Your Rights as a Data Subject'),
        _bulletPoint(
            'Right of Access: Export your full family ledger to CSV at any time under Settings → Export CSV.'),
        _bulletPoint(
            'Right to Rectification: Correct your name, avatar, or role directly from Family Members settings.'),
        _bulletPoint(
            'Right to Erasure (Right to be Forgotten): Delete your account or entire family space at any time.'),
        _bulletPoint(
            'Data Portability: Standard CSV formatting allows importing your transactions into spreadsheets or other accounting software.'),
        const SizedBox(height: 16),
        _sectionTitle('Account Deletion Process'),
        _cardItem(
          title: 'Leaving a Family (Member)',
          description:
              'Go to Family → Your Profile → "Leave family". Your user membership is deleted and authorization tokens revoked. Your past transaction records remain in the family ledger attributed to "Former Member" so household accounting remains balanced.',
        ),
        _cardItem(
          title: 'Deleting a Family Space (Owner)',
          description:
              'The family owner can transfer ownership to another parent, or permanently delete the entire family space. Deleting a space triggers a database cascade deletion of all budgets, transactions, lists, and avatars.',
        ),
        _cardItem(
          title: 'Permanent Account Purge',
          description:
              'You can initiate permanent account deletion directly from the Settings screen. Re-authentication is required to prevent accidental erasure. Backups age out within 30 days.',
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _titleBadge(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: context.primary, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: context.ink,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12.5, color: context.inkSoft),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: context.ink,
        ),
      ),
    );
  }

  Widget _cardItem({required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MhuriCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12.5,
                color: context.inkSoft,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: context.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: context.inkSoft,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, size: 20),
              const SizedBox(width: 8),
              Text(
                'Questions or Data Requests?',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'For compliance inquiries or assistance with data export and deletion, '
            'contact your family administrator or reach out at privacy@mhuri.app.',
            style: TextStyle(fontSize: 12, color: context.inkSoft, height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('View Open Source Licenses'),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Mhuri',
              applicationVersion: '1.0.0',
            ),
          ),
        ],
      ),
    );
  }
}
