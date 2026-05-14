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
            backgroundColor: const Color(0xFF0D0D0D),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: const Text('Now Playing'),
            ),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('Nothing playing', style: TextStyle(color: Colors.white38)),
                ],
              ),
            ),
          );
        }

        final track = trackFromMediaItem(item);
        final likeState = ref.watch(likeStatusProvider(track.id));
        final artUrl = item.artUri?.toString() ?? '';

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          body: Stack(
            children: [
              // Blurred art background
              if (artUrl.isNotEmpty)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.18,
                    child: Image.network(
                      artUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x880D0D0D),
                        Color(0xFF0D0D0D),
                      ],
                      stops: [0.0, 0.55],
                    ),
                  ),
                ),
              ),
              // Content
              SafeArea(
                child: Column(
                  children: [
                    // Top bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down,
                                color: Colors.white70, size: 32),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Expanded(
                            child: Text(
                              'NOW PLAYING',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          likeState.when(
                            data: (isLiked) => IconButton(
                              icon: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Colors.pinkAccent : Colors.white54,
                              ),
                              onPressed: () => ref
                                  .read(userLibraryRepositoryProvider)
                                  .setLiked(track, !isLiked),
                            ),
                            loading: () => const SizedBox(width: 48),
                            error: (_, __) => const SizedBox(width: 48),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Album art — not full screen, a floating card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: artUrl.isNotEmpty
                                ? Image.network(
                                    artUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _PlaceholderArt(title: item.title),
                                  )
                                : _PlaceholderArt(title: item.title),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title + artist
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.artist ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Progress slider
                    StreamBuilder<Duration>(
                      stream: handler.positionStream,
                      builder: (context, posSnap) {
                        final pos = posSnap.data ?? Duration.zero;
                        return StreamBuilder<Duration?>(
                          stream: handler.durationStream,
                          builder: (context, durSnap) {
                            final total =
                                durSnap.data ?? item.duration ?? Duration.zero;
                            final maxMs = total.inMilliseconds.clamp(1, 3600000);
                            final value = pos.inMilliseconds / maxMs;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(
                                          overlayRadius: 16),
                                      activeTrackColor: Colors.white,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: Colors.white,
                                      overlayColor: Colors.white24,
                                    ),
                                    child: Slider(
                                      value: value.clamp(0.0, 1.0),
                                      onChanged: (v) {
                                        handler.seek(Duration(
                                            milliseconds: (v * maxMs).round()));
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 8),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_fmt(pos),
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12)),
                                        Text(_fmt(total),
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Playback controls
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Rewind 10s
                          _ControlButton(
                            icon: Icons.replay_10,
                            size: 28,
                            onPressed: () {
                              final pos = handler.playbackState.valueOrNull
                                      ?.updatePosition ??
                                  Duration.zero;
                              final next = pos - const Duration(seconds: 10);
                              handler.seek(
                                  next.isNegative ? Duration.zero : next);
                            },
                          ),
                          // Play / Pause
                          StreamBuilder<PlaybackState>(
                            stream: handler.playbackState,
                            builder: (context, ps) {
                              final playing = ps.data?.playing ?? false;
                              return GestureDetector(
                                onTap: () =>
                                    playing ? handler.pause() : handler.play(),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.25),
                                        blurRadius: 24,
                                      )
                                    ],
                                  ),
                                  child: Icon(
                                    playing
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.black,
                                    size: 36,
                                  ),
                                ),
                              );
                            },
                          ),
                          // Forward 10s
                          _ControlButton(
                            icon: Icons.forward_10,
                            size: 28,
                            onPressed: () {
                              final state =
                                  handler.playbackState.valueOrNull;
                              final pos =
                                  state?.updatePosition ?? Duration.zero;
                              final total =
                                  handler.mediaItem.valueOrNull?.duration ??
                                      Duration.zero;
                              final next =
                                  pos + const Duration(seconds: 10);
                              handler.seek(next > total ? total : next);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Lyrics button
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white60,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => Container(
                            height: MediaQuery.of(context).size.height * 0.75,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(28)),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(28)),
                              child: DraggableScrollableSheet(
                                expand: false,
                                initialChildSize: 1,
                                builder: (_, scroll) =>
                                    _FullLyricsPane(
                                        track: track, scroll: scroll),
                              ),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.lyrics_outlined, size: 18),
                      label: const Text('Lyrics'),
                    ),
                  ],
                ),
              ),
            ],
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

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onPressed,
    this.size = 24,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70, size: size),
      onPressed: onPressed,
      splashRadius: 28,
    );
  }
}

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E2E),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : '♪',
          style: const TextStyle(
            fontSize: 80,
            color: Colors.white24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
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
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'LYRICS',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _load(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final synced = snap.data![0] as List<LyricLine>;
              final plain = snap.data![1] as String?;
              if (synced.isEmpty && (plain == null || plain.isEmpty)) {
                return const Center(
                    child: Text('No lyrics found',
                        style: TextStyle(color: Colors.white38)));
              }
              if (synced.isEmpty) {
                return ListView(
                  controller: widget.scroll,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(plain!,
                        style: const TextStyle(
                            color: Colors.white70, height: 1.7, fontSize: 15))
                  ],
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
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    itemCount: synced.length,
                    itemBuilder: (context, i) {
                      final line = synced[i];
                      final hl = i == active;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          line.text,
                          style: TextStyle(
                            fontSize: hl ? 19 : 15,
                            fontWeight:
                                hl ? FontWeight.w700 : FontWeight.w400,
                            color: hl
                                ? Colors.white
                                : Colors.white38,
                            height: 1.4,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
