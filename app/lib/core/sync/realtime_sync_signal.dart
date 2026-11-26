import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef RealtimeSocketConnector = Future<WebSocket> Function(String url);

/// Lightweight, dependency-free Supabase Realtime (Phoenix v1) listener for
/// `public.family_sync_signal`.
///
/// Design invariants:
/// - Signal-only: payloads carry no financial data; notifications only wake up
///   [SyncEngine] to run an authenticated, RLS-enforced delta pull.
/// - Silent fallback: socket failures never surface user-facing errors. When
///   Realtime is unavailable, [isConnected] becomes false and [SyncEngine]
///   falls back to its foreground poll seamlessly.
/// - Burst coalescing: rapid multi-row commits coalesce into a single callback.
class RealtimeSyncSignal {
  RealtimeSyncSignal({
    required String baseUrl,
    required String anonKey,
    required Future<String?> Function() tokenGet,
    required void Function(int? remoteSeq) onSignal,
    void Function()? onConnected,
    RealtimeSocketConnector? connector,
    Duration coalesceWindow = const Duration(milliseconds: 120),
  })  : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _anonKey = anonKey,
        _tokenGet = tokenGet,
        _onSignal = onSignal,
        _onConnected = onConnected,
        _connector = connector ?? _defaultConnect,
        _coalesceWindow = coalesceWindow;

  final String _baseUrl;
  final String _anonKey;
  final Future<String?> Function() _tokenGet;
  final void Function(int? remoteSeq) _onSignal;
  final void Function()? _onConnected;
  final RealtimeSocketConnector _connector;
  final Duration _coalesceWindow;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  Timer? _heartbeatTimer;
  Timer? _tokenRefreshTimer;
  Timer? _reconnectTimer;
  Timer? _coalesceTimer;

  String? _spaceId;
  bool _active = false;
  bool _disposed = false;
  bool _connecting = false;
  bool _joined = false;
  int _refCounter = 0;
  String? _joinRef;
  int _reconnectAttempt = 0;
  int? _pendingMaxSeq;

  bool get isConnected => _socket != null && _joined;

  static Future<WebSocket> _defaultConnect(String url) =>
      WebSocket.connect(url).timeout(const Duration(seconds: 10));

  void configure({required String? spaceId, required bool active}) {
    if (_disposed) return;
    final cleanSpace = (spaceId == null || spaceId.isEmpty) ? null : spaceId;
    final spaceChanged = _spaceId != cleanSpace;
    final activeChanged = _active != active;
    if (!spaceChanged && !activeChanged) return;

    _spaceId = cleanSpace;
    _active = active;

    if (!_active || _spaceId == null) {
      _reconnectAttempt = 0;
      _teardownSocket();
      return;
    }

    if (spaceChanged || (_socket == null && !_connecting)) {
      _reconnectAttempt = 0;
      _teardownSocket();
      _connect();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    _spaceId = null;
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    _teardownSocket();
  }

  String _wsUrl() {
    final wsBase = _baseUrl.startsWith('https://')
        ? 'wss://${_baseUrl.substring('https://'.length)}'
        : _baseUrl.startsWith('http://')
            ? 'ws://${_baseUrl.substring('http://'.length)}'
            : 'wss://$_baseUrl';
    final encodedKey = Uri.encodeQueryComponent(_anonKey);
    return '$wsBase/realtime/v1/websocket?apikey=$encodedKey&vsn=1.0.0';
  }

  String _topicFor(String spaceId) =>
      'realtime:public:family_sync_signal:space_id=eq.$spaceId';

  String _nextRef() => '${++_refCounter}';

  Future<void> _connect() async {
    if (_disposed || !_active || _spaceId == null || _connecting) return;
    if (_anonKey.isEmpty || _baseUrl.isEmpty) return;

    final targetSpace = _spaceId!;
    _connecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      final token = await _tokenGet();
      if (_disposed || !_active || _spaceId != targetSpace) {
        _connecting = false;
        return;
      }
      if (token == null || token.isEmpty) {
        _connecting = false;
        _scheduleReconnect();
        return;
      }

      final ws = await _connector(_wsUrl());
      if (_disposed || !_active || _spaceId != targetSpace) {
        try {
          await ws.close();
        } catch (_) {}
        _connecting = false;
        return;
      }

      ws.pingInterval = const Duration(seconds: 25);
      _socket = ws;
      _joined = false;
      _connecting = false;

      _sub = ws.listen(
        _handleFrame,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );

      _sendJoin(targetSpace, token);
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        _sendFrame({
          'topic': 'phoenix',
          'event': 'heartbeat',
          'payload': const <String, Object?>{},
          'ref': _nextRef(),
        });
      });
      _tokenRefreshTimer?.cancel();
      _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 4), (_) {
        unawaited(_refreshSocketToken(targetSpace));
      });
    } catch (_) {
      _connecting = false;
      _handleDisconnect();
    }
  }

  Future<void> _refreshSocketToken(String targetSpace) async {
    if (_disposed || !_active || _spaceId != targetSpace || _socket == null) {
      return;
    }
    try {
      final token = await _tokenGet();
      if (token == null || token.isEmpty) return;
      _sendFrame({
        'topic': _topicFor(targetSpace),
        'event': 'access_token',
        'payload': {'access_token': token},
        'ref': _nextRef(),
      });
    } catch (_) {}
  }

  void _sendJoin(String spaceId, String token) {
    final ref = _nextRef();
    _joinRef = ref;
    _sendFrame({
      'topic': _topicFor(spaceId),
      'event': 'phx_join',
      'payload': {
        'config': {
          'broadcast': {'ack': false, 'self': false},
          'presence': {'key': ''},
          'postgres_changes': [
            {
              'event': '*',
              'schema': 'public',
              'table': 'family_sync_signal',
              'filter': 'space_id=eq.$spaceId',
            },
          ],
          'private': false,
        },
        'access_token': token,
      },
      'ref': ref,
      'join_ref': ref,
    });
  }

  void _sendFrame(Map<String, Object?> frame) {
    final ws = _socket;
    if (ws == null) return;
    try {
      ws.add(jsonEncode(frame));
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleFrame(dynamic raw) {
    if (_disposed || raw is! String || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final event = decoded['event']?.toString() ?? '';
      final ref = decoded['ref']?.toString();
      final payload = decoded['payload'];

      if (event == 'phx_reply' && ref != null && ref == _joinRef) {
        final status = payload is Map ? payload['status']?.toString() : null;
        if (status == 'ok') {
          _joined = true;
          _reconnectAttempt = 0;
          _onConnected?.call();
        } else {
          _handleDisconnect();
        }
        return;
      }

      if (event == 'phx_error' || event == 'phx_close') {
        _handleDisconnect();
        return;
      }

      if (event == 'postgres_changes' ||
          event == 'INSERT' ||
          event == 'UPDATE') {
        int? seq;
        if (payload is Map) {
          final data = payload['data'];
          final record = data is Map
              ? (data['record'] ?? data['new'])
              : (payload['record'] ?? payload['new']);
          if (record is Map) {
            final rawSeq = record['latest_seq'] ?? record['last_seq'];
            if (rawSeq is num) {
              seq = rawSeq.toInt();
            } else if (rawSeq != null) {
              seq = int.tryParse(rawSeq.toString());
            }
          }
        }
        _scheduleCoalescedSignal(seq);
      }
    } catch (_) {
      // Ignore malformed frames cleanly.
    }
  }

  void _scheduleCoalescedSignal(int? seq) {
    if (seq != null && (_pendingMaxSeq == null || seq > _pendingMaxSeq!)) {
      _pendingMaxSeq = seq;
    }
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(_coalesceWindow, () {
      if (_disposed || !_active) return;
      final captured = _pendingMaxSeq;
      _pendingMaxSeq = null;
      _onSignal(captured);
    });
  }

  void _handleDisconnect() {
    _teardownSocket();
    if (!_disposed && _active && _spaceId != null) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || !_active || _spaceId == null) return;
    if (_reconnectTimer?.isActive ?? false) return;
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(1, 5);
    final delaySecs = switch (_reconnectAttempt) {
      1 => 2,
      2 => 4,
      3 => 8,
      4 => 16,
      _ => 30,
    };
    _reconnectTimer = Timer(Duration(seconds: delaySecs), _connect);
  }

  void _teardownSocket() {
    _joined = false;
    _joinRef = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    final sub = _sub;
    _sub = null;
    final ws = _socket;
    _socket = null;
    if (sub != null) {
      unawaited(sub.cancel().catchError((_) {}));
    }
    if (ws != null) {
      try {
        unawaited(ws.close().catchError((_) {}));
      } catch (_) {}
    }
  }
}
