import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../sync/receipt_storage_service.dart';

/// Sync status of one transaction's receipt photo (#1).
enum ReceiptSyncState { syncedToCloud, savedOnDevice, waitingUpload, none }

ReceiptSyncState receiptSyncStateOf(AppState state, Tx tx) {
  final uri = tx.receiptUri;
  if (uri == null || uri.trim().isEmpty) return ReceiptSyncState.none;
  if (isRemoteReceiptUri(uri)) return ReceiptSyncState.syncedToCloud;
  return state.sync != null
      ? ReceiptSyncState.waitingUpload
      : ReceiptSyncState.savedOnDevice;
}

/// Localized one-line status for a receipt photo.
String receiptStatusLabel(BuildContext context, ReceiptSyncState status) {
  final l = AppLocalizations.of(context)!;
  return switch (status) {
    ReceiptSyncState.syncedToCloud => l.receiptSavedToCloud,
    ReceiptSyncState.waitingUpload => l.receiptWaitingUpload,
    ReceiptSyncState.savedOnDevice => l.receiptOnThisDevice,
    ReceiptSyncState.none => '',
  };
}

/// Opens the fullscreen zoomable receipt photo for [tx], loading bytes from
/// the device path, the offline disk cache, or the authenticated private
/// `receipts` Storage endpoint (in that order, via [ReceiptStorageService]).
Future<void> showReceiptViewer(
  BuildContext context, {
  required AppState state,
  required Tx tx,
}) async {
  final uri = tx.receiptUri?.trim();
  if (uri == null || uri.isEmpty) return;
  final storage = state.receiptStorage;
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ReceiptViewerPage(
        title: AppLocalizations.of(context)!.receiptPhoto,
        statusLabel: receiptStatusLabel(
          context,
          receiptSyncStateOf(state, tx),
        ),
        loader: storage == null
            ? () async {
                // No configured backend (tests/offline-only): still show a
                // device-local photo, fail cleanly for remote-only ones.
                if (isRemoteReceiptUri(uri)) {
                  throw const ReceiptStorageException(
                      'Sign in again to download this receipt photo.');
                }
                return _readLocalReceipt(uri);
              }
            : () => storage.loadBytes(uri),
      ),
    ),
  );
}

/// Opens the zoomable viewer for a receipt staged in Quick Add that has no
/// transaction row yet.
Future<void> showStagedReceiptViewer(
  BuildContext context, {
  required String path,
  required Uint8List bytes,
}) async {
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ReceiptViewerPage(
        title: AppLocalizations.of(context)!.receiptPhoto,
        statusLabel: receiptStatusLabel(
          context,
          ReceiptSyncState.savedOnDevice,
        ),
        loader: () async => bytes,
      ),
    ),
  );
}

Future<Uint8List> _readLocalReceipt(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw const ReceiptStorageException(
        'This receipt was saved only on another device or is no longer on disk.');
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    throw const ReceiptStorageException('The receipt file is empty.');
  }
  return bytes;
}

/// Fullscreen, pinch-to-zoom receipt photo with a sync-status chip.
class ReceiptViewerPage extends StatelessWidget {
  const ReceiptViewerPage({
    super.key,
    required this.title,
    required this.statusLabel,
    required this.loader,
  });

  final String title;
  final String statusLabel;
  final Future<Uint8List> Function() loader;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          if (statusLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: loader(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            );
          }
          final bytes = snapshot.data;
          if (snapshot.hasError ||
              bytes == null ||
              bytes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      color: Colors.white38,
                      size: 44,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppLocalizations.of(context)!.receiptLoadFailed,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small square receipt preview for tiles and sheets. Local photos render
/// straight from disk; remote photos load through the offline cache first.
class ReceiptThumb extends StatelessWidget {
  const ReceiptThumb({
    super.key,
    required this.receiptUri,
    this.storage,
    this.size = 44,
    this.borderRadius = 10,
  });

  final String receiptUri;
  final ReceiptStorageService? storage;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final uri = receiptUri.trim();
    final Widget image;
    if (!isRemoteReceiptUri(uri)) {
      image = Image.file(
        File(uri),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _broken(context),
      );
    } else {
      final loader = storage;
      if (loader == null) {
        image = _broken(context);
      } else {
        image = FutureBuilder<Uint8List>(
          future: loader.loadBytes(uri),
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done ||
                bytes == null ||
                bytes.isEmpty) {
              return const ColoredBox(
                color: Color(0x14000000),
                child: Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _broken(context),
            );
          },
        );
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: image,
      ),
    );
  }

  Widget _broken(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.receipt_long_outlined,
          size: size * 0.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}
