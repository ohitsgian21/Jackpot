import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_screen.dart';
import 'auth_repository.dart';
import 'login_screen.dart';

/// Shows [HomeScreen] when a session exists, [LoginScreen] otherwise.
///
/// Watches [authStateChangesProvider] so session persistence (a restart
/// recovering a stored session) and sign-out both route correctly without
/// any manual navigation calls.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (state) {
        final session = state.session ?? ref.read(authRepositoryProvider).currentSession;
        return session != null ? const HomeScreen() : const LoginScreen();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(child: Text('Something went wrong: $error')),
      ),
    );
  }
}
