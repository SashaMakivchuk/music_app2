import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

extension AuthAsyncX on AsyncValue<User?> {
  User? get asUser => when(
        data: (u) => u,
        loading: () => null,
        error: (e, st) => null,
      );
}
