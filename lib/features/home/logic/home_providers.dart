import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../data/models/track_model.dart';
import '../../search/logic/search_provider.dart';

final homeFeedTracksProvider = FutureProvider<List<Track>>((ref) async {
  final sound = ref.watch(soundCloudRepoProvider);
  final user = ref.watch(authStateProvider).asUser;
  if (user != null) {
    try {
      final fn = ref.watch(cloudFunctionsRepositoryProvider);
      final qs = await fn.getRecommendationQueries();
      if (qs.isNotEmpty) {
        final lists = await Future.wait(
          qs.take(4).map((q) => sound.searchTracks(q)),
        );
        final seen = <String>{};
        final out = <Track>[];
        for (final list in lists) {
          for (final t in list) {
            if (seen.add(t.id)) out.add(t);
          }
        }
        if (out.isNotEmpty) return out.take(24).toList();
      }
    } catch (_) {
      // Callable unavailable, wrong region, or secret not configured.
    }
  }
  return sound.fetchRecentTracks(limit: 24);
});
