import 'package:flutter/material.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// First-run onboarding (M4, live mode only — demo never shows it).
/// Four calm slides (app.dart gates on live + logged-in + first run), then
/// straight into the app; the family space is set up from the Family tab
/// (create / join with the partner's code).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});

  final AppState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  // Slide copy lives in the ARB translations (ob1/ob2/ob3); only the icons
  // live here.
  static const _slideIcons = <IconData>[
    Icons.diversity_3,
    Icons.mail_outline,
    Icons.handshake,
    Icons.notifications_active,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slideIcons.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      widget.state.completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Column(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/branding/splash.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.state.completeOnboarding,
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, 48), // 48dp tap target (a11y)
                ),
                child: Text(
                  AppLocalizations.of(context)!.skip,
                  style: TextStyle(
                    color: context.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slideIcons.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final l10 = AppLocalizations.of(context)!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [context.primary, context.primaryDark],
                            ),
                            borderRadius: BorderRadius.circular(32),
                            // Same soft elevation pattern as the Pool card.
                            boxShadow: [
                              BoxShadow(
                                color: context.primary.withValues(alpha: 0.28),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Icon(_slideIcons[i], size: 52, color: Colors.white),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          [l10.ob1Title, l10.ob2Title, l10.ob3Title, l10.ob4Title][i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: context.ink,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          [l10.ob1Body, l10.ob2Body, l10.ob3Body, l10.ob4Body][i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: context.inkSoft,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slideIcons.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          width: i == _page ? 22 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: i == _page ? context.primary : context.track,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.primary,
                      foregroundColor: context.onSolid,
                      minimumSize: const Size.fromHeight(54),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      _page == _slideIcons.length - 1
                          ? AppLocalizations.of(context)!.obDone
                          : AppLocalizations.of(context)!.next,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      AppLocalizations.of(context)!.nextCreateSpace,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: context.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
