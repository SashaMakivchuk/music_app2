import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/audio_provider.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/utils/media_item_track.dart';
import '../../../data/models/track_model.dart';
import '../logic/search_provider.dart';
import '../models/ai_message.dart';
import 'widgets/chat_bubble.dart';

class AiAgentScreen extends ConsumerStatefulWidget {
  const AiAgentScreen({super.key});

  @override
  ConsumerState<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends ConsumerState<AiAgentScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<AiMessage> _messages = [];
  bool _busy = false;

  Future<void> _send(String raw) async {
    final prompt = raw.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _messages.add(
        AiMessage(text: prompt, isUser: true, timestamp: DateTime.now()),
      );
      _controller.clear();
      _busy = true;
    });

    try {
      final fn = ref.read(cloudFunctionsRepositoryProvider);
      final result = await fn.musicAgentKeywords(prompt);

      // Show the AI's conversational reply in the chat
      setState(() {
        _messages.add(AiMessage(
          text: result.reply,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });

      if (result.keywords.isEmpty) return;

      final sound = ref.read(spotifyRepoProvider);
      final merged = <Track>[];
      final seen = <String>{};
      for (final p in result.keywords) {
        final list = await sound.searchTracks(p);
        for (final t in list) {
          if (seen.add(t.id)) merged.add(t);
        }
      }
      if (!mounted) return;
      if (merged.isEmpty) {
        setState(() {
          _messages.add(AiMessage(
            text: "Hmm, couldn't find tracks for those on Spotify. Try rephrasing?",
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _messages.add(AiMessage(
          text: 'Here are some picks 🎵',
          isUser: false,
          timestamp: DateTime.now(),
          tracks: merged.take(12).toList(),
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(
          AiMessage(
            text:
                'AI unavailable ($e). Deploy Cloud Function `musicAgent` with secret OPENAI_API_KEY.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent),
            SizedBox(width: 8),
            Text('Music AI Agent'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                return ChatBubble(message: message);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: const Border(top: BorderSide(color: Colors.grey)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Chill lo-fi for studying',
                      border: InputBorder.none,
                    ),
                    onSubmitted: _send,
                  ),
                ),
                IconButton(
                  icon: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Colors.deepPurpleAccent),
                  onPressed: _busy ? null : () => _send(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
