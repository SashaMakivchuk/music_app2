import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/audio_provider.dart';
import '../../../core/utils/media_item_track.dart';
import '../../../data/models/track_model.dart';
import '../../search/logic/search_provider.dart';
import '../logic/home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedTracksProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeFeedTracksProvider);
        },
        child: feed.when(
          data: (tracks) {
            if (tracks.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'No recommendations yet.\n'
                      'Add SOUNDCLOUD_CLIENT_ID to .env and sign in for AI feed.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              itemCount: tracks.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'For you',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  );
                }
                final t = tracks[i - 1];
                return _TrackTile(track: t);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Feed error: $e')),
        ),
      ),
    );
  }
}

class _TrackTile extends ConsumerWidget {
  const _TrackTile({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: track.thumbnailUrl.isEmpty
          ? const Icon(Icons.music_note)
          : Image.network(
              track.thumbnailUrl.replaceAll('-large', '-t200x200'),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
            ),
      title: Text(track.title),
      subtitle: Text(track.artist),
      onTap: () {
        final uri = track.playbackUri('');
        ref.read(audioHandlerProvider).playFromUri(
              uri,
              {'mediaItem': mediaItemForTrack(track)},
            );
      },
    );
  }
}
