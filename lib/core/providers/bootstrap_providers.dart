import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/cloud_functions_repository.dart';
import '../../data/repositories/download_repository.dart';
import '../../data/repositories/lyrics_repository.dart';
import '../../data/repositories/user_library_repository.dart';
import 'audio_provider.dart';
import 'auth_provider.dart';

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  throw UnimplementedError('override downloadRepositoryProvider in main');
});

final userLibraryRepositoryProvider = Provider<UserLibraryRepository>((ref) {
  return UserLibraryRepository(
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
  );
});

final lyricsRepositoryProvider = Provider((ref) => LyricsRepository());

final cloudFunctionsRepositoryProvider = Provider((ref) {
  return CloudFunctionsRepository();
});

final likeStatusProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, trackId) {
  final user = ref.watch(authStateProvider).asUser;
  if (user == null) {
    return Stream.value(false);
  }
  return ref.watch(userLibraryRepositoryProvider).watchIsLiked(trackId);
});

final currentMediaItemProvider = StreamProvider((ref) {
  final h = ref.watch(audioHandlerProvider);
  return h.mediaItem;
});
