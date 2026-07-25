import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/secure_storage_local_storage.dart';
import 'features/auth/auth_gate.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(
    _supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty,
    'Missing SUPABASE_URL/SUPABASE_ANON_KEY — run with '
    '--dart-define-from-file=env.json',
  );

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(
        persistSessionKey:
            'sb-${Uri.parse(_supabaseUrl).host.split('.').first}-auth-token',
      ),
      pkceAsyncStorage: SecureGotrueAsyncStorage(),
    ),
  );

  runApp(const ProviderScope(child: JackpotApp()));
}

class JackpotApp extends StatelessWidget {
  const JackpotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jackpot',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
