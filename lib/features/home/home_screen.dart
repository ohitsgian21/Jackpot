import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_repository.dart';

/// Placeholder post-login screen for Phase 0 — proves session persistence
/// works end-to-end. Replaced by the real dashboard in Sprint 3.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authRepositoryProvider).currentSession;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jackpot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Text('Signed in as ${session?.user.email ?? 'unknown'}'),
      ),
    );
  }
}
