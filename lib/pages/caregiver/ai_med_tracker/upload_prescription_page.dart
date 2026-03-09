import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
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

class _UploadPrescriptionPageState extends State<UploadPrescriptionPage> with SingleTickerProviderStateMixin {
  final _ai = AiMedExtractionService();
  bool _loading = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
    final theme = Theme.of(context);
    final primary = const Color(0xFF009688);
    final secondary = const Color(0xFF4DB6AC);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Add Prescription",
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF0FDFA),
                    const Color(0xFFE0F2F1),
                    const Color(0xFFB2DFDB).withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),

          // Abstract background shapes
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        "Upload Method",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Scan or upload your prescription to automatically extract medications.",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildActionCard(
                        title: "Scan with Camera",
                        subtitle: "Take a clear photo of your prescription",
                        icon: Icons.camera_alt_rounded,
                        gradient: [primary, primary.withOpacity(0.8)],
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                      const SizedBox(height: 16),
                      _buildActionCard(
                        title: "Upload Image",
                        subtitle: "Select a photo from your gallery",
                        icon: Icons.image_rounded,
                        gradient: [const Color(0xFF00BBA7), const Color(0xFF009688)],
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                      const SizedBox(height: 16),
                      _buildActionCard(
                        title: "Upload PDF",
                        subtitle: "Import a PDF document",
                        icon: Icons.picture_as_pdf_rounded,
                        gradient: [const Color(0xFF26A69A), const Color(0xFF00897B)],
                        onTap: _pickPdf,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF009688)),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "AI Scanning...",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Extracting medication details from your document",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loading ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: gradient[0].withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}