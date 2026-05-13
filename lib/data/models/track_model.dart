class Track {
  final String id;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final String streamUrl;
  final Duration duration;
  final String? localPath;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.streamUrl,
    required this.duration,
    this.localPath,
  });

  bool get isLocal => localPath != null && localPath!.isNotEmpty;

  Uri playbackUri(String soundCloudClientId) {
    if (isLocal) {
      return Uri.file(localPath!);
    }
    var url = streamUrl;
    if (url.isEmpty) return Uri();
    if (soundCloudClientId.isNotEmpty && !url.contains('client_id=')) {
      final sep = url.contains('?') ? '&' : '?';
      url = '$url${sep}client_id=$soundCloudClientId';
    }
    return Uri.parse(url);
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    final user = map['user'];
    String artist = 'Unknown Artist';
    if (user is Map<String, dynamic>) {
      artist = user['username'] as String? ?? artist;
    }
    return Track(
      id: map['id'].toString(),
      title: map['title'] as String? ?? 'Unknown Title',
      artist: artist,
      thumbnailUrl: (map['artwork_url'] as String?) ?? '',
      streamUrl: (map['stream_url'] as String?) ?? '',
      duration: Duration(milliseconds: (map['duration'] as num?)?.toInt() ?? 0),
    );
  }

  factory Track.fromDownload({
    required String id,
    required String title,
    required String artist,
    required String thumbnailUrl,
    required String localPath,
    required Duration duration,
  }) {
    return Track(
      id: id,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      streamUrl: '',
      duration: duration,
      localPath: localPath,
    );
  }
}
