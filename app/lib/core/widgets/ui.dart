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

/// ── Form fields ─────────────────────────────────────────────────────────────
/// The one filled, borderless field with a persistent label. [currencySymbol]
/// switches on the money keyboard (decimal) + currency prefix — the standard
/// currency input. Never re-declare InputDecoration per screen.
class MhuriField extends StatelessWidget {
  const MhuriField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.fillColor,
    this.keyboardType,
    this.obscureText = false,
    this.maxLength,
    this.prefixIcon,
    this.prefixText,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.currencySymbol,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final Color? fillColor;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLength;
  final IconData? prefixIcon;
  final String? prefixText;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  /// When set: decimal keyboard + `symbol ` prefix — the currency input.
  final String? currencySymbol;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        obscureText: obscureText,
        maxLength: maxLength,
        textCapitalization: textCapitalization,
        keyboardType: currencySymbol != null
            ? const TextInputType.numberWithOptions(decimal: true)
            : keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          prefixIcon:
              prefixIcon == null ? null : Icon(prefixIcon, color: context.inkSoft),
          prefixText: prefixText,
          filled: true,
          fillColor: fillColor ?? context.card,
          border: const OutlineInputBorder(borderSide: BorderSide.none),
        ),
      );
}

/// ── Inline error notice ─────────────────────────────────────────────────────
/// The dangerSoft box under a form. Localized, human text only.
class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: context.dangerSoft,
              borderRadius: BorderRadius.circular(12)),
          child: Text(text, style: TextStyle(color: context.expenseRed)),
        ),
      );
}

/// ── Settings / summary row ──────────────────────────────────────────────────
/// Label left, bold value right (sync statuses, settings summaries).
class SettingsRow extends StatelessWidget {
  const SettingsRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

/// ── Secondary button ────────────────────────────────────────────────────────
/// Outlined companion to [PrimaryButton]: tinted outline, optional icon.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Red outline — the destructive-secondary look (remove photo, etc.).
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tint = danger ? context.expenseRed : context.primary;
    final style = OutlinedButton.styleFrom(
      foregroundColor: tint,
      side: BorderSide(color: tint),
      minimumSize: const Size.fromHeight(44),
      shape: const StadiumBorder(),
    );
    return icon == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: Text(label))
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 18),
            label: Text(label),
          );
  }
}

/// ── Page header ─────────────────────────────────────────────────────────────
/// The 26/w800 page title every top-level screen shares.
class PageHeader extends StatelessWidget {
  const PageHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style:
            TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: context.ink),
      );
}

/// ── Member avatar ───────────────────────────────────────────────────────────
/// Photo when present, else the member's emoji icon on the role color.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.backgroundColor,
    required this.icon,
    this.imageUrl,
    this.radius = 20,
  });

  final Color backgroundColor;
  final IconData icon;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        backgroundImage:
            imageUrl != null ? NetworkImage(imageUrl!) : null,
        child: imageUrl != null ? null : Icon(icon, size: 20, color: context.ink),
      );
}

/// ── Bottom-sheet header ─────────────────────────────────────────────────────
/// Title row + labelled close — every sheet opens with this, never a bare title.
class SheetHeader extends StatelessWidget {
  const SheetHeader(this.title, {super.key, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.ink)),
          ),
          IconButton(
            tooltip:
                MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      );
}

/// The standard sheet host: drag handle, safe area, keyboard inset.
/// Every bottom sheet in the app opens through this so modal layout never
/// drifts screen-to-screen.
Future<T?> showMhuriSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollControlled = true,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: scrollControlled,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.bg,
      builder: builder,
    );
