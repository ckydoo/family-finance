import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../l10n/generated/app_localizations.dart';

/// Create-new-password — the last step of password recovery.
///
/// The app got here by opening the reset link (mhuri://reset-callback), which
/// carried a recovery session. This screen picks the new password, PUTs it to
/// GoTrue, signs the user out (the recovery session is single-purpose) and
/// lands on sign-in with a clear confirmation.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.auth,
    this.email,
    this.startExpired = false,
  });

  final AuthController auth;
  final String? email;
  final bool startExpired;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _busy = false;
  bool _expired = false;
  bool _sending = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _expired = widget.startExpired;
  }

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _hasLength => _new.text.length >= 8;
  bool get _hasMix => _new.text.contains(RegExp(r'[A-Za-z]')) &&
      _new.text.contains(RegExp(r'[0-9]'));

  String? _validate(AppLocalizations l) {
    if (!_hasLength || !_hasMix) return l.resetRuleHint;
    if (_new.text != _confirm.text) return l.resetMismatch;
    return null;
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final err = _validate(l);
    if (err != null) {
      setState(() => _inlineError = err);
      return;
    }
    setState(() {
      _busy = true;
      _inlineError = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final r = await widget.auth.updatePassword(_new.text);
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _busy = false;
        // A dead recovery session (single-use link already used / too old)
        // switches the screen to the honest "send a new link" state.
        if (r.code == 'reset_expired') {
          _expired = true;
          _inlineError = null;
        } else {
          _inlineError = r.error;
        }
      });
      return;
    }
    // Success: the recovery session ends here — back to sign-in.
    await widget.auth.signOut();
    if (!mounted) return;
    navigator.popUntil((route) => route.isFirst);
    messenger.showSnackBar(SnackBar(
      content: Text(l.resetSuccess),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _sendNewLink() async {
    final l = AppLocalizations.of(context)!;
    final email = widget.email;
    if (email == null || email.isEmpty) {
      setState(() => _inlineError = l.resetExpiredBody);
      return;
    }
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final sent = await widget.auth.sendPasswordReset(email);
    if (!mounted) return;
    navigator.popUntil((route) => route.isFirst);
    messenger.showSnackBar(SnackBar(
      content: Text(sent ? l.passwordResetSent : l.passwordResetFailed),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.resetTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            if (_expired) ...[
              Icon(Icons.schedule, size: 44, color: context.primary),
              const SizedBox(height: 12),
              Text(l.resetExpiredTitle,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(l.resetExpiredBody,
                  style: TextStyle(fontSize: 14, color: context.inkSoft),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _sending ? null : _sendNewLink,
                child: Text(l.resetSendNew),
              ),
            ] else ...[
              if (widget.email != null && widget.email!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(widget.email!,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: context.inkSoft)),
                ),
              Text(l.resetSubtitle,
                  style: TextStyle(fontSize: 14, color: context.inkSoft)),
              const SizedBox(height: 16),
              TextField(
                controller: _new,
                obscureText: _obscureNew,
                autofillHints: const [AutofillHints.newPassword],
                enableSuggestions: false,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l.resetNewLabel,
                  errorText: _inlineError,
                  suffixIcon: IconButton(
                    tooltip: l.resetShow,
                    icon: Icon(_obscureNew
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _rule(l.resetRuleLength, _hasLength),
              _rule(l.resetRuleMix, _hasMix),
              const SizedBox(height: 16),
              TextField(
                controller: _confirm,
                obscureText: _obscureConfirm,
                autofillHints: const [AutofillHints.newPassword],
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l.resetConfirmLabel,
                  suffixIcon: IconButton(
                    tooltip: l.resetShow,
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.resetCta),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rule(String text, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: ok ? Colors.green : context.inkSoft,
            ),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(fontSize: 12.5, color: context.ink)),
          ],
        ),
      );
}
