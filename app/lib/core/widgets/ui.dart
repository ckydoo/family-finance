import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ── Mhuri shared component kit (Phase 3) ────────────────────────────────────
/// One source of truth for the recurring shapes: cards, section headers,
/// primary buttons, empty hints. Screens compose these instead of re-declaring
/// radius/padding/weights — the design system from PRODUCT_SPEC §7 without a
/// theme package. Adopt a screen at a time; new code MUST use these.

/// The standard rounded content card (was: per-screen Container + BoxDecoration).
class MhuriCard extends StatelessWidget {
  const MhuriCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Draws the primary-colored border (selection / fresh-result emphasis).
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: highlight
              ? Border.all(color: context.primary, width: 1.5)
              : null,
        ),
        child: child,
      );
}

/// Section header inside a settings-style page (icon + label).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: context.primaryDark),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: context.inkSoft,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
}

/// The single full-width call-to-action (stadium, 54 high, busy spinner).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool danger;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              danger ? context.danger : context.primary,
          foregroundColor: context.onSolid,
          disabledBackgroundColor:
              (danger ? context.danger : context.primary)
                  .withValues(alpha: 0.5),
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Text(label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );
}

/// Centered hint inside a card for empty/error states.
class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 28, color: context.inkSoft),
                const SizedBox(height: 8),
              ],
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.inkSoft),
              ),
            ],
          ),
        ),
      );
}


/// The one confirm dialog (destructive / leave-without-saving).
/// Resolves true when the user confirms.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String? confirmLabel,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel ??
              MaterialLocalizations.of(ctx).okButtonLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
