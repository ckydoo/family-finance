import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/features/family_chat/chat_text_input.dart';

void main() {
  group('stripChatEmoji', () {
    test('removes keyboard emoji and common composite sequences', () {
      expect(stripChatEmoji('Hello 😀'), 'Hello ');
      expect(stripChatEmoji('👨‍👩‍👧‍👦'), isEmpty);
      expect(stripChatEmoji('🇿🇼'), isEmpty);
      expect(stripChatEmoji('👍🏾'), isEmpty);
      expect(stripChatEmoji('❤️'), isEmpty);
      expect(stripChatEmoji('✅'), isEmpty);
      expect(stripChatEmoji('↔️'), isEmpty);
      expect(stripChatEmoji('Ⓜ️'), isEmpty);
      expect(stripChatEmoji('#️⃣'), isEmpty);
    });

    test('preserves ordinary multilingual text and punctuation', () {
      const text =
          'Mhuri · USD/ZiG $25.00 → bank\nMãi, niño, Français, 中文. مرحبا';
      expect(stripChatEmoji(text), text);
    });

    test('preserves non-emoji joiners in ordinary writing systems', () {
      const text = 'क्‍ष';
      expect(stripChatEmoji(text), text);
    });
  });

  test('formatter filters typed or pasted emoji and repairs the selection', () {
    const formatter = NoEmojiTextInputFormatter();
    const oldValue = TextEditingValue(text: 'Hello');
    const emojiValue = TextEditingValue(
      text: 'Hello😀 family',
      selection: TextSelection.collapsed(offset: 14),
    );

    final result = formatter.formatEditUpdate(oldValue, emojiValue);

    expect(result.text, 'Hello family');
    expect(result.selection.extentOffset, result.text.length);
    expect(result.composing, TextRange.empty);
  });
}
