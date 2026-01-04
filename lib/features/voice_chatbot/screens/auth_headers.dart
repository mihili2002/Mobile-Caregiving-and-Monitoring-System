import 'package:firebase_auth/firebase_auth.dart';

Future<Map<String, String>> authHeaders() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception("User not logged in");
  }

  final token = await user.getIdToken();

  return {
    "Authorization": "Bearer $token",
    "Content-Type": "application/json",
  };
}
