import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/sync/avatar_service.dart';
import 'package:mhuri_money/core/sync/chat_media_service.dart';
import 'package:mhuri_money/core/sync/supabase_sync_client.dart';
import 'package:mhuri_money/core/utils/error_messages.dart';

void main() {
  group('userFacingErrorMessage', () {
    test('returns fallback for null or empty input', () {
      expect(
        userFacingErrorMessage(null),
        'Something went wrong. Please check your connection and try again.',
      );
      expect(
        userFacingErrorMessage('   ', fallback: 'Custom fallback'),
        'Custom fallback',
      );
    });

    test('formats AvatarException and ChatMediaException', () {
      const avatarErr = AvatarException('Photo is too large.');
      expect(userFacingErrorMessage(avatarErr), 'Photo is too large.');

      const chatErr = ChatMediaException('Could not upload photo.');
      expect(userFacingErrorMessage(chatErr), 'Could not upload photo.');
    });

    test('formats SocketException and network timeouts', () {
      const socketErr = SocketException('Failed host lookup');
      expect(
        userFacingErrorMessage(socketErr),
        'Could not connect. Please check your internet connection.',
      );
      expect(
        userFacingErrorMessage('SocketException: OS Error: connection refused'),
        'Could not reach the server. Please check your internet connection.',
      );
      expect(
        userFacingErrorMessage('TimeoutException after 0:00:10.000000'),
        'The request timed out. Please check your connection and try again.',
      );
    });

    test('formats SyncException auth expiration', () {
      const authErr = SyncException(401, 'Unauthorized');
      expect(
        userFacingErrorMessage(authErr),
        'Your session has expired. Please sign in again.',
      );
      expect(
        userFacingErrorMessage(const SyncException(403, 'HTTP 403')),
        'You do not have permission to make this change.',
      );
    });

    test('formats SyncException server error codes without message', () {
      const srvErr = SyncException(500, 'HTTP 500');
      expect(
        userFacingErrorMessage(srvErr),
        'Our servers are temporarily busy. Please try again shortly.',
      );

      const netErr = SyncException(0, 'HTTP 0');
      expect(
        userFacingErrorMessage(netErr),
        'Could not reach the server. Please check your internet connection.',
      );
    });

    test('translates raw error codes and developer strings', () {
      expect(
        userFacingErrorMessage(
            'FAMILY_NAME_TAKEN: That family name is already taken - try another.'),
        'That family name is already taken - try another.',
      );
      expect(
        userFacingErrorMessage('FAMILY_NAME_TAKEN'),
        'That family name is already taken — try another.',
      );
      expect(
        userFacingErrorMessage('INVALID_CODE'),
        'That invite code was not found — check it and try again.',
      );
      expect(
        userFacingErrorMessage('ALREADY_IN_FAMILY'),
        'This account already belongs to a family.',
      );
      expect(
        userFacingErrorMessage('TOO_MANY_INVITES'),
        'Maximum open invites reached. Revoke an old invite or wait for it to expire.',
      );
      expect(
        userFacingErrorMessage('EMAIL_EXISTS'),
        'An account with this email already exists.',
      );
      expect(
        userFacingErrorMessage('OWNER_REQUIRED_FOR_ADULT'),
        'Only the family owner can grant an Adult role.',
      );
      expect(
        userFacingErrorMessage('unexpected response from server'),
        'The server sent an unexpected response. Please try again in a moment.',
      );
      expect(
        userFacingErrorMessage('GOAL_CREATE_FAILED'),
        'Could not create your savings jar. Please try again.',
      );
    });

    test('strips Exception: prefix and formats nested SyncException strings',
        () {
      expect(
        userFacingErrorMessage('Exception: FAMILY_NAME_TAKEN: Taken'),
        'Taken',
      );
      expect(
        userFacingErrorMessage('SyncException(500, HTTP 500)'),
        'Our servers are temporarily busy. Please try again shortly.',
      );
    });

    test('never exposes unknown developer or database details', () {
      expect(
        userFacingErrorMessage(
          'DatabaseException(near SELECT: syntax error)',
          fallback: 'Could not save your change. Please try again.',
        ),
        'Mhuri could not access saved data on this device. Please reopen the app and try again.',
      );
      expect(
        userFacingErrorMessage(
          'Null check operator used on a null value at sync_engine.dart:42',
          fallback: 'Could not save your change. Please try again.',
        ),
        'Could not save your change. Please try again.',
      );
      expect(
        userFacingErrorMessage(
          'new row violates row-level security policy for table transaction',
        ),
        'This change could not be saved. Check your family access and try again.',
      );
    });
  });
}
