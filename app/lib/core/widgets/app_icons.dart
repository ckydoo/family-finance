/// M8 polish - icon system. Every visual entity (envelope, goal, account,
/// member, recurring rule) carries a stable SEMANTIC icon key in the data
/// layer: 'cart', 'school', 'fuel', 'man', 'bank', 'autorenew', … No emojis
/// exist in the database or the UI. This map is the single place that turns
/// a key into a Material icon; unknown keys (future/remote data) fall back
/// to a neutral icon, never blank, never a raw emoji.
///
/// Notification text (reminders.dart) is the one intentional emoji zone -
/// it renders in the OS tray, outside the app, where IconData cannot.
library;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme/app_theme.dart';

/// Semantic icon keys → the app's premium icon family.
final Map<String, IconData> kKeyIcons = {
  // members
  'man': FontAwesomeIcons.person.data,
  'woman': FontAwesomeIcons.personDress.data,
  'boy': FontAwesomeIcons.child.data,
  'baby': FontAwesomeIcons.babyCarriage.data,
  'student': FontAwesomeIcons.graduationCap.data,
  'grandma': FontAwesomeIcons.personCane.data,
  'person': FontAwesomeIcons.user.data,
  // accounts
  'bank': FontAwesomeIcons.buildingColumns.data,
  'cash': FontAwesomeIcons.moneyBillWave.data,
  'wallet': FontAwesomeIcons.wallet.data,
  // envelopes & recurring
  'cart': FontAwesomeIcons.cartShopping.data,
  'school': FontAwesomeIcons.graduationCap.data,
  'fuel': FontAwesomeIcons.gasPump.data,
  'power': FontAwesomeIcons.bolt.data,
  'airtime': FontAwesomeIcons.mobileScreen.data,
  'stars': FontAwesomeIcons.star.data,
  'lifebuoy': FontAwesomeIcons.lifeRing.data,
  'giving': FontAwesomeIcons.handHoldingHeart.data,
  'home': FontAwesomeIcons.houseChimney.data,
  'lightbulb': FontAwesomeIcons.lightbulb.data,
  'health': FontAwesomeIcons.heartPulse.data,
  'car': FontAwesomeIcons.car.data,
  'water': FontAwesomeIcons.droplet.data,
  // goals
  'beach': FontAwesomeIcons.umbrellaBeach.data,
  'bike': FontAwesomeIcons.bicycle.data,
  'laptop': FontAwesomeIcons.laptop.data,
  'goal': FontAwesomeIcons.bullseye.data,
  // fallbacks & misc
  'money': FontAwesomeIcons.piggyBank.data,
  'receipt': FontAwesomeIcons.receipt.data,
  'autorenew': FontAwesomeIcons.arrowsRotate.data,
  'mail': FontAwesomeIcons.envelope.data,
};

/// One neutral fallback for unknown or remotely supplied semantic keys.
///
/// Keep this separate from action icons: semantic entities use the premium
/// family, while controls such as back, close and search remain Material.
final IconData kFallbackSemanticIcon = FontAwesomeIcons.tag.data;

/// Looks up an icon for a data emoji key (null → caller draws the fallback).
IconData? iconForKey(String? key) => key == null ? null : kKeyIcons[key];

/// Unframed semantic icon; unknown/remote keys
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
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: resolved != null
            ? Icon(
                resolved,
                size: iconSize ?? size * 0.46,
                color: fg ?? context.primaryDark,
              )
            : Icon(
                kFallbackSemanticIcon,
                size: iconSize ?? size * 0.46,
                color: fg ?? context.primaryDark,
              ),
      ),
    );
  }
}

/// Smart-card / banner icon. It is unframed unless a background is requested.
class AppIconBubble extends StatelessWidget {
  const AppIconBubble({
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
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(
          icon,
          size: size * 0.5,
          color: color ?? Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
