import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/audio_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/utils/media_item_track.dart';
import '../../../data/models/download_record.dart';
import '../../../data/models/track_model.dart';
import '../logic/library_providers.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadRepositoryProvider).allDownloads();
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Downloads'),
              Tab(text: 'Albums'),
              Tab(text: 'Playlists'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _DownloadsTab(
                  downloads: downloads,
                  onPlay: (d) {
                    final t = Track.fromDownload(
                      id: d.id,
                      title: d.title,
                      artist: d.artist,
                      thumbnailUrl: d.thumbnailUrl ?? '',
                      localPath: d.localPath,
                      duration: Duration(milliseconds: d.durationMs),
                    );
                    ref.read(audioHandlerProvider).playFromUri(
                          t.playbackUri(''),
                          {'mediaItem': mediaItemForTrack(t)},
                        );
                  },
                  onDelete: (id) async {
                    await ref.read(downloadRepositoryProvider).remove(id);
                    setState(() {});
                  },
                ),
                _AlbumsTab(uid: uid),
                const _PlaylistsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadsTab extends StatelessWidget {
  const _DownloadsTab({
    required this.downloads,
    required this.onPlay,
    required this.onDelete,
  });

  final List<DownloadRecord> downloads;
  final void Function(DownloadRecord) onPlay;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    if (downloads.isEmpty) {
      return const Center(child: Text('No downloads yet. Use ⋮ on a search result.'));
    }
    return ListView.builder(
      itemCount: downloads.length,
      itemBuilder: (context, i) {
        final d = downloads[i];
        return ListTile(
          leading: const Icon(Icons.download_done),
          title: Text(d.title),
          subtitle: Text(d.artist),
          onTap: () => onPlay(d),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => onDelete(d.id),
          ),
        );
      },
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab({required this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (uid == null) {
      return const Center(child: Text('Sign in to sync favourite albums.'));
    }
    final grouped = <String, List<DownloadRecord>>{};
    for (final d in ref.watch(downloadRepositoryProvider).allDownloads()) {
      grouped.putIfAbsent(d.artist, () => []).add(d);
    }
    final favs = ref.watch(favouriteAlbumsProvider);
    return favs.when(
      data: (favList) {
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text('Saved albums',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ...favList.map(
              (a) => ListTile(
                leading: const Icon(Icons.album),
                title: Text(a['title'] as String? ?? ''),
                subtitle: Text(a['artist'] as String? ?? ''),
              ),
            ),
            const Divider(height: 32),
            const Text('From downloads (by artist)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ...grouped.entries.map(
              (e) => ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(e.key),
                subtitle: Text('${e.value.length} tracks'),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in to use playlists.'));
    }
    final playlists = ref.watch(userPlaylistsProvider);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              final name = await showDialog<String>(
                context: context,
                builder: (ctx) {
                  final c = TextEditingController();
                  return AlertDialog(
                    title: const Text('Playlist name'),
                    content: TextField(controller: c),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, c.text.trim()),
                        child: const Text('Create'),
                      ),
                    ],
                  );
                },
              );
              if (name != null && name.isNotEmpty) {
                await ref
                    .read(userLibraryRepositoryProvider)
                    .createPlaylist(name);
                ref.invalidate(userPlaylistsProvider);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('New playlist'),
          ),
        ),
        Expanded(
          child: playlists.when(
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('No playlists yet.'));
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final p = list[i];
                  return ListTile(
                    leading: const Icon(Icons.queue_music),
                    title: Text(p['name'] as String? ?? 'Playlist'),
                    subtitle: Text(
                        '${(p['trackIds'] as List?)?.length ?? 0} tracks'),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
        ),
      ],
    );
  }
}
