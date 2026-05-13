import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/bootstrap_providers.dart';

final favouriteAlbumsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).asUser;
  if (user == null) {
    return Stream.value(<Map<String, dynamic>>[]);
  }
  return ref.watch(userLibraryRepositoryProvider).watchFavouriteAlbums();
});

final userPlaylistsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).asUser;
  if (user == null) {
    return Stream.value(<Map<String, dynamic>>[]);
  }
  return ref.watch(userLibraryRepositoryProvider).watchPlaylists();
});
