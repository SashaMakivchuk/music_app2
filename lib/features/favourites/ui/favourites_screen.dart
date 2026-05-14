import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/audio_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/utils/media_item_track.dart';
import '../../../data/models/track_model.dart';
import '../../library/logic/library_providers.dart';
import '../../search/logic/search_provider.dart';

final likedTracksProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).asUser;
  if (user == null) {
    return Stream.value(<Map<String, dynamic>>[]);
  }
  return ref.watch(userLibraryRepositoryProvider).watchLikes();
});

class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  Track _trackFromLike(Map<String, dynamic> m) {
    return Track(
      id: m['trackId'] as String? ?? '',
      title: m['title'] as String? ?? '',
      artist: m['artist'] as String? ?? '',
      thumbnailUrl: m['thumbnailUrl'] as String? ?? '',
      streamUrl: m['streamUrl'] as String? ?? '',
      duration: Duration(
        milliseconds: (m['durationMs'] as num?)?.toInt() ?? 0,
      ),
      localPath: m['localPath'] as String?,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likes = ref.watch(likedTracksProvider);
    final albums = ref.watch(favouriteAlbumsProvider);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
        children: [
          const ListTile(
            title: Text('Liked tracks',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          likes.when(
            data: (list) {
              if (list.isEmpty) {
                return const ListTile(
                  title: Text('No likes yet. Use ⋮ on SoundCloud results.'),
                );
              }
              return Column(
                children: list
                    .map(
                      (m) => ListTile(
                        leading: (m['thumbnailUrl'] as String?)?.isNotEmpty == true
                            ? Image.network(
                                (m['thumbnailUrl'] as String)
                                    .replaceAll('-large', '-t200x200'),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.favorite),
                              )
                            : const Icon(Icons.favorite),
                        title: Text(m['title'] as String? ?? ''),
                        subtitle: Text(m['artist'] as String? ?? ''),
                        onTap: () {
                          final t = _trackFromLike(m);
                          ref.read(audioHandlerProvider).playFromUri(
                                t.playbackUri(''),
                                {'mediaItem': mediaItemForTrack(t)},
                              );
                        },
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Likes error: $e'),
          ),
          const Divider(height: 32),
          const ListTile(
            title: Text('Favourite albums',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          albums.when(
            data: (list) {
              if (list.isEmpty) {
                return const ListTile(
                  title: Text('Save artists from search ⋮ menu.'),
                );
              }
              return Column(
                children: list
                    .map(
                      (a) => ListTile(
                        leading: const Icon(Icons.album),
                        title: Text(a['title'] as String? ?? ''),
                        subtitle: Text(a['artist'] as String? ?? ''),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Albums error: $e'),
          ),
        ],
      ),
    );
  }
}
