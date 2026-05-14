import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

@JS('Spotify.Player')
extension type SpotifyPlayer._(JSObject _) implements JSObject {
  external factory SpotifyPlayer(PlayerOptions options);
  external JSPromise connect();
  external void disconnect();
  external void addListener(String eventName, JSFunction callback);
  external JSPromise pause();
  external JSPromise resume();
  external JSPromise togglePlay();
  external JSPromise seek(num positionMs);
  external JSPromise previousTrack();
  external JSPromise nextTrack();
}

@JS()
@anonymous
extension type PlayerOptions._(JSObject _) implements JSObject {
  external factory PlayerOptions({
    String name,
    JSFunction getOAuthToken,
    num volume,
  });
}

extension type WindowExtension._(JSObject _) implements JSObject {
  @JS('_spotifySDKReady')
  external JSAny get spotifySDKReady;
  @JS('_spotifySDKReadyCallbacks')
  external JSArray get spotifySDKReadyCallbacks;
}

class SpotifyWebPlaybackService {
  SpotifyPlayer? _player;
  String? _deviceId;
  String? _token;
.
  Future<void> init(
    String token,
    Function(Map<String, dynamic>) onStateChange,
  ) async {
    _token = token;

    final completer = Completer<void>();

    void setupPlayer() {
      _player = SpotifyPlayer(PlayerOptions(
        name: 'Music App',
        getOAuthToken: ((JSFunction cb) {
          cb.callAsFunction(null, token.toJS);
        }).toJS,
        volume: 1.0,
      ));

      _player!.addListener('ready', ((JSObject event) {
        final deviceIdJs = event.getProperty('device_id'.toJS);
        if (deviceIdJs is JSString) {
          _deviceId = deviceIdJs.toDart;
        }
        if (!completer.isCompleted) completer.complete();
      }).toJS);

      _player!.addListener('not_ready', ((JSObject _) {
        _deviceId = null;
      }).toJS);

      _player!.addListener('player_state_changed', ((JSObject? stateJs) {
        if (stateJs == null) return;
        final isPausedJs = stateJs.getProperty('paused'.toJS);
        final positionJs = stateJs.getProperty('position'.toJS);
        final durationJs = stateJs.getProperty('duration'.toJS);
        if (isPausedJs is JSBoolean &&
            positionJs is JSNumber &&
            durationJs is JSNumber) {
          onStateChange({
            'paused': isPausedJs.toDart,
            'position': positionJs.toDartInt,
            'duration': durationJs.toDartInt,
          });
        }
      }).toJS);

      _player!.connect();
    }

    final win = web.window as WindowExtension;
    final isReady = win.spotifySDKReady;
    if (isReady.isA<JSBoolean>() && (isReady as JSBoolean).toDart) {
      setupPlayer();
    } else {
      final callbacks = win.spotifySDKReadyCallbacks;
      callbacks.callMethod('push'.toJS, setupPlayer.toJS);
    }

    try {
      await completer.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      print('SpotifyWebPlaybackService: timeout waiting for SDK ready or device_id');
    }
  }

  Future<void> playUri(String uri) async {
    if (_deviceId == null || _token == null) return;
    final url = Uri.https('api.spotify.com', '/v1/me/player/play', {
      'device_id': _deviceId!,
    });
    await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'uris': [uri]}),
    );
  }

  Future<void> pause() async {
    await _player?.pause().toDart;
  }

  Future<void> resume() async {
    await _player?.resume().toDart;
  }

  Future<void> seek(Duration position) async {
    await _player?.seek(position.inMilliseconds).toDart;
  }
}
