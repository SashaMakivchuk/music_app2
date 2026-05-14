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

  Uri playbackUri(String unusedId) {
    if (isLocal) {
      return Uri.file(localPath!);
    }
    // We store the Spotify URI (e.g. spotify:track:...) in streamUrl
    if (streamUrl.isEmpty) return Uri();
    return Uri.parse(streamUrl);
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    final artists = map['artists'] as List<dynamic>?;
    String artist = 'Unknown Artist';
    if (artists != null && artists.isNotEmpty) {
      artist = artists[0]['name'] as String? ?? artist;
    }
    
    final album = map['album'] as Map<String, dynamic>?;
    final images = album?['images'] as List<dynamic>?;
    String thumb = '';
    if (images != null && images.isNotEmpty) {
      thumb = images[0]['url'] as String? ?? '';
    }

    return Track(
      id: map['id'].toString(),
      title: map['name'] as String? ?? 'Unknown Title',
      artist: artist,
      thumbnailUrl: thumb,
      streamUrl: map['uri'] as String? ?? '', // Store Spotify URI here
      duration: Duration(milliseconds: (map['duration_ms'] as num?)?.toInt() ?? 0),
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
