import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// First-run family setup (live mode): the one thing that makes the app
/// useful is creating a family or joining one — so that IS the onboarding.
///
/// Flow: welcome → create-or-join → (name+household | code) → invite → Home.
/// "Skip for now" always leads to Home; completeOnboarding() persists the
/// flag (m4_test covers persistence). Family RPCs: create_space / join_space.
class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({super.key, required this.state});

  final AppState state;

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

enum _Step { welcome, choice, create, join, invite }

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  _Step _step = _Step.welcome;
  bool _busy = false;
  String? _error;

  final _name = TextEditingController();
  final _code = TextEditingController();
  String _household = 'couple_kids';

  static const _households = <(String, String)>[
    ('couple_kids', 'hhCouple'),
    ('single_parent', 'hhSingle'),
    ('extended', 'hhExtended'),
    ('blended', 'hhBlended'),
    ('partners', 'hhPartners'),
    ('solo', 'hhSolo'),
    ('other', 'hhOther'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  String _hh(String key) {
    final l = AppLocalizations.of(context)!;
    return switch (key) {
      'hhCouple' => l.hhCouple,
      'hhSingle' => l.hhSingle,
      'hhExtended' => l.hhExtended,
      'hhBlended' => l.hhBlended,
      'hhPartners' => l.hhPartners,
      'hhSolo' => l.hhSolo,
      _ => l.hhOther,
    };
  }

  void _go(_Step s) => setState(() {
        _step = s;
        _error = null;
      });

  Future<void> _create() async {
    final l = AppLocalizations.of(context)!;
    if (_name.text.trim().length < 2) {
      setState(() => _error = l.familyNameHint);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final engine = widget.state.sync;
    final ok = await engine
        ?.createSpace(_name.text.trim(), household: _household) ??
        false;
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _go(_Step.invite);
    } else {
      setState(() => _error =
          engine?.lastError ?? AppLocalizations.of(context)!.savedOffline);
    }
  }

  Future<void> _join() async {
    final engine = widget.state.sync;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await engine?.joinSpace(_code.text) ?? false;
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      widget.state.completeOnboarding();
    } else {
      setState(() => _error = engine?.lastError);
    }
  }

  Future<void> _copyCode() async {
    final l = AppLocalizations.of(context)!;
    final code = widget.state.inviteCode ?? '';
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.copied),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: switch (_step) {
          _Step.welcome => _welcome(l),
          _Step.choice => _choice(l),
          _Step.create => _create_(l),
          _Step.join => _join_(l),
          _Step.invite => _invite(l),
        },
      ),
    );
  }

  // ── shared chrome ─────────────────────────────────────────────────────────

  Widget _brandTile() => Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/branding/splash.png',
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
      );

  Widget _header({required VoidCallback onBack}) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 16, 0),
        child: Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: context.inkSoft,
              style: IconButton.styleFrom(
                backgroundColor: context.card,
                minimumSize: const Size.square(44),
              ),
            ),
          ],
        ),
      );

  Widget _body({required List<Widget> children}) => Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: children,
        ),
      );

  Widget _stadium({
    required String label,
    required VoidCallback? onPressed,
    Color? color,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? context.primary,
            foregroundColor: context.onSolid,
            disabledBackgroundColor:
                (color ?? context.primary).withValues(alpha: 0.6),
            minimumSize: const Size.fromHeight(54),
            shape: const StadiumBorder(),
          ),
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      );

  Widget _errorBox(String text) => Container(
        margin: const EdgeInsets.fromLTRB(24, 4, 24, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.dangerSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text,
            style:
                TextStyle(fontSize: 12.5, color: context.expenseRed)),
      );

  // ── step 1: welcome ───────────────────────────────────────────────────────

  Widget _welcome(AppLocalizations l) => Column(
        children: [
          const SizedBox(height: 36),
          _brandTile(),
          _body(children: [
            const SizedBox(height: 24),
            Text(l.ob1Title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: context.ink)),
            const SizedBox(height: 14),
            Text(l.ob1Body,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: context.inkSoft, height: 1.5)),
          ]),
          _stadium(label: l.next, onPressed: () => _go(_Step.choice)),
          const SizedBox(height: 12),
        ],
      );

  // ── step 2: create or join ────────────────────────────────────────────────

  Widget _choiceCard({
    required IconData icon,
    required String title,
    required String body,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
          color: context.card,
          borderRadius: kBRadiusL,
          child: InkWell(
            onTap: onTap,
            borderRadius: kBRadiusL,
            splashColor: context.primarySoft,
            highlightColor: context.primarySoft,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: kBRadiusL,
                border: Border.all(color: context.hairline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [context.primary, context.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 26, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: context.ink)),
                        const SizedBox(height: 3),
                        Text(body,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: context.inkSoft,
                                height: 1.35)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.inkSoft),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _choice(AppLocalizations l) => Column(
        children: [
          _header(onBack: () => _go(_Step.welcome)),
          _body(children: [
            Text(l.setupChoiceTitle,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.ink)),
            const SizedBox(height: 8),
            Text(l.setupChoiceBody,
                style: TextStyle(
                    fontSize: 13.5, color: context.inkSoft, height: 1.45)),
            const SizedBox(height: 22),
            _choiceCard(
              icon: Icons.diversity_3,
              title: l.setupCreateCard,
              body: l.setupCreateCardBody,
              onTap: () => _go(_Step.create),
            ),
            _choiceCard(
              icon: Icons.link_rounded,
              title: l.setupJoinCard,
              body: l.setupJoinCardBody,
              onTap: () => _go(_Step.join),
            ),
          ]),
          Center(
            child: TextButton(
              onPressed: widget.state.completeOnboarding,
              style:
                  TextButton.styleFrom(minimumSize: const Size(64, 48)),
              child: Text(l.skipForNow,
                  style: TextStyle(
                      color: context.inkSoft,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );

  // ── step 3a: create ───────────────────────────────────────────────────────

  Widget _create_(AppLocalizations l) => Column(
        children: [
          _header(onBack: () => _go(_Step.choice)),
          _body(children: [
            Text(l.setupCreateCard,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.ink)),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.ink),
              decoration: InputDecoration(
                labelText: l.familyNameLabel,
                hintText: l.familyNameHint,
                prefixIcon:
                    Icon(Icons.home_rounded, color: context.inkSoft),
                filled: true,
                fillColor: context.card,
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 18),
            Text(l.householdLabel,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.inkSoft)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, key) in _households)
                  ChoiceChip(
                    label: Text(_hh(key)),
                    selected: _household == value,
                    onSelected: (_) => setState(() => _household = value),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              _errorBox(_error!),
            ],
          ]),
          _stadium(
            label: l.createFamilyCta,
            onPressed: _busy ? null : _create,
          ),
          const SizedBox(height: 12),
        ],
      );

  // ── step 3b: join ─────────────────────────────────────────────────────────

  Widget _join_(AppLocalizations l) => Column(
        children: [
          _header(onBack: () => _go(_Step.choice)),
          _body(children: [
            Text(l.setupJoinCard,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.ink)),
            const SizedBox(height: 8),
            Text(l.inviteHowTo,
                style: TextStyle(
                    fontSize: 13.5, color: context.inkSoft, height: 1.45)),
            const SizedBox(height: 18),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
              maxLength: 8,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                  letterSpacing: 6),
              decoration: InputDecoration(
                labelText: l.joinCodeLabel,
                counterText: '',
                prefixIcon:
                    Icon(Icons.key_rounded, color: context.inkSoft),
                filled: true,
                fillColor: context.card,
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              _errorBox(_error!),
            ],
          ]),
          _stadium(
            label: l.joinFamilyCta,
            onPressed: _busy ? null : _join,
          ),
          const SizedBox(height: 12),
        ],
      );

  // ── step 4: invite (create path only) ─────────────────────────────────────

  Widget _invite(AppLocalizations l) {
    final code = widget.state.inviteCode ?? '';
    return Column(
      children: [
        _header(onBack: () => _go(_Step.choice)),
        _body(children: [
          Text(l.setupInviteTitle,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.ink)),
          const SizedBox(height: 8),
          Text(l.inviteHowTo,
              style: TextStyle(
                  fontSize: 13.5, color: context.inkSoft, height: 1.45)),
          const SizedBox(height: 18),
          if (code.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.primary, width: 1.4),
              ),
              alignment: Alignment.center,
              child: Text(
                code,
                style: TextStyle(
                  fontSize: 26,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w800,
                  color: context.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _copyCode,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.primary,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
                side: BorderSide(color: context.primary),
              ),
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l.copyInvite),
            ),
          ],
        ]),
        _stadium(
          label: l.obDone,
          onPressed: () {
            widget.state.completeOnboarding();
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
