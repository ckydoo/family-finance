import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Email + password login against the family's Supabase project.
/// Two modes: sign in, or create account. When Supabase has "Confirm email"
/// enabled, sign-up returns a "check your inbox" state instead of a session.
const String kDefaultCountryCode = '263'; // kept for reference — auth is
// email-based since the 2026-09 auth switch; no phone input remains.

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _createMode = false;
  bool _obscure = true;
  bool _confirmSent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _validEmail =>
      RegExp(r'^\S+@\S+\.\S+').hasMatch(_email.text.trim());

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (!_validEmail) {
      setState(() {
        _error = l.loginBadEmail;
        _confirmSent = false;
      });
      return;
    }
    if (_password.text.length < 6) {
      setState(() {
        _error = l.loginShortPassword;
        _confirmSent = false;
      });
      return;
    }
    final email = _email.text.trim();
    final ok = _createMode
        ? await widget.auth.signUp(email, _password.text)
        : await widget.auth.signIn(email, _password.text);
    if (!mounted) return;
    if (ok) {
      // Success: AuthController notifies, the gate in app.dart swaps screens.
      setState(() => _error = null);
    } else if (_createMode && widget.auth.needsConfirmation) {
      setState(() {
        _confirmSent = true;
        _createMode = false;
        _error = null;
      });
    } else {
      setState(() {
        _error = widget.auth.lastError;
        _confirmSent = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.primary, context.primaryDark],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/branding/splash.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l.loginWelcome,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: context.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.loginSignInHint,
              style: TextStyle(fontSize: 13.5, color: context.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 24),

            // Sign in / Create account switch — one screen, both modes.
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(l.loginSignIn),
                  icon: const Icon(Icons.login_rounded, size: 18),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(l.loginCreateAccount),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                ),
              ],
              selected: {_createMode},
              onSelectionChanged: (s) => setState(() {
                _createMode = s.first;
                _error = null;
                _confirmSent = false;
              }),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 16),

            if (_confirmSent) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read_outlined,
                        size: 18, color: context.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.checkYourEmail,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: context.ink,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                      letterSpacing: 0.3,
                    ),
                    decoration: InputDecoration(
                      labelText: l.emailLabel,
                      hintText: 'you@example.com',
                      prefixIcon:
                          Icon(Icons.mail_outline, color: context.inkSoft),
                      filled: true,
                      fillColor: context.card,
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: [
                      _createMode ? AutofillHints.newPassword : AutofillHints.password
                    ],
                    onSubmitted: (_) => _submit(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                      letterSpacing: 1,
                    ),
                    decoration: InputDecoration(
                      labelText: l.passwordLabel,
                      prefixIcon:
                          Icon(Icons.lock_outline, color: context.inkSoft),
                      suffixIcon: IconButton(
                        tooltip: l.togglePassword,
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: context.inkSoft,
                        ),
                      ),
                      filled: true,
                      fillColor: context.card,
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.dangerSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(fontSize: 12.5, color: context.expenseRed),
                ),
              ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: widget.auth,
              builder: (context, _) {
                final busy = widget.auth.busy;
                return ElevatedButton(
                  onPressed: busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: context.onSolid,
                    disabledBackgroundColor: context.primary.withValues(alpha: 0.6),
                    minimumSize: const Size.fromHeight(54),
                    shape: const StadiumBorder(),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _createMode ? l.loginCreateAccount : l.loginSignIn,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
