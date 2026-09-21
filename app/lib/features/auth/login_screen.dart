import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Phone OTP login (live mode only — demo never shows this screen).
/// Two phases: phone number → verification code.
/// Launch market's code for local (leading-0) numbers.
const String kDefaultCountryCode = '263';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Normalises phone numbers to E.164 for the OTP API. Leading-0 local
  /// numbers assume the launch market's code; international (+…) passes
  /// through untouched.
  String _normalizePhone(String raw) {
    var p = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (p.startsWith('00'))
      p = '+${p.substring(2)}';
    else if (p.startsWith('0'))
      p = '+$kDefaultCountryCode${p.substring(1)}';
    else if (!p.startsWith('+')) p = '+$p';
    return p;
  }

  Future<void> _send() async {
    final phone = _normalizePhone(_phone.text);
    if (phone.length < 10) {
      setState(() => _error = AppLocalizations.of(context)!.loginBadPhone);
      return;
    }
    final ok = await widget.auth.sendCode(phone);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _codeSent = true;
        _error = null;
      });
    } else {
      setState(() => _error = widget.auth.lastError);
    }
  }

  Future<void> _verify() async {
    final phone = _normalizePhone(_phone.text);
    final ok = await widget.auth.verify(phone, _code.text);
    if (!mounted) return;
    // Success: AuthController notifies, the gate in app.dart swaps screens.
    if (!ok) setState(() => _error = widget.auth.lastError);
  }

  @override
  Widget build(BuildContext context) {
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
              _codeSent
                  ? AppLocalizations.of(context)!.loginEnterCode
                  : AppLocalizations.of(context)!.loginWelcome,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: context.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _codeSent
                  ? AppLocalizations.of(context)!
                      .loginSentCode(_normalizePhone(_phone.text))
                  : AppLocalizations.of(context)!.loginSignInHint,
              style: TextStyle(
                  fontSize: 13.5, color: context.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 24),
            if (!_codeSent) ...[
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofocus: true,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                  letterSpacing: 1,
                ),
                decoration: InputDecoration(
                  hintText: '0772 123 456',
                  filled: true,
                  fillColor: context.card,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
            ] else ...[
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                autofocus: true,
                maxLength: 6,
                obscureText: true,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '••••••',
                  counterText: '',
                  filled: true,
                  fillColor: context.card,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9E0DF),
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
                  onPressed:
                      busy ? null : () => _codeSent ? _verify() : _send(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: context.onSolid,
                    disabledBackgroundColor:
                        context.primary.withValues(alpha: 0.6),
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
                          _codeSent
                              ? AppLocalizations.of(context)!.loginVerify
                              : AppLocalizations.of(context)!.loginSendCode,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                );
              },
            ),
            if (_codeSent) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() {
                  _codeSent = false;
                  _error = null;
                  _code.clear();
                }),
                child: Text(
                  AppLocalizations.of(context)!.loginChangeNumber,
                  style: TextStyle(
                      color: context.inkSoft, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Center(
              child: Text(
                AppLocalizations.of(context)!.loginFooter,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: context.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
