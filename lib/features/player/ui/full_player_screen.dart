import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/audio_provider.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/utils/media_item_track.dart';
import '../../../data/models/lyric_line.dart';
import '../../../data/models/track_model.dart';

class FullPlayerScreen extends ConsumerWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snap) {
        final item = snap.data;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Now playing')),
            body: const Center(child: Text('Nothing playing')),
          );
        }
        final track = trackFromMediaItem(item);
        final likeState = ref.watch(likeStatusProvider(track.id));
        return Scaffold(
          appBar: AppBar(
            title: const Text('Now playing'),
            actions: [
              likeState.when(
                data: (isLiked) {
                  return IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.pinkAccent : null,
                    ),
                    onPressed: () async {
                      await ref
                          .read(userLibraryRepositoryProvider)
                          .setLiked(track, !isLiked);
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (item.artUri != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        item.artUri.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.music_note, size: 120),
                      ),
                    ),
                  )
                else
                  const Icon(Icons.music_note, size: 120),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  item.artist ?? '',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                StreamBuilder<Duration>(
                  stream: handler.positionStream,
                  builder: (context, posSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    return StreamBuilder<Duration?>(
                      stream: handler.durationStream,
                      builder: (context, durSnap) {
                        final total =
                            durSnap.data ?? item.duration ?? Duration.zero;
                        final maxMs = total.inMilliseconds.clamp(1, 1 << 50);
                        final value = pos.inMilliseconds / maxMs;
                        return Column(
                          children: [
                            Slider(
                              value: value.clamp(0.0, 1.0),
                              onChanged: (v) {
                                handler.seek(
                                  Duration(
                                    milliseconds: (v * maxMs).round(),
                                  ),
                                );
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_fmt(pos)),
                                Text(_fmt(total)),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 48,
                      onPressed: () {
                        final p = handler.player.position;
                        final next = p - const Duration(seconds: 10);
                        handler.seek(
                          next.isNegative ? Duration.zero : next,
                        );
                      },
                      icon: const Icon(Icons.replay_10),
                    ),
                    StreamBuilder<PlaybackState>(
                      stream: handler.playbackState,
                      builder: (context, ps) {
                        final playing = ps.data?.playing ?? false;
                        return IconButton(
                          iconSize: 64,
                          onPressed: () {
                            if (playing) {
                              handler.pause();
                            } else {
                              handler.play();
                            }
                          },
                          icon: Icon(
                            playing
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      iconSize: 48,
                      onPressed: () {
                        final p = handler.player.position;
                        final d = handler.player.duration ?? Duration.zero;
                        final next = p + const Duration(seconds: 10);
                        handler.seek(next > d ? d : next);
                      },
                      icon: const Icon(Icons.forward_10),
                    ),
                  ],
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: const Color(0xFF121212),
                      builder: (ctx) => DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.55,
                        minChildSize: 0.35,
                        maxChildSize: 0.92,
                        builder: (_, scroll) =>
                            _FullLyricsPane(track: track, scroll: scroll),
                      ),
                    );
                  },
                  icon: const Icon(Icons.subtitles_outlined),
                  label: const Text('Synced lyrics (LRCLIB)'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _FullLyricsPane extends ConsumerStatefulWidget {
  const _FullLyricsPane({required this.track, required this.scroll});

  final Track track;
  final ScrollController scroll;

  @override
  ConsumerState<_FullLyricsPane> createState() => _FullLyricsPaneState();
}

class _FullLyricsPaneState extends ConsumerState<_FullLyricsPane> {
  Future<List<dynamic>>? _future;

  Future<List<dynamic>> _load() {
    _future ??= () {
      final lyrics = ref.read(lyricsRepositoryProvider);
      return Future.wait([
        lyrics.fetchSyncedLines(
          artist: widget.track.artist,
          title: widget.track.title,
          durationSeconds: widget.track.duration.inSeconds,
        ),
        lyrics.fetchPlainLyrics(
          artist: widget.track.artist,
          title: widget.track.title,
          durationSeconds: widget.track.duration.inSeconds,
        ),
      ]);
    }();
    return _future!;
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.watch(audioHandlerProvider);
    return FutureBuilder<List<dynamic>>(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final synced = snap.data![0] as List<LyricLine>;
        final plain = snap.data![1] as String?;
        if (synced.isEmpty && (plain == null || plain.isEmpty)) {
          return const Center(child: Text('No lyrics found'));
        }
        if (synced.isEmpty) {
          return ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.all(20),
            children: [Text(plain!, style: const TextStyle(height: 1.5))],
          );
        }
        return StreamBuilder<Duration>(
          stream: handler.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            var active = 0;
            for (var i = 0; i < synced.length; i++) {
              if (synced[i].time <= pos) active = i;
            }
            return ListView.builder(
              controller: widget.scroll,
              padding: const EdgeInsets.all(16),
              itemCount: synced.length,
              itemBuilder: (context, i) {
                final line = synced[i];
                final hl = i == active;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    line.text,
                    style: TextStyle(
                      fontSize: hl ? 20 : 16,
                      fontWeight: hl ? FontWeight.bold : FontWeight.normal,
                      color: hl ? Colors.deepPurpleAccent : Colors.white70,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
