import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

const _kClientId = '43ad5e4914584859815e5b9f6ab2e216';
const _kScopes =
    'streaming user-read-email user-read-private user-modify-playback-state user-read-playback-state user-read-currently-playing';

final spotifyAuthProvider =
    NotifierProvider<SpotifyAuthNotifier, String?>(() => SpotifyAuthNotifier());

class SpotifyAuthNotifier extends Notifier<String?> {
  @override
  String? build() {
    // First try to restore a previously saved token from this session
    final saved = web.window.sessionStorage.getItem('spotify_access_token');
    if (saved != null && saved.isNotEmpty) return saved;

    // Otherwise check if Spotify just redirected back with ?code=...
    _checkCallbackCode();
    return null;
  }

  /// Called on app start. If the URL has ?code=... it is a PKCE callback.
  void _checkCallbackCode() {
    final search = web.window.location.search;
    if (!search.contains('code=')) return;

    final params = Uri.splitQueryString(search.replaceFirst('?', ''));
    final code = params['code'];
    final returnedState = params['state'];
    final storedState = web.window.sessionStorage.getItem('spotify_state');
    final verifier = web.window.sessionStorage.getItem('spotify_pkce_verifier');

    if (code != null && verifier != null && returnedState == storedState) {
      // Clean the URL immediately so the code isn't reused on refresh
      web.window.history.replaceState(null, '', web.window.location.pathname);
      // Exchange the authorization code for an access token
      _exchangeCodeForToken(code, verifier);
    }
  }

  Future<void> _exchangeCodeForToken(String code, String verifier) async {
    final body = {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': _redirectUri,
      'client_id': _kClientId,
      'code_verifier': verifier,
    };

    final response =
        await _httpPost('https://accounts.spotify.com/api/token', body);

    if (response != null && response['access_token'] != null) {
      final token = response['access_token'] as String;
      web.window.sessionStorage.setItem('spotify_access_token', token);
      state = token;
    }
  }

  /// Redirects the browser to Spotify login with PKCE parameters.
  void login() {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    final stateParam = _randomString(16);

    web.window.sessionStorage.setItem('spotify_pkce_verifier', verifier);
    web.window.sessionStorage.setItem('spotify_state', stateParam);

    final url = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': _kClientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'scope': _kScopes,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'state': stateParam,
    });

    web.window.location.href = url.toString();
  }

  String get _redirectUri =>
      web.window.location.origin + web.window.location.pathname;

  // ── PKCE helpers ──────────────────────────────────────────────────────────

  String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rng = Random.secure();
    return List.generate(128, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  String _randomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── HTTP POST via XMLHttpRequest ──────────────────────────────────────────

  Future<Map<String, dynamic>?> _httpPost(
      String url, Map<String, String> body) async {
    final xhr = web.XMLHttpRequest();
    xhr.open('POST', url, false); // synchronous – safe in this context
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    final encoded = body.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    xhr.send(encoded.toJS);
    if (xhr.status == 200) {
      return json.decode(xhr.responseText) as Map<String, dynamic>;
    }
    return null;
  }
}
