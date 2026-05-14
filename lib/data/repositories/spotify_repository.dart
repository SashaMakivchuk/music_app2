import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track_model.dart';

class SpotifyRepository {
  SpotifyRepository(this._token);
  final String? _token;

  Future<List<Track>> searchTracks(String query) async {
    if (_token == null || query.isEmpty) return [];
    
    final uri = Uri.https('api.spotify.com', '/v1/search', {
      'q': query,
      'type': 'track',
      'limit': '20',
    });

    try {
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $_token',
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['tracks']['items'] as List<dynamic>? ?? [];
        return items.map((e) => Track.fromMap(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Track>> fetchRecentTracks({int limit = 12}) async {
    if (_token == null) return [];
    
    final uri = Uri.https('api.spotify.com', '/v1/me/player/recently-played', {
      'limit': '$limit',
    });

    try {
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $_token',
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        return items.map((e) {
          final trackData = e['track'] as Map<String, dynamic>;
          return Track.fromMap(trackData);
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
