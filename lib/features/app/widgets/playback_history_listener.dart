import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/utils/media_item_track.dart';

/// Logs each distinct [MediaItem.id] to Firestore [listen_history] when signed in.
class PlaybackHistoryListener extends ConsumerStatefulWidget {
  const PlaybackHistoryListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PlaybackHistoryListener> createState() =>
      _PlaybackHistoryListenerState();
}

class _PlaybackHistoryListenerState
    extends ConsumerState<PlaybackHistoryListener> {
  String? _lastLoggedId;

  @override
  Widget build(BuildContext context) {
    ref.listen(currentMediaItemProvider, (previous, next) {
      next.whenData((MediaItem? item) async {
        if (item == null) {
          _lastLoggedId = null;
          return;
        }
        if (_lastLoggedId == item.id) return;
        _lastLoggedId = item.id;
        final track = trackFromMediaItem(item);
        await ref.read(userLibraryRepositoryProvider).logListen(track);
      });
    });
    return widget.child;
  }
}
