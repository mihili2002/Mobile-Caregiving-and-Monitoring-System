import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:flutter/foundation.dart'; // debugPrint

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? get currentUser => _auth.currentUser;

  static const String _tokenKey = "idToken";

  StreamSubscription<User?>? _idTokenSub;

  AuthService() {
    _startIdTokenListener();
  }

  /// Starts listening for token updates and saves them in secure storage.
  void _startIdTokenListener() {
    _idTokenSub?.cancel();

    _idTokenSub = _auth.idTokenChanges().listen((user) async {
      if (user == null) {
        await _storage.delete(key: _tokenKey);
        return;
      }

      try {
        final token = await user.getIdToken(); // String?
        if (token != null && token.isNotEmpty) {
          await _storage.write(key: _tokenKey, value: token);
        }
      } catch (_) {
        // Optional: log error
      }
    });
  }

  /// Sign in and persist token locally.
  Future<User?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = result.user;
    if (user != null) {
      final token = await user.getIdToken(true); // ✅ force refresh

      if (token == null || token.isEmpty) {
        throw Exception("Failed to retrieve Firebase ID token");
      }

      await _storage.write(key: _tokenKey, value: token);

      // ✅ Copy token to clipboard for Swagger testing
      await Clipboard.setData(ClipboardData(text: token));
      debugPrint("✅ Firebase ID token copied to clipboard");
    }

    return user;
  }

  /// Register and persist token locally.
  Future<User?> register(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = result.user;
    if (user != null) {
      final token = await user.getIdToken(true);

      if (token == null || token.isEmpty) {
        throw Exception("Failed to retrieve Firebase ID token");
      }

      await _storage.write(key: _tokenKey, value: token);

      // ✅ Copy token to clipboard for Swagger testing
      await Clipboard.setData(ClipboardData(text: token));
     // debugPrint("✅ Firebase ID token copied to clipboard");
     debugPrint("🔥 FIREBASE ID TOKEN ↓↓↓");
debugPrint(token);
debugPrint("🔥 END TOKEN");

    }

    return user;
  }

  /// Sign out and clear token.
  Future<void> signOut() async {
    await _auth.signOut();
    await _storage.delete(key: _tokenKey);
  }

  /// Stream of auth changes (login/logout).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Returns whatever token is stored locally (may be expired).
  Future<String?> getStoredToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Always returns a valid token by forcing refresh if needed.
  Future<String?> getValidToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final token = await user.getIdToken(forceRefresh);
      if (token != null && token.isNotEmpty) {
        await _storage.write(key: _tokenKey, value: token);
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  /// Copy latest valid token to clipboard manually (for Swagger testing)
  Future<void> copyTokenToClipboard() async {
    final token = await getValidToken(forceRefresh: true);

    if (token == null || token.isEmpty) {
      throw Exception("No valid token available to copy");
    }

    await Clipboard.setData(ClipboardData(text: token));
    debugPrint("✅ Token copied to clipboard");
  }

  /// Cleanup
  Future<void> dispose() async {
    await _idTokenSub?.cancel();
    _idTokenSub = null;
  }

  Future<AppUser?> getCurrentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await UserService().getUser(user.uid);
  }
}
