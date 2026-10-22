import 'dart:io';

import '../sync/avatar_service.dart';
import '../sync/chat_media_service.dart';
import '../sync/supabase_sync_client.dart';

/// Translates raw system errors, exception types, HTTP status codes, and
/// developer error strings into empathetic, user-facing error messages.
String userFacingErrorMessage(
  dynamic error, {
  String fallback =
      'Something went wrong. Please check your connection and try again.',
}) {
  if (error == null) return fallback;

  if (error is AvatarException) {
    return error.message;
  }

  if (error is ChatMediaException) {
    return error.message;
  }

  if (error is SocketException) {
    return 'Could not connect. Please check your internet connection.';
  }

  if (error is SyncException) {
    return _friendlySyncException(error, fallback: fallback);
  }

  final raw = error.toString().trim();
  if (raw.isEmpty) return fallback;

  return _cleanRawErrorMessage(raw, fallback: fallback);
}

String _friendlySyncException(SyncException e, {required String fallback}) {
  if (e.isAuthError) {
    return 'Your session has expired. Please sign in again.';
  }

  final msg = e.message.trim();
  if (msg.isNotEmpty &&
      !msg.startsWith('HTTP ') &&
      !msg.startsWith('SyncException(')) {
    return _cleanRawErrorMessage(msg, fallback: fallback);
  }

  return _mapHttpStatusCode(e.statusCode, fallback: fallback);
}

String _mapHttpStatusCode(int code, {required String fallback}) {
  switch (code) {
    case 400:
    case 422:
      return 'The information provided could not be processed. Please check and try again.';
    case 401:
      return 'Your session has expired. Please sign in again.';
    case 403:
      return 'You do not have permission to make this change.';
    case 404:
      return 'The requested record was not found.';
    case 409:
      return 'This record already exists or conflicts with a previous update.';
    case 429:
      return 'Too many requests. Please wait a moment and try again.';
    case 500:
    case 502:
    case 503:
    case 504:
      return 'Our servers are temporarily busy. Please try again shortly.';
    case 0:
      return 'Could not reach the server. Please check your internet connection.';
    default:
      return fallback;
  }
}

String _cleanRawErrorMessage(String raw, {required String fallback}) {
  // Strip Exception: or SyncException(...) wrapper if present
  var text = raw;
  if (text.startsWith('Exception: ')) {
    text = text.substring('Exception: '.length).trim();
  } else if (text.startsWith('SyncException(') && text.endsWith(')')) {
    final inner = text.substring('SyncException('.length, text.length - 1);
    final comma = inner.indexOf(',');
    if (comma != -1) {
      text = inner.substring(comma + 1).trim();
    }
  }

  // Handle known error code prefixes like "FAMILY_NAME_TAKEN: ..."
  if (text.contains('FAMILY_NAME_TAKEN')) {
    final idx = text.indexOf(':');
    if (idx != -1 && idx + 1 < text.length) {
      final sub = text.substring(idx + 1).trim();
      if (sub.isNotEmpty) return sub;
    }
    return 'That family name is already taken — try another.';
  }

  if (text.contains('INVALID_CODE')) {
    return 'That invite code was not found — check it and try again.';
  }

  if (text.contains('ALREADY_IN_FAMILY')) {
    return 'This account already belongs to a family.';
  }

  if (text.contains('TOO_MANY_INVITES')) {
    return 'Maximum open invites reached. Revoke an old invite or wait for it to expire.';
  }

  if (text.contains('EMAIL_EXISTS')) {
    return 'An account with this email already exists.';
  }

  if (text.contains('OWNER_REQUIRED_FOR_ADULT')) {
    return 'Only the family owner can grant an Adult role.';
  }

  if (text.contains('SYNC_NOT_READY')) {
    return 'Connecting to family sync. Please try again in a moment.';
  }

  if (text.contains('unexpected response from server')) {
    return 'The server sent an unexpected response. Please try again in a moment.';
  }

  if (text.contains('GOAL_CREATE_FAILED')) {
    return 'Could not create your savings jar. Please try again.';
  }

  if (text.contains('row-level security') ||
      text.contains('violates row-level security') ||
      text.contains('permission denied') ||
      text.contains('PGRST') ||
      text.contains('PostgrestException')) {
    return 'This change could not be saved. Check your family access and try again.';
  }

  if (text.contains('JWT') ||
      text.contains('invalid claim') ||
      text.contains('token is expired')) {
    return 'Your session has expired. Please sign in again.';
  }

  if (text.contains('DatabaseException') ||
      text.contains('SqliteException') ||
      text.contains('database_closed')) {
    return 'Mhuri could not access saved data on this device. Please reopen the app and try again.';
  }

  if (text.startsWith('HTTP ')) {
    final parts = text.split(' ');
    final code = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (code != null) {
      return _mapHttpStatusCode(code, fallback: fallback);
    }
    return fallback;
  }

  if (text.contains('SocketException') ||
      text.contains('Network error') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('Connection timed out')) {
    return 'Could not reach the server. Please check your internet connection.';
  }

  if (text.contains('TimeoutException')) {
    return 'The request timed out. Please check your connection and try again.';
  }

  // Unknown server, database and implementation messages must never be
  // rendered to users. They remain available through debug/observability
  // logging at the call site.
  return fallback;
}
