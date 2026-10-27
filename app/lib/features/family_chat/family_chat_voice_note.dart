import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/theme/app_theme.dart';

class FamilyChatVoiceNote extends StatefulWidget {
  const FamilyChatVoiceNote({
    super.key,
    required this.url,
    required this.headersGet,
    required this.player,
    required this.isMine,
  });

  final String url;
  final Future<Map<String, String>> Function() headersGet;
  final AudioPlayer player;
  final bool isMine;

  @override
  State<FamilyChatVoiceNote> createState() => _FamilyChatVoiceNoteState();
}

class _FamilyChatVoiceNoteState extends State<FamilyChatVoiceNote> {
  bool _loading = false;
  String? _error;

  bool get _isCurrent => widget.player.audioSource?.sequence
          .any((source) => source.tag == widget.url) ??
      false;

  Future<void> _togglePlayback() async {
    final isCurrent = _isCurrent;
    if (isCurrent && widget.player.playing) {
      await widget.player.pause();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!isCurrent) {
        await widget.player.setAudioSource(AudioSource.uri(
          Uri.parse(widget.url),
          headers: await widget.headersGet(),
          tag: widget.url,
        ));
      }
      if (widget.player.processingState == ProcessingState.completed) {
        await widget.player.seek(Duration.zero);
      }
      unawaited(widget.player.play());
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not play this voice note.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _time(Duration? duration) {
    final seconds = (duration?.inSeconds ?? 0).clamp(0, 359999);
    final minutes = (seconds ~/ 60).toString().padLeft(1, '0');
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.isMine ? context.onSolid : context.ink;
    final muted = widget.isMine
        ? context.onSolid.withValues(alpha: .75)
        : context.inkSoft;
    return SizedBox(
      width: 244,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StreamBuilder<SequenceState?>(
                stream: widget.player.sequenceStateStream,
                builder: (context, sequenceSnapshot) {
                  final isCurrent = _isCurrent;
                  return StreamBuilder<PlayerState>(
                    stream: widget.player.playerStateStream,
                    builder: (context, playerSnapshot) {
                      final isPlaying =
                          isCurrent && (playerSnapshot.data?.playing ?? false);
                      return IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        onPressed: _loading ? null : _togglePlayback,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        tooltip:
                            isPlaying ? 'Pause voice note' : 'Play voice note',
                      );
                    },
                  );
                },
              ),
              Expanded(
                child: StreamBuilder<Duration?>(
                  stream: widget.player.durationStream,
                  builder: (context, durationSnapshot) =>
                      StreamBuilder<Duration>(
                    stream: widget.player.positionStream,
                    builder: (context, positionSnapshot) {
                      final isCurrent = _isCurrent;
                      final duration = isCurrent
                          ? durationSnapshot.data ?? Duration.zero
                          : Duration.zero;
                      final position = isCurrent
                          ? positionSnapshot.data ?? Duration.zero
                          : Duration.zero;
                      final max = duration.inMilliseconds.toDouble();
                      final value = position.inMilliseconds
                          .toDouble()
                          .clamp(0, max > 0 ? max : 1)
                          .toDouble();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Slider(
                            value: value,
                            max: max > 0 ? max : 1,
                            onChanged: max <= 0 || !isCurrent
                                ? null
                                : (next) => widget.player.seek(Duration(
                                      milliseconds: next.round(),
                                    )),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_time(position),
                                    style:
                                        TextStyle(color: muted, fontSize: 10)),
                                Text(_time(duration),
                                    style:
                                        TextStyle(color: muted, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 4),
              child: Text(_error!,
                  style: TextStyle(color: context.danger, fontSize: 11)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 4),
              child: Text('Voice note',
                  style: TextStyle(color: foreground, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
