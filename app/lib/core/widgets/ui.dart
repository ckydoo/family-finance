import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// ── Mhuri shared component kit (Phase 3) ────────────────────────────────────
/// One source of truth for the recurring shapes: cards, section headers,
/// primary buttons, empty hints. Screens compose these instead of re-declaring
/// radius/padding/weights - the design system from PRODUCT_SPEC §7 without a
/// theme package. Adopt a screen at a time; new code MUST use these.

/// The standard rounded content card (was: per-screen Container + BoxDecoration).
class MhuriCard extends StatelessWidget {
  const MhuriCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.highlight = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Draws the primary-colored border (selection / fresh-result emphasis).
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = highlight
        ? BorderSide(color: context.primary, width: 1.5)
        : BorderSide.none;
    return Material(
      color: context.card,
      shape: RoundedRectangleBorder(
        borderRadius: kBRadiusL,
        side: highlight ? border : BorderSide(color: context.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Section header inside a settings-style page. Typography carries the
/// hierarchy; optional icons are accepted for compatibility but omitted.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.inkSoft,
            letterSpacing: 0.2,
          ),
        ),
      );
}

/// A clean section header with optional trailing action (e.g. "See all").
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(top: 20, bottom: 8),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.ink,
              letterSpacing: -0.2,
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A clean, flat list row (title, subtitle, leading, trailing, optional divider).
/// Replaces oversized cards with high information density and low visual noise.
class MhuriListRow extends StatelessWidget {
  const MhuriListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  subtitle!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: kBRadiusS,
        child: content,
      );
    }

    if (!showDivider) return content;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        Divider(
          height: 1,
          thickness: 1,
          color: context.hairline.withValues(alpha: 0.6),
        ),
      ],
    );
  }
}

/// A restrained progress bar with consistent height and radius.
class MhuriProgress extends StatelessWidget {
  const MhuriProgress({
    super.key,
    required this.progress,
    this.color,
    this.trackColor,
    this.height = 5.0,
    this.radius = 4.0,
  });

  final double progress;
  final Color? color;
  final Color? trackColor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: height,
        color: trackColor ?? context.track,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: clamped,
          child: Container(
            color: color ?? context.primary,
          ),
        ),
      ),
    );
  }
}

/// The single full-width call-to-action.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.danger = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool danger;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: danger ? context.danger : context.primary,
          foregroundColor: context.onSolid,
          disabledBackgroundColor: danger ? context.dangerSoft : context.track,
          disabledForegroundColor: context.inkFaint,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2.5))
            : icon != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                      Text(label,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  )
                : Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
      );
}

/// Centered hint inside a card for empty/error states.
class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(body),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: danger,
            isDefaultAction: !danger,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
                confirmLabel ?? MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
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
          child:
              Text(confirmLabel ?? MaterialLocalizations.of(ctx).okButtonLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Prevents typing or pasting any non-numeric characters into amounts (allows digits and up to 2 decimal places).
List<TextInputFormatter> get amountInputFormatters => [
      // 12 major-unit digits plus decimal point and cents. This stays far
      // inside SQLite's signed 64-bit integer range after conversion to minor
      // units, while still supporting amounts up to 999,999,999,999.99.
      LengthLimitingTextInputFormatter(15),
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
    ];

/// Prevents typing or pasting any non-numeric characters into integer fields (e.g. quantity).
List<TextInputFormatter> get integerInputFormatters => [
      // Quantities are capped to three digits so quantity x the largest
      // accepted unit price remains safely inside the database integer range.
      LengthLimitingTextInputFormatter(3),
      FilteringTextInputFormatter.digitsOnly,
    ];

/// Numeric 4–6 digit PIN input. Kept separate from quantity formatters,
/// which intentionally stop at three digits.
List<TextInputFormatter> get pinInputFormatters => [
      LengthLimitingTextInputFormatter(6),
      FilteringTextInputFormatter.digitsOnly,
    ];

/// ── Form fields ─────────────────────────────────────────────────────────────
/// The one filled, borderless field with a persistent label. [currencySymbol]
/// switches on the money keyboard (decimal) + currency prefix - the standard
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
    this.errorText,
    this.inputFormatters,
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
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;

  /// When set: decimal keyboard + `symbol ` prefix - the currency input.
  final String? currencySymbol;

  @override
  Widget build(BuildContext context) {
    final effectiveFormatters = inputFormatters ??
        (currencySymbol != null ||
                keyboardType ==
                    const TextInputType.numberWithOptions(decimal: true)
            ? amountInputFormatters
            : (keyboardType == TextInputType.number
                ? integerInputFormatters
                : null));

    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      obscureText: obscureText,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      keyboardType: currencySymbol != null
          ? const TextInputType.numberWithOptions(decimal: true)
          : keyboardType,
      inputFormatters: effectiveFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: context.inkSoft),
        prefixText: prefixText,
        errorText: errorText,
        errorStyle: TextStyle(
          color: context.danger,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: fillColor ?? context.card,
        border: const OutlineInputBorder(borderSide: BorderSide.none),
      ),
    );
  }
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.dangerSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.danger),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 18, color: context.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: context.expenseRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
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

  /// Red outline - the destructive-secondary look (remove photo, etc.).
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tint = danger ? context.expenseRed : context.primary;
    final style = OutlinedButton.styleFrom(
      foregroundColor: tint,
      side: BorderSide(color: tint),
      minimumSize: const Size.fromHeight(44),
      shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
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
/// Restrained top-level page title.
class PageHeader extends StatelessWidget {
  const PageHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, color: context.ink),
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
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
        child:
            imageUrl != null ? null : Icon(icon, size: 20, color: context.ink),
      );
}

/// ── Bottom-sheet header ─────────────────────────────────────────────────────
/// Title row + labelled close - every sheet opens with this, never a bare title.
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
                    fontWeight: FontWeight.w700,
                    color: context.ink)),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      );
}

/// ── Status banner ──────────────────────────────────────────────────────────
/// Consistent notification / alert bar for sync health, warnings, overspend policies.
enum BannerType { info, warning, error, success }

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.title,
    this.type = BannerType.info,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final BannerType type;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (type) {
      BannerType.info => (
          context.card,
          context.ink,
          Icons.info_outline_rounded
        ),
      BannerType.warning => (
          context.warningSoft,
          context.ink,
          Icons.warning_amber_rounded
        ),
      BannerType.error => (
          context.dangerSoft,
          context.expenseRed,
          Icons.error_outline_rounded
        ),
      BannerType.success => (
          context.primarySoft,
          context.primaryDark,
          Icons.check_circle_outline_rounded
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13, color: fg),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(message, style: TextStyle(fontSize: 12.5, color: fg)),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(48, 36),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ── Money card ─────────────────────────────────────────────────────────────
/// Prominent financial summary card (balance, envelope, pool, or goal).
class MoneyCard extends StatelessWidget {
  const MoneyCard({
    super.key,
    required this.title,
    required this.amount,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.highlight = false,
  });

  final String title;
  final String amount;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => MhuriCard(
        highlight: highlight,
        onTap: onTap,
        child: Row(
          children: [
            if (icon != null) ...[
              SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, color: context.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 12, color: context.inkSoft),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// ── Modal Bottom Sheet Shell ───────────────────────────────────────────────
/// Standardizes header, close button, progressive disclosure scrolling,
/// keyboard awareness, max height constraints, and unsaved changes confirmation.
class MhuriSheetShell extends StatelessWidget {
  const MhuriSheetShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.onClose,
    this.footer,
    this.isDirty = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onClose;
  final Widget? footer;
  final bool isDirty;

  Future<bool> _handleClose(BuildContext context) async {
    if (isDirty) {
      final discard = await confirmDialog(
        context,
        title: 'Discard changes?',
        body: 'You have unsaved changes that will be lost.',
        confirmLabel: 'Discard',
        danger: true,
      );
      if (!discard) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.90;
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _handleClose(context);
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: context.ink,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                  fontSize: 12.5, color: context.inkSoft),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () async {
                        if (onClose != null) {
                          onClose!();
                        } else {
                          final ok = await _handleClose(context);
                          if (ok && context.mounted) Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: child,
                ),
              ),
              if (footer != null) ...[
                const Divider(height: 1),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 4),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: footer!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The standard sheet host: drag handle, safe area, keyboard inset.
/// Every bottom sheet in the app opens through this so modal layout never
/// drifts screen-to-screen.
Future<T?> showMhuriSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool scrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: scrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: builder,
    );
