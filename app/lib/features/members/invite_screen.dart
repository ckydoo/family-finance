import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/sync/supabase_sync_client.dart';
import '../../core/widgets/ui.dart';
import '../../l10n/generated/app_localizations.dart';

/// Owner-managed invitations (migration 010): create role-bound invites,
/// show them as QR + code with share/copy, list pending/accepted, revoke.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  static const _roles = <String, String>{
    'adult': 'roleAdult',
    'co_parent': 'roleParent',
    'teen': 'roleTeen',
    'kid': 'roleChild',
    'viewer': 'roleViewer',
  };

  String _role = 'adult';
  final _email = TextEditingController();
  bool _busy = false;
  bool _loaded = false;
  String? _newCode;
  List<InviteInfo>? _invites;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String _roleLabel(AppLocalizations l, String role) => switch (role) {
        'adult' => l.roleAdult,
        'co_parent' => l.roleParent,
        'teen' => l.roleTeen,
        'kid' => l.roleChild,
        'viewer' => l.roleViewer,
        _ => role,
      };

  Future<void> _load() async {
    try {
      final list = await AppScope.of(context).sync?.listInvites() ?? [];
      if (!mounted) return;
      setState(() => _invites = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)!.invitesLoadFailed);
    }
  }

  Future<void> _create() async {
    final l = AppLocalizations.of(context)!;
    final s = AppScope.of(context);
    if (!s.canInvite) {
      setState(() => _error = l.inviteOwnerOnly);
      return;
    }
    final email = _email.text.trim();
    if (email.isNotEmpty && !RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      setState(() => _error = l.loginBadEmail);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await AppScope.of(context)
          .sync
          ?.createInvite(_role, email: email.isEmpty ? null : email);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _newCode = r?['code'];
        _email.clear();
      });
      HapticFeedback.mediumImpact();
      await _load();
    } on SyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message.contains('TOO_MANY_INVITES')
            ? l.inviteTooMany
            : l.inviteFailed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l.inviteFailed;
      });
    }
  }

  Future<void> _revoke(InviteInfo inv) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.inviteRevoke),
        content: Text(l.inviteRevokeBody(inv.code)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.inviteRevoke)),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    try {
      await AppScope.of(context).sync?.revokeInvite(inv.id);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.inviteFailed),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _share(InviteInfo inv) {
    final l = AppLocalizations.of(context)!;
    SharePlus.instance.share(
      ShareParams(
        text: '${l.inviteShareText} ${inv.link}',
        title: 'Mhuri',
      ),
    );
  }

  Future<void> _showCreateAccount() async {
    final s = AppScope.of(context);
    final l = AppLocalizations.of(context)!;
    if (!s.canInvite) {
      setState(() => _error = l.inviteOwnerOnly);
      return;
    }
    final created = await showMhuriSheet<bool>(
      context: context,
      builder: (_) => _CreateMemberAccountSheet(
        state: s,
        ownerCanGrantAdult: s.authRole == Role.owner,
      ),
    );
    if (created != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.memberAccountCreated),
      behavior: SnackBarBehavior.floating,
    ));
    await s.sync?.syncNow(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = AppScope.of(context);
    final open = _invites?.where((i) => i.isOpen).toList() ?? [];
    final done = _invites?.where((i) => !i.isOpen).toList() ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(l.inviteTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // ── new invite ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.inviteNew,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in _roles.entries)
                        ChoiceChip(
                          label: Text(_roleLabel(l, e.key)),
                          selected: _role == e.key,
                          onSelected: (_) => setState(() => _role = e.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l.inviteEmailOptional,
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _create,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2))
                        : const Icon(Icons.person_add_alt, size: 18),
                    label: Text(l.inviteCreate),
                  ),
                ],
              ),
            ),

            // ── just-created: code + QR ───────────────────────────────
            if (_newCode != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.primary, width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(l.inviteCreated,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    QrImageView(
                      data: 'mhuri://join?c=$_newCode',
                      size: 168,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    SelectableText(_newCode!,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2)),
                    const SizedBox(height: 6),
                    Text(l.inviteScanHint,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12.5, color: context.inkSoft)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _newCode!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(l.copied),
                                  behavior: SnackBarBehavior.floating),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: Text(l.copyInvite),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.tonalIcon(
                          onPressed: () => _share(
                              InviteInfo(id: '', code: _newCode!, role: _role)),
                          icon: Icon(Icons.adaptive.share, size: 16),
                          label: Text(l.inviteShare),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.memberAccountTitle,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(l.memberAccountSubtitle,
                      style: TextStyle(fontSize: 12.5, color: context.inkSoft)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: s.canInvite ? _showCreateAccount : null,
                    icon: const Icon(Icons.manage_accounts_outlined, size: 19),
                    label: Text(l.memberAccountAction),
                  ),
                ],
              ),
            ),

            // ── pending ───────────────────────────────────────────────
            const SizedBox(height: 16),
            Text(l.invitePending,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: context.inkSoft)),
            const SizedBox(height: 6),
            if (_invites == null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else if (open.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l.inviteNone,
                    style: TextStyle(fontSize: 13, color: context.inkSoft)),
              )
            else
              for (final inv in open)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.link, size: 20),
                  title: Text('${inv.code} · ${_roleLabel(l, inv.role)}',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                  subtitle: inv.email != null
                      ? Text(inv.email!, style: const TextStyle(fontSize: 12))
                      : null,
                  trailing: IconButton(
                    tooltip: l.inviteRevoke,
                    icon: const Icon(Icons.link_off, size: 20),
                    onPressed: () => _revoke(inv),
                  ),
                ),

            // ── history (accepted/revoked/expired) ────────────────────
            if (done.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l.inviteHistory,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: context.inkSoft)),
              const SizedBox(height: 6),
              for (final inv in done)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    inv.acceptedAt != null
                        ? Icons.check_circle_outline
                        : Icons.link_off,
                    size: 20,
                    color: inv.acceptedAt != null ? Colors.green : null,
                  ),
                  title: Text(
                    inv.acceptedAt != null
                        ? l.inviteAcceptedLabel(
                            inv.code, _roleLabel(l, inv.role))
                        : '${inv.code} · ${_roleLabel(l, inv.role)}',
                    style: TextStyle(
                        fontSize: 13,
                        color: context.inkSoft,
                        decoration: inv.revokedAt != null
                            ? TextDecoration.lineThrough
                            : null),
                  ),
                ),
            ],
            if (!s.canInvite)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(l.inviteOwnerOnly,
                    style: TextStyle(fontSize: 12, color: context.inkSoft)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateMemberAccountSheet extends StatefulWidget {
  const _CreateMemberAccountSheet({
    required this.state,
    required this.ownerCanGrantAdult,
  });

  final AppState state;
  final bool ownerCanGrantAdult;

  @override
  State<_CreateMemberAccountSheet> createState() =>
      _CreateMemberAccountSheetState();
}

class _CreateMemberAccountSheetState extends State<_CreateMemberAccountSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String _role = 'teen';
  String? _error;

  List<String> get _roles => widget.ownerCanGrantAdult
      ? const ['co_parent', 'adult', 'teen', 'kid', 'viewer']
      : const ['teen', 'kid', 'viewer'];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _roleLabel(AppLocalizations l, String role) => switch (role) {
        'adult' => l.roleAdult,
        'co_parent' => l.roleParent,
        'teen' => l.roleTeen,
        'kid' => l.roleChild,
        'viewer' => l.roleViewer,
        _ => role,
      };

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.length < 2) {
      setState(() => _error = l.memberAccountBadName);
      return;
    }
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      setState(() => _error = l.loginBadEmail);
      return;
    }
    if (password.length < 10 ||
        !RegExp('[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      setState(() => _error = l.memberAccountPasswordRule);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final engine = widget.state.sync;
      if (engine == null) {
        throw const SyncException(0, 'SYNC_NOT_READY');
      }
      await engine.createFamilyMember(
        name: name,
        email: email,
        temporaryPassword: password,
        role: _role,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on SyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message.contains('EMAIL_EXISTS')
            ? l.memberAccountEmailExists
            : e.message.contains('OWNER_REQUIRED_FOR_ADULT')
                ? l.memberAccountOwnerRole
                : l.memberAccountFailed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l.memberAccountFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return MhuriSheetShell(
      title: l.memberAccountTitle,
      subtitle: l.memberAccountSheetSubtitle,
      isDirty: _name.text.isNotEmpty ||
          _email.text.isNotEmpty ||
          _password.text.isNotEmpty,
      footer: PrimaryButton(
        label: l.memberAccountCreate,
        onPressed: _busy ? null : _submit,
        busy: _busy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(labelText: l.memberAccountName),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(labelText: l.memberAccountEmail),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: l.memberAccountTemporaryPassword,
              helperText: l.memberAccountPasswordRule,
              suffixIcon: IconButton(
                tooltip: l.resetShow,
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l.memberAccountRole,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in _roles)
                ChoiceChip(
                  label: Text(_roleLabel(l, role)),
                  selected: _role == role,
                  onSelected: (_) => setState(() => _role = role),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l.memberAccountSecurityNote,
              style: TextStyle(fontSize: 12, color: context.inkSoft)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.danger)),
          ],
        ],
      ),
    );
  }
}
