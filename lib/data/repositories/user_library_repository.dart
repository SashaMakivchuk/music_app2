import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/utils/doc_id.dart';
import '../models/track_model.dart';

class UserLibraryRepository {
  UserLibraryRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _userCol(String uid) =>
      _db.collection('users').doc(uid).collection('likes');

  CollectionReference<Map<String, dynamic>> _historyCol(String uid) =>
      _db.collection('users').doc(uid).collection('listen_history');

  CollectionReference<Map<String, dynamic>> _albumsCol(String uid) =>
      _db.collection('users').doc(uid).collection('favourite_albums');

  CollectionReference<Map<String, dynamic>> _playlistsCol(String uid) =>
      _db.collection('users').doc(uid).collection('playlists');

  CollectionReference<Map<String, dynamic>> _downloadsMetaCol(String uid) =>
      _db.collection('users').doc(uid).collection('downloads');

  String? get _uid => _auth.currentUser?.uid;

  Future<void> ensureUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfileFields({
    String? displayName,
    String? photoUrl,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = _db.collection('users').doc(uid);
    await ref.set({
      if (displayName != null) 'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<bool> watchIsLiked(String trackId) {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(false);
    }
    final id = firestoreSafeDocId(trackId);
    return _userCol(uid).doc(id).snapshots().map((s) => s.exists);
  }

  Future<bool> isLiked(String trackId) async {
    final uid = _uid;
    if (uid == null) return false;
    final id = firestoreSafeDocId(trackId);
    final s = await _userCol(uid).doc(id).get();
    return s.exists;
  }

  Future<void> setLiked(Track track, bool liked) async {
    final uid = _uid;
    if (uid == null) return;
    final id = firestoreSafeDocId(track.id);
    final ref = _userCol(uid).doc(id);
    if (!liked) {
      await ref.delete();
      return;
    }
    await ref.set({
      'trackId': track.id,
      'title': track.title,
      'artist': track.artist,
      'thumbnailUrl': track.thumbnailUrl,
      'streamUrl': track.streamUrl,
      'durationMs': track.duration.inMilliseconds,
      'localPath': track.localPath,
      'likedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchLikes() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(<Map<String, dynamic>>[]);
    }
    return _userCol(uid)
        .orderBy('likedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Future<void> logListen(Track track) async {
    final uid = _uid;
    if (uid == null) return;
    await _historyCol(uid).add({
      'trackId': track.id,
      'title': track.title,
      'artist': track.artist,
      'thumbnailUrl': track.thumbnailUrl,
      'streamUrl': track.streamUrl,
      'durationMs': track.duration.inMilliseconds,
      'localPath': track.localPath,
      'playedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addFavouriteAlbum({
    required String key,
    required String title,
    required String artist,
    String? coverUrl,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final id = firestoreSafeDocId(key);
    await _albumsCol(uid).doc(id).set({
      'title': title,
      'artist': artist,
      'coverUrl': coverUrl,
      'savedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> watchFavouriteAlbums() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(<Map<String, dynamic>>[]);
    }
    return _albumsCol(uid)
        .orderBy('savedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Future<void> syncDownloadMetadata({
    required String trackId,
    required String title,
    required String artist,
    String? localPath,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final id = firestoreSafeDocId(trackId);
    await _downloadsMetaCol(uid).doc(id).set({
      'trackId': trackId,
      'title': title,
      'artist': artist,
      'localPath': localPath,
      'syncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> createPlaylist(String name) async {
    final uid = _uid;
    if (uid == null) return;
    await _playlistsCol(uid).add({
      'name': name,
      'trackIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchPlaylists() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(<Map<String, dynamic>>[]);
    }
    return _playlistsCol(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
