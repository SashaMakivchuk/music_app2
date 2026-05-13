import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lyric_line.dart';

class LyricsRepository {
  static const _base = 'https://lrclib.net/api';

  Future<List<LyricLine>> fetchSyncedLines({
    required String artist,
    required String title,
    int? durationSeconds,
  }) async {
    final params = <String, String>{
      'artist_name': artist,
      'track_name': title,
      if (durationSeconds != null) 'duration': '$durationSeconds',
    };
    final uri = Uri.parse('$_base/get').replace(queryParameters: params);
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final map = json.decode(res.body) as Map<String, dynamic>?;
    final synced = map?['syncedLyrics'] as String?;
    if (synced == null || synced.isEmpty) return [];
    return _parseLrc(synced);
  }

  Future<String?> fetchPlainLyrics({
    required String artist,
    required String title,
    int? durationSeconds,
  }) async {
    final params = <String, String>{
      'artist_name': artist,
      'track_name': title,
      if (durationSeconds != null) 'duration': '$durationSeconds',
    };
    final uri = Uri.parse('$_base/get').replace(queryParameters: params);
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final map = json.decode(res.body) as Map<String, dynamic>?;
    final plain = map?['plainLyrics'] as String?;
    if (plain != null && plain.isNotEmpty) return plain;
    return null;
  }

  List<LyricLine> _parseLrc(String lrc) {
    final re = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]([^\r\n]*)');
    final lines = <LyricLine>[];
    for (final m in re.allMatches(lrc)) {
      final min = int.tryParse(m.group(1)!) ?? 0;
      final sec = int.tryParse(m.group(2)!) ?? 0;
      final frac = m.group(3);
      int ms = 0;
      if (frac != null && frac.isNotEmpty) {
        final padded = frac.padRight(3, '0').substring(0, 3);
        ms = int.tryParse(padded) ?? 0;
      }
      final text = (m.group(4) ?? '').trim();
      if (text.isEmpty) continue;
      lines.add(
        LyricLine(
          time: Duration(minutes: min, seconds: sec, milliseconds: ms),
          text: text,
        ),
      );
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }
}
