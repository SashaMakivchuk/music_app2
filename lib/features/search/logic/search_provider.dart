import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/track_model.dart';
import '../../../data/repositories/spotify_repository.dart';
import '../../auth/services/spotify_auth_service.dart';

final spotifyRepoProvider = Provider<SpotifyRepository>((ref) {
  final token = ref.watch(spotifyAuthProvider);
  return SpotifyRepository(token);
});

final searchResultsProvider =
    FutureProvider.family<List<Track>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repo = ref.read(spotifyRepoProvider);
  return repo.searchTracks(query);
});
