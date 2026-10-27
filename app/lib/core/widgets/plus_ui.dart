import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared presentation for Mhuri Plus surfaces. Premium features keep the
/// product's established slate/champagne palette and spacing instead of
/// introducing a separate visual language.
class PlusHero extends StatelessWidget {
  const PlusHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.icon = Icons.auto_awesome_rounded,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.primary,
          borderRadius: BorderRadius.circular(kRadiusSheet),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.accent,
                    borderRadius: kBRadiusL,
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: kSpace12),
                Expanded(
                  child: Text(
                    eyebrow.toUpperCase(),
                    style: MhuriType.caption.copyWith(
                      color: context.accent,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: kSpace16),
            Text(
              title,
              style: MhuriType.titleL.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: kSpace8),
            Text(
              description,
              style: MhuriType.body.copyWith(
                color: Colors.white.withValues(alpha: .78),
              ),
            ),
          ],
        ),
      );
}

class PlusSectionCard extends StatelessWidget {
  const PlusSectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.action,
    this.padding = const EdgeInsets.all(kSpace16),
  });

  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: context.card,
        shape: RoundedRectangleBorder(
          borderRadius: kBRadiusL,
          side: BorderSide(color: context.hairline),
        ),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: context.accentSoft,
                          borderRadius: kBRadiusM,
                        ),
                        child: Icon(icon, size: 19, color: context.accentDark),
                      ),
                      const SizedBox(width: kSpace12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title!,
                              style: MhuriType.titleM
                                  .copyWith(color: context.ink)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(subtitle!,
                                style: MhuriType.caption
                                    .copyWith(color: context.inkSoft)),
                          ],
                        ],
                      ),
                    ),
                    if (action != null) action!,
                  ],
                ),
                const SizedBox(height: kSpace16),
              ],
              child,
            ],
          ),
        ),
      );
}

class PlusEmptyState extends StatelessWidget {
  const PlusEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => PlusSectionCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: kSpace16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: context.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: context.primary),
                  ),
                  const SizedBox(height: kSpace12),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: MhuriType.titleM.copyWith(color: context.ink)),
                  const SizedBox(height: kSpace4),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: MhuriType.body.copyWith(color: context.inkSoft)),
                  if (action != null) ...[
                    const SizedBox(height: kSpace16),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

class PlusInlineMessage extends StatelessWidget {
  const PlusInlineMessage({
    super.key,
    required this.message,
    this.isError = false,
    this.onRetry,
  });

  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(kSpace12),
        decoration: BoxDecoration(
          color: isError ? context.dangerSoft : context.infoSoft,
          borderRadius: kBRadiusM,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.wifi_off_rounded : Icons.info_outline_rounded,
              size: 20,
              color: isError ? context.danger : context.information,
            ),
            const SizedBox(width: kSpace8),
            Expanded(
                child: Text(message,
                    style: MhuriType.caption.copyWith(color: context.ink))),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
}

String friendlyPlusError(Object error) {
  final raw = error.toString();
  if (raw.contains('SocketFailed') ||
      raw.contains('Failed host lookup') ||
      raw.contains('SocketException') ||
      raw.contains('ClientException')) {
    return 'We could not connect right now. Check your internet connection and try again.';
  }
  if (raw.contains('PLUS_FEATURE_REQUIRED')) {
    return 'Mhuri Plus needs to be active for this family.';
  }
  if (raw.contains('FAMILY_ACCESS_DENIED')) {
    return 'You no longer have access to this family.';
  }
  return 'Something went wrong. Please try again.';
}
