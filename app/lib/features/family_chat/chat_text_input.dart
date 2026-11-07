import 'package:flutter/services.dart';

/// Removes emoji entered through a system keyboard, hardware keyboard, or
/// paste while leaving ordinary multilingual text and punctuation intact.
///
/// The chat's own emoji/sticker tray writes directly to its controller and is
/// intentionally not affected by this input formatter.
class NoEmojiTextInputFormatter extends TextInputFormatter {
  const NoEmojiTextInputFormatter({this.onEmojiBlocked});

  final VoidCallback? onEmojiBlocked;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clean = stripChatEmoji(newValue.text);
    if (clean == newValue.text) return newValue;
    onEmojiBlocked?.call();

    int cleanOffset(int offset) {
      if (offset < 0 || offset > newValue.text.length) return clean.length;
      return stripChatEmoji(newValue.text.substring(0, offset)).length;
    }

    final selection = newValue.selection;
    return TextEditingValue(
      text: clean,
      selection: selection.isValid
          ? TextSelection(
              baseOffset: cleanOffset(selection.baseOffset),
              extentOffset: cleanOffset(selection.extentOffset),
            )
          : TextSelection.collapsed(offset: clean.length),
      // The old composing range may no longer exist after filtering.
      composing: TextRange.empty,
    );
  }
}

final RegExp _keycapEmoji = RegExp(r'[#*0-9]\uFE0F?\u20E3');

/// Emoji blocks and emoji-presenting characters outside the main SMP blocks.
/// Broad Misc Symbols/Dingbats ranges are intentional: characters such as
/// hearts, checks, and stars should not enter through the device keyboard.
bool _isEmojiCodePoint(int value) =>
    (value >= 0x1F000 && value <= 0x1FFFF) ||
    (value >= 0x2600 && value <= 0x27BF) ||
    (value >= 0x2B00 && value <= 0x2BFF) ||
    (value >= 0x2300 && value <= 0x23FF) ||
    (value >= 0x2460 && value <= 0x24FF) ||
    (value >= 0x25A0 && value <= 0x25FF) ||
    (value >= 0x2900 && value <= 0x297F) ||
    (value >= 0x2194 && value <= 0x2199) ||
    value == 0x21A9 ||
    value == 0x21AA ||
    value == 0x20E3 ||
    value == 0x00A9 ||
    value == 0x00AE ||
    value == 0x203C ||
    value == 0x2049 ||
    value == 0x2122 ||
    value == 0x2139 ||
    value == 0x3030 ||
    value == 0x303D ||
    value == 0x3297 ||
    value == 0x3299;

bool _isVariationSelector(int value) =>
    value == 0xFE0E ||
    value == 0xFE0F ||
    (value >= 0xE0100 && value <= 0xE01EF);

bool containsChatEmoji(String input) => stripChatEmoji(input) != input;

/// Strips complete common emoji sequences, including flags, skin tones,
/// keycaps, and zero-width-joiner families. ZWJ characters used by ordinary
/// writing systems are preserved unless they join emoji code points.
String stripChatEmoji(String input) {
  if (input.isEmpty) return input;
  final withoutKeycaps = input.replaceAll(_keycapEmoji, '');
  final codePoints = withoutKeycaps.runes.toList(growable: false);
  final output = StringBuffer();

  bool isFollowedByEmojiPresentation(int index) =>
      index + 1 < codePoints.length &&
      (codePoints[index + 1] == 0xFE0F || codePoints[index + 1] == 0x20E3);

  bool adjacentToEmoji(int index) {
    final previousIsEmoji = index > 0 &&
        (_isEmojiCodePoint(codePoints[index - 1]) ||
            isFollowedByEmojiPresentation(index - 1));
    final nextIsEmoji = index + 1 < codePoints.length &&
        (_isEmojiCodePoint(codePoints[index + 1]) ||
            isFollowedByEmojiPresentation(index + 1));
    return previousIsEmoji || nextIsEmoji;
  }

  for (var index = 0; index < codePoints.length; index++) {
    final value = codePoints[index];
    if (_isEmojiCodePoint(value)) continue;
    if (isFollowedByEmojiPresentation(index)) continue;
    if (value == 0xFE0F) continue;
    if (value == 0x200D && adjacentToEmoji(index)) continue;
    if (_isVariationSelector(value) && adjacentToEmoji(index)) continue;
    // Emoji tag sequences used by subdivision flags have no ordinary text use.
    if (value >= 0xE0020 && value <= 0xE007F) continue;
    output.writeCharCode(value);
  }
  return output.toString();
}
