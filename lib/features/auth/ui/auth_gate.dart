import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/audio_provider.dart';
import '../../player/services/audio_handler.dart';
import '../../app/main_shell.dart';
import '../../app/widgets/playback_history_listener.dart';
import '../services/spotify_auth_service.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }
        
        final spotifyToken = ref.watch(spotifyAuthProvider);
        if (spotifyToken == null) {
          return const SpotifyConnectScreen();
        }

        // Initialize Spotify SDK on successful login
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final handler = ref.read(audioHandlerProvider) as MyAudioHandler;
          handler.initSpotify(spotifyToken);
        });

        return const PlaybackHistoryListener(
          child: MainShell(),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Auth error: $e')),
      ),
    );
  }
}

class SpotifyConnectScreen extends ConsumerWidget {
  const SpotifyConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            Text('Connect to Spotify', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            const Text('You need a Spotify Premium account to play music.'),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                try {
                  ref.read(spotifyAuthProvider.notifier).login();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              },
              child: const Text('Login with Spotify'),
            ),
          ],
        ),
      ),
    );
  }
}
