import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/track_model.dart';

class SoundCloudRepository {
  SoundCloudRepository()
      : _fn = FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _fn;

  String get clientId => dotenv.get('SOUNDCLOUD_CLIENT_ID', fallback: '');

  Future<List<Track>> searchTracks(String query) async {
    if (kIsWeb) return _searchViaProxy(query: query);
    if (clientId.isEmpty) return [];
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

  Future<List<Track>> fetchRecentTracks({int limit = 12}) async {
    if (kIsWeb) return _searchViaProxy(limit: limit);
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
        return body.map((e) => Track.fromMap(e as Map<String, dynamic>)).toList();
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

  // Proxy through Cloud Function for web (avoids CORS)
  Future<List<Track>> _searchViaProxy({String? query, int limit = 12}) async {
    try {
      final callable = _fn.httpsCallable('soundcloudSearch');
      final res = await callable.call<Map<String, dynamic>>({
        if (query != null) 'query': query,
        'limit': limit,
      });
      final tracks = res.data['tracks'] as List<dynamic>? ?? [];
      return tracks
          .map((e) => Track.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}