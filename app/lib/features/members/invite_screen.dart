import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/sync/supabase_sync_client.dart';
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
  String? _newCode;
  List<InviteInfo>? _invites;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String _roleLabel(AppLocalizations l, String role) =>
      switch (role) {
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
      setState(() =>
          _error = AppLocalizations.of(context)!.invitesLoadFailed);
    }
  }

  Future<void> _create() async {
    final l = AppLocalizations.of(context)!;
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
        title: 'Mhuri Hub',
      ),
    );
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
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
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
                        style: TextStyle(
                            fontSize: 12.5, color: context.inkSoft)),
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
                          onPressed: () => _share(InviteInfo(
                              id: '', code: _newCode!, role: _role)),
                          icon: const Icon(Icons.share, size: 16),
                          label: Text(l.inviteShare),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

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
                child: Center(child: CircularProgressIndicator()),
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
                      ? Text(inv.email!,
                          style: const TextStyle(fontSize: 12))
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
                        decoration:
                            inv.revokedAt != null
                                ? TextDecoration.lineThrough
                                : null),
                  ),
                ),
            ],
            if (s.user.role != Role.owner)
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
