import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase session in the platform secure storage
/// (Keychain/Keystore/DPAPI-backed file) instead of plaintext SharedPreferences.
///
/// Reads are wrapped in try/catch: if secure storage can't be read (seen on
/// Windows after certain uninstall/reinstall sequences), treat it as "no
/// session" and fall back to the login screen rather than crashing.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;
  static const _storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await _storage.read(key: persistSessionKey) != null;
    } catch (error) {
      debugPrint('SecureLocalStorage.hasAccessToken failed: $error');
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: persistSessionKey);
    } catch (error) {
      debugPrint('SecureLocalStorage.accessToken failed: $error');
      return null;
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: persistSessionKey);
    } catch (error) {
      debugPrint('SecureLocalStorage.removePersistedSession failed: $error');
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: persistSessionKey, value: persistSessionString);
  }
}

/// Same rationale as [SecureLocalStorage], for the PKCE flow's code verifier.
class SecureGotrueAsyncStorage extends GotrueAsyncStorage {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> getItem({required String key}) async {
    try {
      return await _storage.read(key: key);
    } catch (error) {
      debugPrint('SecureGotrueAsyncStorage.getItem failed: $error');
      return null;
    }
  }

  @override
  Future<void> removeItem({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (error) {
      debugPrint('SecureGotrueAsyncStorage.removeItem failed: $error');
    }
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }
}
