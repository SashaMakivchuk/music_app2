import '../../../data/models/track_model.dart';

class AiMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Track> tracks; // non-empty = this message contains track recommendations

  AiMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.tracks = const [],
  });
}