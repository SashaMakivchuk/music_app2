import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/core/providers/audio_provider.dart';
import 'package:music_app/core/utils/media_item_track.dart';
import 'package:music_app/data/models/track_model.dart';
import 'package:music_app/features/search/models/ai_message.dart';

class ChatBubble extends ConsumerWidget {
  final AiMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alignRight = message.isUser;
    final hasTracks = message.tracks.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Text bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            decoration: BoxDecoration(
              color: alignRight
                  ? Colors.deepPurple[700]
                  : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomRight: alignRight
                    ? const Radius.circular(4)
                    : const Radius.circular(18),
                bottomLeft: alignRight
                    ? const Radius.circular(18)
                    : const Radius.circular(4),
              ),
            ),
            child: Text(
              message.text,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            ),
          ),

          // Inline track list (only for AI recommendation messages)
          if (hasTracks) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                children: message.tracks.take(12).map((track) {
                  return _TrackCard(
                    track: track,
                    onTap: () {
                      ref.read(audioHandlerProvider).playFromUri(
                            track.playbackUri(''),
                            {'mediaItem': mediaItemForTrack(track)},
                          );
                    },
                  );
                }).toList(),
              ),
            ),
          ],

          // Timestamp
          const SizedBox(height: 4),
          Text(
            "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: track.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      track.thumbnailUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _artPlaceholder(),
                    )
                  : _artPlaceholder(),
            ),
            const SizedBox(width: 12),
            // Title + artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.play_circle_outline,
                color: Colors.deepPurpleAccent, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _artPlaceholder() => Container(
        width: 44,
        height: 44,
        color: const Color(0xFF2A2A3E),
        child: const Icon(Icons.music_note, color: Colors.white24, size: 20),
      );
}