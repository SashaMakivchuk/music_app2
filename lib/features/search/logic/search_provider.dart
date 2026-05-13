import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/track_model.dart';
import '../../../data/repositories/soundcloud_repository.dart';

final soundCloudRepoProvider = Provider<SoundCloudRepository>((ref) {
  return SoundCloudRepository();
});

final searchResultsProvider =
    FutureProvider.family<List<Track>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repo = ref.read(soundCloudRepoProvider);
  return repo.searchTracks(query);
});
