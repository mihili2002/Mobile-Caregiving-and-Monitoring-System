import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/medication_model.dart';
import '../../../services/ai_med_extraction_service.dart';
import 'review_medications_page.dart';

class UploadPrescriptionPage extends StatefulWidget {
  final String elderId;
  const UploadPrescriptionPage({super.key, required this.elderId});

  @override
  State<UploadPrescriptionPage> createState() => _UploadPrescriptionPageState();
}

class _UploadPrescriptionPageState extends State<UploadPrescriptionPage> {
  final _ai = AiMedExtractionService();
  bool _loading = false;

  Future<void> _pickImage(ImageSource src) async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: src, imageQuality: 85);
      if (x == null) return;
      
      final bytes = await x.readAsBytes();
      await _extract(bytes, x.name);
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["pdf"],
        withData: true, // Important for Web!
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.single;
      final bytes = file.bytes ?? (file.path != null ? File(file.path!).readAsBytesSync() : null);

      if (bytes != null) {
        await _extract(bytes, file.name);
      }
    } catch (e) {
      debugPrint("Error picking PDF: $e");
    }
  }

  Future<void> _extract(Uint8List fileBytes, String filename) async {
    setState(() => _loading = true);
    try {
      // Pass bytes and filename instead of File object
      final json = await _ai.extractFromPrescription(
        elderId: widget.elderId,
        fileBytes: fileBytes,
        filename: filename,
      );

      final medsJson = (json["medications"] as List?) ?? [];
      final meds = medsJson.map((e) => MedicationModel.fromJson(e)).toList();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewMedicationsPage(
            elderId: widget.elderId,
            medications: meds,
            usedMethod: (json["used_method"] ?? "vision_llm").toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("AI extraction failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Prescription")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_loading) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              const Text("AI scanning prescription..."),
              const SizedBox(height: 24),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Scan with Camera"),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo),
              label: const Text("Upload Image"),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _pickPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Upload PDF"),
            ),
          ],
        ),
      ),
    );
  }
}
