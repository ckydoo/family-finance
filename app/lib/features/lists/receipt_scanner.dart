import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// A single line item detected on a scanned receipt.
class ReceiptItem {
  final String name;
  final double price;

  const ReceiptItem({required this.name, required this.price});
}

/// Result of scanning a receipt image: the extracted grand total and the
/// line items OCR could confidently read.
class ReceiptScanResult {
  final double? total;
  final List<ReceiptItem> items;
  final String? rawText;

  const ReceiptScanResult({
    this.total,
    this.items = const [],
    this.rawText,
  });

  bool get hasItems => items.isNotEmpty;
}

/// Receipt scanning for the shopping flow.
///
/// Captures a receipt photo with the camera and runs on-device text
/// recognition (Google ML Kit) to pull out the grand total and line items,
/// so the checkout sheet can be pre-filled instead of typing the total by
/// hand. Returns `null` when the user cancels the camera; a result with a
/// null `total` when OCR ran but could not find a total.
Future<ReceiptScanResult?> scanReceipt(BuildContext context) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.rear,
    maxWidth: 1200,
    imageQuality: 85,
  );
  if (picked == null) return null;

  final recognizer = TextRecognizer();
  try {
    final input = InputImage.fromFilePath(picked.path);
    final result = await recognizer.processImage(input);
    return parseReceipt(result.text);
  } catch (_) {
    // OCR model unavailable or recognition failed — return an empty result
    // so the user can type the total manually.
    return const ReceiptScanResult();
  } finally {
    await recognizer.close();
  }
}

/// Parses OCR text into a total + line items.
///
/// Heuristic but deliberately conservative: a line is treated as an item only
/// when it ends in a positive price and is not a summary/tax/payment line, so
/// the user reviews a short, plausible list rather than a noisy dump.
ReceiptScanResult parseReceipt(String text) {
  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where(
        (line) => line.isNotEmpty,
      )
      .toList();

  return ReceiptScanResult(
    total: _extractTotal(lines),
    items: _extractItems(lines),
    rawText: text,
  );
}

/// Finds the grand total. Prefers explicit "amount/balance due" labels, then
/// falls back to a bare "total".
double? _extractTotal(List<String> lines) {
  final labelPatterns = [
    RegExp(
      r'(amount\s+due|balance\s+due|total\s+due|total\s+payable|amount\s+payable)',
      caseSensitive: false,
    ),
    RegExp(r'(grand\s+total|total\s+amount|total)', caseSensitive: false),
  ];
  for (final pattern in labelPatterns) {
    for (final line in lines) {
      if (pattern.hasMatch(line)) {
        final value = _lastNumber(line);
        if (value != null) return value;
      }
    }
  }
  return null;
}

/// Extracts the last number on a line, normalising thousands separators.
double? _lastNumber(String line) {
  final matches = RegExp(r'\d[\d,]*(?:\.\d+)?').allMatches(line);
  if (matches.isEmpty) return null;
  final raw = matches.last.group(0)!.replaceAll(',', '');
  return double.tryParse(raw);
}

List<ReceiptItem> _extractItems(List<String> lines) {
  final items = <ReceiptItem>[];
  final skip = RegExp(
    r'(total|subtotal|tax|vat|change|balance|cash|card|debit|credit|'
    r'date|time|receipt|thank|voucher|discount|fee|tip|paid|amount|due|'
    r'price|qty|quantity|unit)',
    caseSensitive: false,
  );

  for (final line in lines) {
    if (skip.hasMatch(line)) continue;
    final matches = RegExp(r'\d[\d,]*(?:\.\d+)?').allMatches(line);
    if (matches.isEmpty) continue;
    final price = double.tryParse(
      matches.last.group(0)!.replaceAll(',', ''),
    );
    if (price == null || price <= 0) continue;

    final before = line.substring(0, matches.last.start).trim();
    if (before.isEmpty) continue;
    final name = before.replaceAll(RegExp(r'[\s.:;\-]+$'), '').trim();
    if (name.isEmpty) continue;
    items.add(ReceiptItem(name: name, price: price));
  }
  return items;
}
