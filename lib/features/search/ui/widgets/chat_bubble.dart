import 'package:flutter/material.dart';
import 'package:music_app/features/search/models/ai_message.dart';

class ChatBubble extends StatelessWidget {
  final AiMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final alignRight = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // The Bubble
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: alignRight ? Colors.deepPurple[700] : Colors.grey[800],
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: alignRight ? const Radius.circular(0) : const Radius.circular(16),
                bottomLeft: alignRight ? const Radius.circular(16) : const Radius.circular(0),
              ),
            ),
            child: Text(
              message.text,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          // Optional Timestamp
          const SizedBox(height: 4),
          Text(
            "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
    );
  }
}