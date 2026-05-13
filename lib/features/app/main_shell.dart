import 'package:audio_service/audio_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/providers/audio_provider.dart';
import '../../../core/utils/media_item_track.dart';
import '../../../data/models/lyric_line.dart';
import '../../../data/models/track_model.dart';
import '../favourites/ui/favourites_screen.dart';
import '../home/ui/home_screen.dart';
import '../library/ui/library_screen.dart';
import '../player/ui/full_player_screen.dart';
import '../search/ui/search_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UserAccountsDrawerHeader(
              currentAccountPicture: CircleAvatar(
                backgroundImage:
                    user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person, size: 36)
                    : null,
              ),
              accountName: Text(user?.displayName ?? 'Listener'),
              accountEmail: Text(user?.email ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Update avatar'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final x = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 85,
                );
                if (x == null || user == null) return;
                final uid = user.uid;
                final refSt =
                    FirebaseStorage.instance.ref().child('avatars/$uid/profile.jpg');
                await refSt.putData(await x.readAsBytes());
                final url = await refSt.getDownloadURL();
                await user.updatePhotoURL(url);
                await ref.read(userLibraryRepositoryProvider).updateProfileFields(
                      photoUrl: url,
                    );
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.pop(context);
                await GoogleSignIn.instance.signOut();
                await ref.read(firebaseAuthProvider).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const SearchScreen(),
      const LibraryScreen(),
      const FavouritesScreen(),
    ];
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Music App'),
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: pages,
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _MiniPlayerBar(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
              icon: Icon(Icons.library_music_outlined), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Saved'),
        ],
      ),
    );
  }
}

class _MiniPlayerBar extends ConsumerWidget {
  const _MiniPlayerBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snap) {
        final item = snap.data;
        if (item == null) {
          return const SizedBox.shrink();
        }
        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, ps) {
            final playing = ps.data?.playing ?? false;
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 72),
              child: Material(
                elevation: 8,
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FullPlayerScreen(),
                      ),
                    );
                  },
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        if (item.artUri != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.artUri.toString(),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.music_note),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.music_note),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              Text(
                                item.artist ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                          onPressed: () {
                            if (playing) {
                              handler.pause();
                            } else {
                              handler.play();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.subtitles_outlined),
                          tooltip: 'Lyrics',
                          onPressed: () {
                            final t = trackFromMediaItem(item);
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: const Color(0xFF121212),
                              builder: (ctx) => DraggableScrollableSheet(
                                expand: false,
                                initialChildSize: 0.55,
                                minChildSize: 0.35,
                                maxChildSize: 0.9,
                                builder: (_, scroll) =>
                                    _LyricsSheet(track: t, scroll: scroll),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LyricsSheet extends ConsumerStatefulWidget {
  const _LyricsSheet({required this.track, required this.scroll});

  final Track track;
  final ScrollController scroll;

  @override
  ConsumerState<_LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends ConsumerState<_LyricsSheet> {
  Future<List<dynamic>>? _future;

  Future<List<dynamic>> _load() {
    _future ??= () {
      final lyrics = ref.read(lyricsRepositoryProvider);
      return Future.wait([
        lyrics.fetchSyncedLines(
          artist: widget.track.artist,
          title: widget.track.title,
          durationSeconds: widget.track.duration.inSeconds,
        ),
        lyrics.fetchPlainLyrics(
          artist: widget.track.artist,
          title: widget.track.title,
          durationSeconds: widget.track.duration.inSeconds,
        ),
      ]);
    }();
    return _future!;
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.watch(audioHandlerProvider);
    return FutureBuilder<List<dynamic>>(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final synced = snap.data![0] as List<LyricLine>;
        final plain = snap.data![1] as String?;
        if (synced.isEmpty && (plain == null || plain.isEmpty)) {
          return const Center(child: Text('No lyrics found (LRCLIB)'));
        }
        if (synced.isEmpty) {
          return ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.all(20),
            children: [
              Text(plain!, style: const TextStyle(height: 1.5)),
            ],
          );
        }
        return StreamBuilder<Duration>(
          stream: handler.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            int active = 0;
            for (var i = 0; i < synced.length; i++) {
              if (synced[i].time <= pos) active = i;
            }
            return ListView.builder(
              controller: widget.scroll,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: synced.length,
              itemBuilder: (context, i) {
                final line = synced[i];
                final hl = i == active;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    line.text,
                    style: TextStyle(
                      fontSize: hl ? 18 : 15,
                      fontWeight: hl ? FontWeight.w700 : FontWeight.w400,
                      color: hl ? Colors.deepPurpleAccent : Colors.white70,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
