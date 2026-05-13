import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/track_model.dart';

class SoundCloudRepository {
  String get clientId => dotenv.get('SOUNDCLOUD_CLIENT_ID', fallback: '');

  Future<List<Track>> searchTracks(String query) async {
    if (clientId.isEmpty) {
      return [];
    }
    final uri = Uri.https('api.soundcloud.com', '/tracks', {
      'q': query,
      'client_id': clientId,
    });
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data
            .map((e) => Track.fromMap(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetches a single page of trending-ish recent uploads (simple home filler).
  Future<List<Track>> fetchRecentTracks({int limit = 12}) async {
    if (clientId.isEmpty) return [];
    final uri = Uri.https('api.soundcloud.com', '/tracks', {
      'linked_partitioning': 'true',
      'limit': '$limit',
      'client_id': clientId,
    });
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final body = json.decode(response.body);
      if (body is List<dynamic>) {
        return body
            .map((e) => Track.fromMap(e as Map<String, dynamic>))
            .toList();
      }
      if (body is Map<String, dynamic> && body['collection'] is List) {
        return (body['collection'] as List<dynamic>)
            .map((e) => Track.fromMap(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
