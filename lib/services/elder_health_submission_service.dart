import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data' as typed_data;
import '../config/api_config.dart'; //adjust path if yours is different

class ElderHealthSubmissionService {
  ///Calls backend API:
  /// POST /elder/health-submissions/
  Future<void> submitHealthDetails({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/elder/health-submissions/");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      //success
      return;
    }

    // ❌ failed: show backend error
    String message = "Failed to submit health details.";
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded["detail"] != null) {
        message = decoded["detail"].toString();
      } else {
        message = decoded.toString();
      }
    } catch (_) {
      message = response.body;
    }

    throw Exception("[${
      response.statusCode
    }] $message");
  }

  Future<Map<String, dynamic>> extractDataFromPDF({
    required String token,
    required typed_data.Uint8List fileBytes,
    required String fileName,
  }) async {
    // Replace with your local machine's IP or your hosted Python backend URL
    final url = Uri.parse("${ApiConfig.baseUrl}/api/health/extract-pdf");

    try {
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';

      // Attach the PDF file from memory (Uint8List)
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes.toList(),
          filename: fileName,
          // contentType: MediaType('application', 'pdf'), // requires import 'package:http_parser/http_parser.dart';
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Extraction failed: ${response.body}");
      }
    } catch (e) {
      throw Exception("Connection error: $e");
    }
  }

  Future<Map<String, dynamic>> getSubmissionDetails({
    required String token,
    required String submissionId,
  }) async {
    final url =
    Uri.parse("${ApiConfig.baseUrl}/elder/health-submissions/$submissionId");

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to load submission details "
            "(status: ${response.statusCode})",
      );
    }

    final decoded = jsonDecode(response.body);

    //Backend returns a single submission object
    return decoded as Map<String, dynamic>;
  }

  Future<void> updateHealthDetails({
    required String token,
    required String submissionId,
    required Map<String, dynamic> payload,
  }) async {
    final res = await http.put(
      Uri.parse("${ApiConfig.baseUrl}/elder/health-submissions/$submissionId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to update submission");
    }
  }

  /// Get all submissions for a specific elder
  /// GET /elder/health-submissions/?elder_id={elderId}
  Future<List<Map<String, dynamic>>> getElderSubmissions({
    required String token,
    required String elderId,
  }) async {
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/elder/health-submissions/?elder_id=$elderId",
    );

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to load elder submissions "
            "(status: ${response.statusCode})",
      );
    }

    final decoded = jsonDecode(response.body);

    // Backend should return a list of submissions
    if (decoded is List) {
      return List<Map<String, dynamic>>.from(decoded);
    }
    return [];
  }

  /// Get the latest submission ID for an elder (for merging data)
  /// Returns null if no submissions exist
  Future<String?> getLatestSubmissionIdForElder({
    required String token,
    required String elderId,
  }) async {
    try {
      final submissions = await getElderSubmissions(
        token: token,
        elderId: elderId,
      );

      if (submissions.isEmpty) {
        return null;
      }

      // Sort by creation date (most recent first)
      // Assuming backend returns submissions with 'id' and 'created_at' fields
      submissions.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });

      return submissions.first['id']?.toString();
    } catch (e) {
      // If there's an error fetching, return null to create a new submission
      return null;
    }
  }
}

