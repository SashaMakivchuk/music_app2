import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'spotify_web_playback_service.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.durationStream.listen((d) {
      final current = mediaItem.value;
      if (current != null && d != null && !_isSpotifyPlaying) {
        if (current.duration != d) {
          mediaItem.add(current.copyWith(duration: d));
        }
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final SpotifyWebPlaybackService _spotifyService = SpotifyWebPlaybackService();
  bool _isSpotifyPlaying = false;
  bool _isSpotifyInitialized = false;

  Future<void> initSpotify(String token) async {
    if (_isSpotifyInitialized) return;
    _isSpotifyInitialized = true;
    
    await _spotifyService.init(token, (state) {
      // Update playback state from Spotify
      final isPaused = state['paused'] as bool;
      final positionMs = state['position'] as int;
      final durationMs = state['duration'] as int;

      final current = mediaItem.value;
      if (current != null && durationMs > 0) {
        final d = Duration(milliseconds: durationMs);
        if (current.duration != d) {
          mediaItem.add(current.copyWith(duration: d));
        }
      }

      playbackState.add(PlaybackState(
        controls: [
          MediaControl.rewind,
          if (isPaused) MediaControl.play else MediaControl.pause,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 3],
        processingState: AudioProcessingState.ready,
        playing: !isPaused,
        updatePosition: Duration(milliseconds: positionMs),
        bufferedPosition: Duration(milliseconds: positionMs),
        speed: 1.0,
      ));
    });
  }

  Stream<Duration?> get durationStream => _isSpotifyPlaying 
      ? Stream.value(mediaItem.value?.duration) 
      : _player.durationStream;

  Stream<Duration> get positionStream => _player.positionStream; // Spotify SDK doesn't stream position frequently, might need a timer if required.

  AudioPlayer get player => _player;

  @override
  Future<void> play() async {
    if (_isSpotifyPlaying) {
      await _spotifyService.resume();
    } else {
      await _player.play();
    }
  }

  @override
  Future<void> pause() async {
    if (_isSpotifyPlaying) {
      await _spotifyService.pause();
    } else {
      await _player.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_isSpotifyPlaying) {
      await _spotifyService.seek(position);
    } else {
      await _player.seek(position);
    }
  }

  @override
  Future<void> stop() async {
    if (_isSpotifyPlaying) {
      await _spotifyService.pause();
    } else {
      await _player.stop();
    }
    mediaItem.add(null);
    queue.add(const []);
  }

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) async {
    final item = extras?['mediaItem'] as MediaItem?;
    
    if (item != null) {
      queue.add([item]);
      mediaItem.add(item);
    } else {
      queue.add(const []);
      mediaItem.add(null);
    }

    final uriString = uri.toString();
    if (uriString.startsWith('spotify:track:')) {
      _isSpotifyPlaying = true;
      await _player.stop(); // Stop local playback if any
      await _spotifyService.playUri(uriString);
      // Playback state will be updated by Spotify listener
    } else {
      _isSpotifyPlaying = false;
      final source = AudioSource.uri(uri, tag: item);
      await _player.setAudioSource(source);
      return _player.play();
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
