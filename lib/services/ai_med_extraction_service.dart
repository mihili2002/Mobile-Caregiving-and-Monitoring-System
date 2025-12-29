import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/medication_model.dart';

import 'dart:typed_data';

class AiMedExtractionService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<Map<String, dynamic>> extractFromPrescription({
    required String elderId,
    required Uint8List fileBytes,
    required String filename,
  }) async {
    final uri = Uri.parse("$baseUrl/api/ai/prescriptions/extract");
    final req = http.MultipartRequest("POST", uri);
    req.fields["elder_id"] = elderId;
    
    req.files.add(
      http.MultipartFile.fromBytes(
        "file",
        fileBytes,
        filename: filename,
      ),
    );

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception("Extraction failed: ${streamed.statusCode} $body");
    }
    return jsonDecode(body);
  }

  Future<void> saveMedications({
    required String elderId,
    required List<MedicationModel> medications,
  }) async {
    final uri = Uri.parse("$baseUrl/api/medications/save");
    final resp = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "elder_id": elderId,
        "medications": medications.map((m) => m.toJson()).toList(),
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception("Save failed: ${resp.statusCode} ${resp.body}");
    }
  }
}
