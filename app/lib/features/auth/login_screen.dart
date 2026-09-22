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

  String? _errorCode;
  bool _resent = false;
  bool _busySendResend = false;
  bool _busyReset = false;

  Future<void> _resetPassword() async {
    final l = AppLocalizations.of(context)!;
    final email = _email.text.trim();
    if (!_validEmail) {
      setState(() => _error = l.loginBadEmail);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busyReset = true;
      _error = null;
    });
    final sent = await widget.auth.sendPasswordReset(email);
    if (!mounted) return;
    setState(() => _busyReset = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(sent ? l.passwordResetSent : l.passwordResetFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Server/auth failures mapped to honest, specific copy — never a riddle.
  String _mappedError(AppLocalizations l) => switch (_errorCode) {
        'email_not_confirmed' => l.authErrEmailNotConfirmed,
        'invalid_credentials' => l.authErrBadCredentials,
        'already_registered' => l.authErrAlreadyRegistered,
        'rate_limited' => l.authErrRateLimited,
        'network' => l.authErrNetwork,
        _ => _error ?? '',
      };

  bool get _validEmail => RegExp(r'^\S+@\S+\.\S+').hasMatch(_email.text.trim());

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
      setState(() {
        _error = null;
        _errorCode = null;
      });
    } else if (_createMode && widget.auth.needsConfirmation) {
      setState(() {
        _confirmSent = true;
        _createMode = false;
        _error = null;
        _errorCode = null;
        _resent = false;
      });
    } else {
      setState(() {
        _error = widget.auth.lastError;
        _errorCode = widget.auth.lastErrorCode;
        _confirmSent = false;
        _resent = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -85,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.primarySoft.withValues(alpha: 0.62),
                ),
              ),
            ),
            Positioned(
              bottom: -75,
              left: -110,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.accentSoft.withValues(alpha: 0.55),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: context.cardShadow,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              'assets/branding/app_icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mhuri Hub',
                              style: TextStyle(
                                color: context.ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              l.brandTagline,
                              style: TextStyle(
                                color: context.primary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 44),
                    Text(
                      _createMode ? l.createAccountTitle : l.welcomeBack,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9,
                        color: context.ink,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _createMode ? l.createAccountHint : l.loginSignInHint,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: context.inkSoft,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: context.hairline),
                        boxShadow: context.cardShadow,
                      ),
                      child: Column(
                        children: [
                          if (_confirmSent) ...[
                            _AuthNotice(
                              icon: Icons.mark_email_read_outlined,
                              text: l.checkYourEmail,
                            ),
                            const SizedBox(height: 16),
                          ],
                          AutofillGroup(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  autofocus: true,
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: context.ink,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: l.emailLabel,
                                    hintText: 'you@example.com',
                                    prefixIcon: Icon(Icons.mail_outline_rounded,
                                        color: context.inkSoft),
                                    filled: true,
                                    fillColor: context.bg,
                                    border: fieldBorder(context.hairline),
                                    enabledBorder:
                                        fieldBorder(context.hairline),
                                    focusedBorder:
                                        fieldBorder(context.primary, 1.6),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  autofillHints: [
                                    _createMode
                                        ? AutofillHints.newPassword
                                        : AutofillHints.password,
                                  ],
                                  onSubmitted: (_) => _submit(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: context.ink,
                                    letterSpacing: 0.8,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: l.passwordLabel,
                                    prefixIcon: Icon(Icons.lock_outline_rounded,
                                        color: context.inkSoft),
                                    suffixIcon: IconButton(
                                      tooltip: l.togglePassword,
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: context.inkSoft,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: context.bg,
                                    border: fieldBorder(context.hairline),
                                    enabledBorder:
                                        fieldBorder(context.hairline),
                                    focusedBorder:
                                        fieldBorder(context.primary, 1.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_createMode)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busyReset ? null : _resetPassword,
                                child: Text(
                                  _busyReset
                                      ? l.sendingPasswordReset
                                      : l.forgotPassword,
                                  style: TextStyle(
                                    color: context.primary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 14),
                          if (_error != null) ...[
                            _AuthNotice(
                              icon: Icons.error_outline_rounded,
                              text: _mappedError(l),
                              danger: true,
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_errorCode == 'email_not_confirmed' ||
                              _confirmSent ||
                              _resent)
                            TextButton.icon(
                              icon: const Icon(Icons.refresh_rounded, size: 17),
                              onPressed: _busySendResend
                                  ? null
                                  : () async {
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      setState(() => _busySendResend = true);
                                      final ok = await widget.auth
                                          .resendConfirmation(
                                              _email.text.trim());
                                      if (!mounted) return;
                                      setState(() {
                                        _busySendResend = false;
                                        _resent = ok;
                                      });
                                      if (ok) {
                                        messenger.showSnackBar(SnackBar(
                                          content: Text(l.authResent),
                                          behavior: SnackBarBehavior.floating,
                                        ));
                                      }
                                    },
                              label: Text(l.authResend),
                            ),
                          const SizedBox(height: 8),
                          AnimatedBuilder(
                            animation: widget.auth,
                            builder: (context, _) {
                              final busy = widget.auth.busy;
                              return ElevatedButton(
                                onPressed: busy ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: context.primary,
                                  foregroundColor: context.onSolid,
                                  disabledBackgroundColor:
                                      context.primary.withValues(alpha: 0.55),
                                  minimumSize: const Size.fromHeight(56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                ),
                                child: busy
                                    ? const SizedBox(
                                        width: 21,
                                        height: 21,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.4,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _createMode
                                                ? l.loginCreateAccount
                                                : l.loginSignIn,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 19),
                                        ],
                                      ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _createMode ? l.alreadyHaveAccount : l.newToMhuri,
                          style: TextStyle(
                            color: context.inkSoft,
                            fontSize: 13,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _createMode = !_createMode;
                            _error = null;
                            _errorCode = null;
                            _confirmSent = false;
                          }),
                          child: Text(
                            _createMode ? l.loginSignIn : l.loginCreateAccount,
                            style: TextStyle(
                              color: context.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthNotice extends StatelessWidget {
  const _AuthNotice({
    required this.icon,
    required this.text,
    this.danger = false,
  });

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: danger ? context.dangerSoft : context.primarySoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18, color: danger ? context.expenseRed : context.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: danger ? context.expenseRed : context.ink,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}
