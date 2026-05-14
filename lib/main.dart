import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/providers/audio_provider.dart';
import 'core/providers/bootstrap_providers.dart';
import 'data/repositories/download_repository.dart';
import 'features/auth/ui/auth_gate.dart';
import 'features/player/services/audio_handler.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Load Environment
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint("Warning: .env file not found. Ensure it is in assets.");
  }

  // 2. Initialize Firebase (CRITICAL for Web)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Initialize Hive
  await Hive.initFlutter();
  final downloadRepo = await DownloadRepository.open();

  // 4. Audio Service (Wrap in try-catch for Web autoplay policies)
  late AudioHandler handler;
  try {
    handler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.alexandra.musicapp.audio',
        androidNotificationChannelName: 'Music App Playback',
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    debugPrint("AudioService Init Error: $e");
    // Fallback or rethrow depending on your needs
  }

  runApp(
    ProviderScope(
      overrides: [
  audioHandlerProvider.overrideWithValue(handler as MyAudioHandler), 
  downloadRepositoryProvider.overrideWithValue(downloadRepo),
      ],
      child: const MusicApp(),
    ),
  );
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
