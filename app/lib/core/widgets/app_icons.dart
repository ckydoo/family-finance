/// M8 polish — icon system. Every visual entity (envelope, goal, account,
/// member, recurring rule) carries a stable SEMANTIC icon key in the data
/// layer: 'cart', 'school', 'fuel', 'man', 'bank', 'autorenew', … No emojis
/// exist in the database or the UI. This map is the single place that turns
/// a key into a Material icon; unknown keys (future/remote data) fall back
/// to a neutral icon, never blank, never a raw emoji.
///
/// Notification text (reminders.dart) is the one intentional emoji zone —
/// it renders in the OS tray, outside the app, where IconData cannot.
library;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';


/// Semantic icon keys → Material icons.
const Map<String, IconData> kKeyIcons = {
  // members
  'man': Icons.man,
  'woman': Icons.woman,
  'boy': Icons.child_care,
  'baby': Icons.child_friendly,
  'student': Icons.school,
  'grandma': Icons.elderly,
  'person': Icons.person,
  // accounts
  'bank': Icons.account_balance,
  'cash': Icons.payments,
  'wallet': Icons.phone_android,
  // envelopes & recurring
  'cart': Icons.shopping_cart,
  'school': Icons.school,
  'fuel': Icons.local_gas_station,
  'power': Icons.bolt,
  'airtime': Icons.smartphone,
  'stars': Icons.star,
  'lifebuoy': Icons.support,
  'giving': Icons.volunteer_activism,
  'home': Icons.home,
  'lightbulb': Icons.lightbulb,
  'health': Icons.medication,
  'car': Icons.directions_car,
  'water': Icons.water_drop,
  // goals
  'beach': Icons.beach_access,
  'bike': Icons.directions_bike,
  'laptop': Icons.laptop_mac,
  'goal': Icons.track_changes,
  // fallbacks & misc
  'money': Icons.savings,
  'receipt': Icons.receipt_long,
  'autorenew': Icons.autorenew,
  'mail': Icons.mail_outline,
};

/// Looks up an icon for a data emoji key (null → caller draws the fallback).
IconData? iconForKey(String? key) => key == null ? null : kKeyIcons[key];

/// Circular soft badge that renders a Material icon; unknown/remote keys
/// fall back to a neutral label icon so nothing ever renders blank.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    this.icon,
    this.emojiKey,
    this.size = 42,
    this.iconSize,
    this.bg,
    this.fg,
    this.borderRadius,
  });

  final IconData? icon;
  final String? emojiKey; // semantic icon key, e.g. 'cart'
  final double size;
  final double? iconSize;
  final Color? bg;
  final Color? fg;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final resolved = icon ?? iconForKey(emojiKey);
    final radius = borderRadius ?? BorderRadius.circular(size / 2);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? context.primarySoft,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: resolved != null
          ? Icon(
              resolved,
              size: iconSize ?? size * 0.46,
              color: fg ?? context.primaryDark,
            )
          : Icon(
              Icons.label_outline,
              size: iconSize ?? size * 0.46,
              color: fg ?? context.primaryDark,
            ),
    );
  }
}

/// Smart-card / banner icon: filled white circle holding a colored icon.
class AppIconBubble extends StatelessWidget {
  AppIconBubble({
    super.key,
    required this.icon,
    this.size = 44,
    this.color,
    this.bg,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // Defaults resolve per-theme (dark mode): onPrimaryContainer/surface.
        color: bg ?? Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.5,
        color: color ?? Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}
