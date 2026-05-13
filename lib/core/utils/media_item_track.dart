import 'package:audio_service/audio_service.dart';

import '../../data/models/track_model.dart';

Track trackFromMediaItem(MediaItem m) {
  final ex = m.extras ?? {};
  return Track(
    id: m.id,
    title: m.title,
    artist: m.artist ?? 'Unknown',
    thumbnailUrl: m.artUri?.toString() ?? '',
    streamUrl: ex['streamUrl'] as String? ?? '',
    duration: m.duration ?? Duration.zero,
    localPath: ex['localPath'] as String?,
  );
}

Map<String, dynamic> trackExtras(Track t) => {
      'streamUrl': t.streamUrl,
      'localPath': t.localPath,
    };

MediaItem mediaItemForTrack(Track t) {
  return MediaItem(
    id: t.id,
    title: t.title,
    artist: t.artist,
    artUri: t.thumbnailUrl.isEmpty ? null : Uri.tryParse(t.thumbnailUrl),
    duration: t.duration,
    extras: trackExtras(t),
  );
}
