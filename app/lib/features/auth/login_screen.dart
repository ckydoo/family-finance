import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../legal/legal_screen.dart';

/// Email + password login against the family's Supabase project.
/// Two modes: sign in, or create account. When Supabase has "Confirm email"
/// enabled, sign-up returns a "check your inbox" state instead of a session.
const String kDefaultCountryCode = '263'; // kept for reference - auth is
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

  Future<void> _signInWithGoogle() async {
    final opened = await launchUrl(
      widget.auth.googleSignInUri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Could not open Google sign-in. Please try again.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Server/auth failures mapped to honest, specific copy - never a riddle.
  String _mappedError(AppLocalizations l) => switch (_errorCode) {
        'email_not_confirmed' => l.authErrEmailNotConfirmed,
        'invalid_credentials' => l.authErrBadCredentials,
        'already_registered' => l.authErrAlreadyRegistered,
        'rate_limited' => l.authErrRateLimited,
        'network' => _error ?? l.authErrNetwork,
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
          borderRadius: kBRadiusM,
          borderSide: BorderSide(color: color, width: width),
        );

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: defaultTargetPlatform == TargetPlatform.iOS
                      ? const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics())
                      : const ClampingScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        maxWidth: 460,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      borderRadius: kBRadiusL,
                                      border:
                                          Border.all(color: context.hairline),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: kBRadiusM,
                                      child: Image.asset(
                                        'assets/branding/app_icon.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Mhuri',
                                    style: TextStyle(
                                      color: context.ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
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
                              const SizedBox(height: 18),
                              Text(
                                _confirmSent
                                    ? l.checkYourEmail
                                    : (_createMode
                                        ? l.createAccountTitle
                                        : l.welcomeBack),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  color: context.ink,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _confirmSent
                                    ? 'We sent a verification link to ${_email.text.trim()}.'
                                    : (_createMode
                                        ? l.createAccountHint
                                        : l.loginSignInHint),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  color: context.inkSoft,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Container(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    if (_confirmSent) ...[
                                      SizedBox(
                                        width: 64,
                                        height: 64,
                                        child: Icon(
                                            Icons.mark_email_read_rounded,
                                            size: 34,
                                            color: context.primary),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Tap the link in your email to activate your account, then sign in below.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: context.inkSoft,
                                          height: 1.45,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      if (_error != null) ...[
                                        _AuthNotice(
                                          icon: Icons.error_outline_rounded,
                                          text: _mappedError(l),
                                          danger: true,
                                        ),
                                        const SizedBox(height: 12),
                                      ],
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
                                              minimumSize:
                                                  const Size.fromHeight(52),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: kBRadiusM,
                                              ),
                                            ),
                                            child: busy
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator
                                                            .adaptive(
                                                      strokeWidth: 2.2,
                                                    ),
                                                  )
                                                : const Text(
                                                    "I've confirmed my email",
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        icon: _busySendResend
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator
                                                    .adaptive(strokeWidth: 2),
                                              )
                                            : const Icon(Icons.refresh_rounded,
                                                size: 17),
                                        onPressed: _busySendResend
                                            ? null
                                            : () async {
                                                final messenger =
                                                    ScaffoldMessenger.of(
                                                        context);
                                                setState(() =>
                                                    _busySendResend = true);
                                                final ok = await widget.auth
                                                    .resendConfirmation(
                                                        _email.text.trim());
                                                if (!mounted) return;
                                                setState(() {
                                                  _busySendResend = false;
                                                  _resent = ok;
                                                });
                                                if (ok) {
                                                  messenger
                                                      .showSnackBar(SnackBar(
                                                    content: Text(l.authResent),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  ));
                                                }
                                              },
                                        style: OutlinedButton.styleFrom(
                                          minimumSize:
                                              const Size.fromHeight(48),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: kBRadiusM),
                                          side: BorderSide(
                                              color: context.hairline),
                                        ),
                                        label: Text(l.authResend),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () => setState(() {
                                          _confirmSent = false;
                                          _createMode = true;
                                          _error = null;
                                          _errorCode = null;
                                        }),
                                        child: Text(
                                          'Wrong email address? Change email',
                                          style: TextStyle(
                                            color: context.primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      AutofillGroup(
                                        child: Column(
                                          children: [
                                            TextField(
                                              controller: _email,
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              autofillHints: const [
                                                AutofillHints.email
                                              ],
                                              autofocus: true,
                                              textInputAction:
                                                  TextInputAction.next,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: context.ink,
                                              ),
                                              decoration: InputDecoration(
                                                labelText: l.emailLabel,
                                                hintText: 'you@example.com',
                                                prefixIcon: Icon(
                                                    Icons.mail_outline_rounded,
                                                    color: context.inkSoft),
                                                filled: true,
                                                fillColor: context.bg,
                                                border: fieldBorder(
                                                    context.hairline),
                                                enabledBorder: fieldBorder(
                                                    context.hairline),
                                                focusedBorder: fieldBorder(
                                                    context.primary, 1.6),
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
                                                prefixIcon: Icon(
                                                    Icons.lock_outline_rounded,
                                                    color: context.inkSoft),
                                                suffixIcon: IconButton(
                                                  tooltip: l.togglePassword,
                                                  onPressed: () => setState(
                                                      () =>
                                                          _obscure = !_obscure),
                                                  icon: Icon(
                                                    _obscure
                                                        ? Icons
                                                            .visibility_outlined
                                                        : Icons
                                                            .visibility_off_outlined,
                                                    color: context.inkSoft,
                                                  ),
                                                ),
                                                filled: true,
                                                fillColor: context.bg,
                                                border: fieldBorder(
                                                    context.hairline),
                                                enabledBorder: fieldBorder(
                                                    context.hairline),
                                                focusedBorder: fieldBorder(
                                                    context.primary, 1.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!_createMode)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: _busyReset
                                                ? null
                                                : _resetPassword,
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
                                          _resent)
                                        TextButton.icon(
                                          icon: const Icon(
                                              Icons.refresh_rounded,
                                              size: 17),
                                          onPressed: _busySendResend
                                              ? null
                                              : () async {
                                                  final messenger =
                                                      ScaffoldMessenger.of(
                                                          context);
                                                  setState(() =>
                                                      _busySendResend = true);
                                                  final ok = await widget.auth
                                                      .resendConfirmation(
                                                          _email.text.trim());
                                                  if (!mounted) return;
                                                  setState(() {
                                                    _busySendResend = false;
                                                    _resent = ok;
                                                  });
                                                  if (ok) {
                                                    messenger
                                                        .showSnackBar(SnackBar(
                                                      content:
                                                          Text(l.authResent),
                                                      behavior: SnackBarBehavior
                                                          .floating,
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
                                                  context.track,
                                              minimumSize:
                                                  const Size.fromHeight(50),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: kBRadiusM,
                                              ),
                                            ),
                                            child: busy
                                                ? const SizedBox(
                                                    width: 21,
                                                    height: 21,
                                                    child:
                                                        CircularProgressIndicator
                                                            .adaptive(
                                                      strokeWidth: 2.4,
                                                    ),
                                                  )
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        _createMode
                                                            ? l.loginCreateAccount
                                                            : l.loginSignIn,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Icon(
                                                          Icons
                                                              .arrow_forward_rounded,
                                                          size: 19),
                                                    ],
                                                  ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 22),
                                      const _OrDivider(),
                                      const SizedBox(height: 16),
                                      _SocialAuthButton(
                                        provider: 'Google',
                                        action: _createMode
                                            ? 'Sign up with'
                                            : 'Continue with',
                                        mark: const FaIcon(
                                          FontAwesomeIcons.google,
                                          size: 20,
                                          color: Color(0xFF4285F4),
                                        ),
                                        onPressed: _signInWithGoogle,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (_confirmSent)
                                Center(
                                  child: TextButton(
                                    onPressed: () => setState(() {
                                      _confirmSent = false;
                                      _createMode = false;
                                      _error = null;
                                      _errorCode = null;
                                    }),
                                    child: Text(
                                      'Back to sign in',
                                      style: TextStyle(
                                        color: context.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      _createMode
                                          ? l.alreadyHaveAccount
                                          : l.newToMhuri,
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
                                        _createMode
                                            ? l.loginSignIn
                                            : l.loginCreateAccount,
                                        style: TextStyle(
                                          color: context.primary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              const Spacer(),
                              const SizedBox(height: 20),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'By continuing, you agree to our ',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: context.inkSoft,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const LegalScreen(
                                            initialSection: LegalSection.terms,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Terms of Service',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: context.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      ' & ',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: context.inkSoft,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const LegalScreen(
                                            initialSection:
                                                LegalSection.privacy,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Privacy Policy',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: context.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
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
          borderRadius: kBRadiusM,
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Divider(color: context.hairline, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'OR',
              style: TextStyle(
                color: context.inkSoft,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Expanded(child: Divider(color: context.hairline, height: 1)),
        ],
      );
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.provider,
    required this.action,
    required this.mark,
    required this.onPressed,
  });

  final String provider;
  final String action;
  final Widget mark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$action $provider',
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: context.ink,
            backgroundColor: context.card,
            minimumSize: const Size.fromHeight(50),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            side: BorderSide(color: context.hairline),
            shape: RoundedRectangleBorder(
              borderRadius: kBRadiusM,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(alignment: Alignment.centerLeft, child: mark),
              Text(
                '$action $provider',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}
