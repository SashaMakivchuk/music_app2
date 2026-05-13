class DownloadRecord {
  final String id;
  final String title;
  final String artist;
  final String localPath;
  final String? thumbnailUrl;
  final int durationMs;

  const DownloadRecord({
    required this.id,
    required this.title,
    required this.artist,
    required this.localPath,
    this.thumbnailUrl,
    required this.durationMs,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'localPath': localPath,
        'thumbnailUrl': thumbnailUrl,
        'durationMs': durationMs,
      };

  static DownloadRecord fromMap(Map<dynamic, dynamic> m) {
    return DownloadRecord(
      id: m['id'] as String? ?? '',
      title: m['title'] as String? ?? 'Unknown',
      artist: m['artist'] as String? ?? 'Unknown',
      localPath: m['localPath'] as String? ?? '',
      thumbnailUrl: m['thumbnailUrl'] as String?,
      durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
    );
  }
}
