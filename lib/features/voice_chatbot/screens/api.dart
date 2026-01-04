import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class Api {
  final String baseUrl;
  Api(this.baseUrl);

  Future<User> _requireUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return user;

    // ✅ Wait a moment for authState to settle (web needs this)
    final completer = Completer<User>();
    late final StreamSubscription sub;

    sub = FirebaseAuth.instance.authStateChanges().listen((u) async {
      if (u != null) {
        await sub.cancel();
        completer.complete(u);
      }
    });

    // timeout safety
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () async {
        await sub.cancel();
        throw Exception("User not logged in (auth not ready)");
      },
    );
  }

  Future<String> _getToken({bool forceRefresh = false}) async {
  final user = await _requireUser();
  final token = await user.getIdToken(forceRefresh);

  if (token == null || token.isEmpty) {
    throw Exception("Firebase token missing");
  }
  return token;
}


  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retry = true,
  }) async {
    final token = await _getToken(forceRefresh: false);

    final uri = Uri.parse("$baseUrl$path");
    final headers = <String, String>{
      "Authorization": "Bearer $token",
      "Accept": "application/json",
      "Content-Type": "application/json",
    };

    http.Response res;
    if (method == "GET") {
      res = await http.get(uri, headers: headers);
    } else {
      res = await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
    }

    // ✅ If 401, refresh token ONCE and retry
    if (res.statusCode == 401 && retry) {
      final fresh = await _getToken(forceRefresh: true);
      final retryHeaders = <String, String>{
        ...headers,
        "Authorization": "Bearer $fresh",
      };

      if (method == "GET") {
        return http.get(uri, headers: retryHeaders);
      } else {
        return http.post(uri,
            headers: retryHeaders, body: jsonEncode(body ?? {}));
      }
    }

    return res;
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final res = await _request("GET", path);
    if (res.statusCode != 200) {
      throw Exception("GET $path failed: ${res.statusCode} ${res.body}");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final res = await _request("POST", path, body: body);
    if (res.statusCode != 200) {
      throw Exception("POST $path failed: ${res.statusCode} ${res.body}");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
