import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/download_record.dart';
import '../models/track_model.dart';

class DownloadRepository {
  DownloadRepository(this._box);

  final Box<Map<dynamic, dynamic>> _box;
  final Dio _dio = Dio();

  static Future<DownloadRepository> open() async {
    final box = await Hive.openBox<Map<dynamic, dynamic>>('downloads');
    return DownloadRepository(box);
  }

  List<DownloadRecord> allDownloads() {
    return _box.values.map(DownloadRecord.fromMap).toList();
  }

  List<DownloadRecord> searchLocal(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];
    return allDownloads().where((d) {
      return d.title.toLowerCase().contains(q) ||
          d.artist.toLowerCase().contains(q);
    }).toList();
  }

  Future<DownloadRecord?> getById(String id) async {
    final m = _box.get(id);
    if (m == null) return null;
    return DownloadRecord.fromMap(m);
  }

  Future<void> remove(String id) async {
    final m = _box.get(id);
    final path = m?['localPath'] as String?;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    }
    await _box.delete(id);
  }

  /// Downloads remote stream to app documents. [streamUrl] should be
  /// already resolved with client_id when needed.
  Future<DownloadRecord> downloadTrack(Track track) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/music_downloads');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final ext = 'mp3';
    final filePath = '${folder.path}/${track.id}.$ext';
    final uri = track.playbackUri(dotenv.get('SOUNDCLOUD_CLIENT_ID', fallback: ''));
    await _dio.downloadUri(uri, filePath);
    final rec = DownloadRecord(
      id: track.id,
      title: track.title,
      artist: track.artist,
      localPath: filePath,
      thumbnailUrl: track.thumbnailUrl.isEmpty ? null : track.thumbnailUrl,
      durationMs: track.duration.inMilliseconds,
    );
    await _box.put(track.id, rec.toMap());
    return rec;
  }
}
