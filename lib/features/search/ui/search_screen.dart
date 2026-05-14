import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/audio_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/utils/media_item_track.dart';
import '../../../data/models/download_record.dart';
import '../../../data/models/track_model.dart';
import '../logic/search_provider.dart';
import 'ai_agent_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDownload(Track track) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Downloading…')));
      await ref.read(downloadRepositoryProvider).downloadTrack(track);
      final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
      if (uid != null) {
        await ref.read(userLibraryRepositoryProvider).syncDownloadMetadata(
              trackId: track.id,
              title: track.title,
              artist: track.artist,
            );
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('Saved to library')));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _toggleLike(Track track) async {
    final repo = ref.read(userLibraryRepositoryProvider);
    final liked = await repo.isLiked(track.id);
    await repo.setLiked(track, !liked);
  }

  Future<void> _favAlbum(Track track) async {
    await ref.read(userLibraryRepositoryProvider).addFavouriteAlbum(
          key: track.artist,
          title: '${track.artist} — collection',
          artist: track.artist,
          coverUrl: track.thumbnailUrl.isEmpty ? null : track.thumbnailUrl,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Artist saved to albums')),
      );
    }
  }

  void _play(Track track) {
    final uri = track.playbackUri('');
    ref.read(audioHandlerProvider).playFromUri(
          uri,
          {'mediaItem': mediaItemForTrack(track)},
        );
  }

  void _playLocal(DownloadRecord d) {
    final track = Track.fromDownload(
      id: d.id,
      title: d.title,
      artist: d.artist,
      thumbnailUrl: d.thumbnailUrl ?? '',
      localPath: d.localPath,
      duration: Duration(milliseconds: d.durationMs),
    );
    ref.read(audioHandlerProvider).playFromUri(
          track.playbackUri(''),
          {'mediaItem': mediaItemForTrack(track)},
        );
  }

  @override
  Widget build(BuildContext context) {
    final remote = ref.watch(searchResultsProvider(_query));
    final local = _query.trim().isEmpty
        ? <DownloadRecord>[]
        : ref.watch(downloadRepositoryProvider).searchLocal(_query);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'Spotify + your downloads…',
            border: InputBorder.none,
          ),
          onSubmitted: (v) => setState(() => _query = v.trim()),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _query = _controller.text.trim()),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  height: MediaQuery.of(context).size.height * 0.9,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: const ClipRRect(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                    child: AiAgentScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: remote.when(
        data: (tracks) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              if (local.isNotEmpty) ...[
                const ListTile(
                  title: Text('On this device',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...local.map(
                  (d) => ListTile(
                    leading: const Icon(Icons.download_done),
                    title: Text(d.title),
                    subtitle: Text(d.artist),
                    onTap: () => _playLocal(d),
                  ),
                ),
                const Divider(),
              ],
              const ListTile(
                title: Text('Spotify',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (tracks.isEmpty && _query.isNotEmpty)
                const ListTile(
                  title: Text('No results'),
                ),
              ...tracks.map(
                (track) => ListTile(
                  leading: track.thumbnailUrl.isEmpty
                      ? const Icon(Icons.music_note)
                      : Image.network(
                          track.thumbnailUrl.replaceAll('-large', '-t200x200'),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.music_note),
                        ),
                  title: Text(track.title),
                  subtitle: Text(track.artist),
                  onTap: () => _play(track),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'dl') await _onDownload(track);
                      if (v == 'like') await _toggleLike(track);
                      if (v == 'alb') await _favAlbum(track);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'dl', child: Text('Download')),
                      PopupMenuItem(value: 'like', child: Text('Like / unlike')),
                      PopupMenuItem(
                          value: 'alb', child: Text('Save artist to albums')),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
